#!/usr/bin/env bash
# agent-approval.sh: may the agent approve this branch itself? Exit 0 = yes; otherwise
# prints each reason the owner's approval is needed. bin/ship asks it when the PR has no
# owner `approved` label.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

# Files holding the rules that judge a change, and inputs those rules read. A change to
# them needs, on top of the pre-merge gate, a passing "## Gate-change review" (c below).
# Not covered: scripts and lint/test config that the *_CMD commands in config.sh read.
GATE_FILES="bin/* .standards/* .claude/* .github/* .husky/* lefthook.yml lefthook.yaml .pre-commit-config.yaml CLAUDE.md */CLAUDE.md AGENTS.md */AGENTS.md docs/guidelines/repo-standards.md docs/doc-map.txt"
# The owner's view of rule changes: one dated line per gate change, appended, never edited.
RULE_LOG="docs/rule-changes.md"

fail=0
# misses counts every miss, so a section can tell whether it added one.
misses=0
miss() { red "  miss $*"; fail=1; misses=$((misses + 1)); }
# A verdict is PASS only as a whole word: "PASS", "PASS — why", "PASS—why". Not "PASSABLE".
is_pass() { case "$1" in PASS|PASS\ *|PASS—*) return 0 ;; *) return 1 ;; esac; }

# Fail closed: without a base, or if git cannot list the branch's changes, nothing below
# can be trusted, so the owner decides.
# The list is NUL-separated in a file: -z and quotePath=false keep git from C-quoting
# non-ASCII names, which would match no glob and resolve to no blob.
base="$(base_commit)"
changed="$(mktemp)"; trap '[ -z "$changed" ] || safe_rm "$changed" "$changed".*' EXIT; diff_ok=0
if [ -z "$base" ]; then miss "no base commit (origin/$BASE_BRANCH or $BASE_BRANCH) — the owner decides"
elif git -c core.quotePath=false diff -z --name-only --no-renames "$base" HEAD > "$changed"; then diff_ok=1
else miss "git diff $base HEAD failed"
fi

# raises_baseline: the branch only raises .standards/coverage-baseline — one number on
# base and HEAD, HEAD's >= base's. No file on the base counts as 0, as coverage-baseline.sh
# reads it, so creating it with one number is a raise (the ratchet asks for it on a fresh
# install). coverage-baseline.sh asks for exactly that edit; any other change to it (lower,
# extra text, deleted) stays a gate change.
raises_baseline() {
  local old new num='^[0-9]+(\.[0-9]+)?$'
  if git cat-file -e "$base:.standards/coverage-baseline" 2>/dev/null; then
    old="$(git show "$base:.standards/coverage-baseline")" || return 1
  else old=0; fi
  new="$(git show "HEAD:.standards/coverage-baseline" 2>/dev/null)" || return 1
  printf '%s\n' "$old" | grep -qE "$num" && [ "$(printf '%s\n' "$old" | wc -l)" -eq 1 ] || return 1
  printf '%s\n' "$new" | grep -qE "$num" && [ "$(printf '%s\n' "$new" | wc -l)" -eq 1 ] || return 1
  awk -v o="$old" -v n="$new" 'BEGIN { exit !(n + 0 >= o + 0) }'
}

# std_block <rev> <path>: the repo-standards block of a CLAUDE.md / AGENTS.md at <rev> — the
# lines between its begin and end markers. Fails when the file is absent there or the
# markers are not exactly one begin followed by one end.
STD_BEGIN="<!-- repo-standards:begin -->"
STD_END="<!-- repo-standards:end -->"
std_block() {
  git show "$1:$2" 2>/dev/null | awk -v b="$STD_BEGIN" -v e="$STD_END" '
    { sub(/[ \t\r]+$/, "") }
    $0 == b { nb++; if (ne) bad = 1; inside = 1; next }
    $0 == e { ne++; if (!inside) bad = 1; inside = 0; next }
    inside { out = out $0 "\n" }
    END { if (bad || nb != 1 || ne != 1) exit 1; printf "%s", out }'
}

# block_unchanged <path>: CLAUDE.md / AGENTS.md whose repo-standards block is the same on
# base and HEAD. Only that block holds rules; the rest of the file is facts any PR may edit
# (in some repos an architecture doc nearly every PR touches). Fails closed: a file without
# well-formed markers on either side counts whole.
block_unchanged() {
  local old new
  old="$(std_block "$base" "$1")" || return 1
  new="$(std_block HEAD "$1")" || return 1
  [ "$old" = "$new" ]
}

# imports_changed <path>: the branch adds, removes or edits an "@path" import line anywhere
# in a CLAUDE.md / AGENTS.md. An import loads another file's text as instructions, so one
# added outside the markers would bring in rules ungated. Any word starting with "@" after
# the start of a line or a space counts (an @-mention too): fail closed.
imports_changed() {
  git diff -U0 --no-renames "$base" HEAD -- "$1" | grep -E '^[-+]' | grep -vE '^(\+\+\+|---) ' \
    | sed 's/^[-+]//' | grep -qE '(^|[[:space:]])@[^[:space:]]'
}

# import_targets: every file a CLAUDE.md / AGENTS.md imports with "@path", on base or HEAD,
# resolved against the importing file's folder, one repo path per line. An imported file is
# read as instructions, so it is a gate file like the block itself. Paths leaving the repo
# (~/..., /abs, too many ..) are skipped: nothing in the repo to gate.
import_targets() {
  local rev f
  for rev in "$base" HEAD; do
    git -c core.quotePath=false ls-tree -r --name-only "$rev" | grep -iE '(^|/)(CLAUDE|AGENTS)\.md$' \
      | while IFS= read -r f; do
          git show "$rev:$f" 2>/dev/null | grep -oE '(^|[[:space:]])@[^[:space:]]+' \
            | sed -E 's/^[[:space:]]*@//; s/[).,;:]+$//' \
            | awk -v dir="$(dirname "$f")" '
                /^[~\/]/ { next }
                {
                  p = (dir == "." ? "" : dir "/") $0; n = split(p, seg, "/"); k = 0
                  for (i = 1; i <= n; i++) {
                    if (seg[i] == "" || seg[i] == ".") continue
                    if (seg[i] == "..") { if (k == 0) { bad = 1; break }; k--; continue }
                    out[++k] = seg[i]
                  }
                  if (!bad && k > 0) { r = out[1]; for (i = 2; i <= k; i++) r = r "/" out[i]; print r }
                  bad = 0
                }'
        done
  done | sort -u
}

# gate_files_touched: sets $touched to the gate files the branch changes (space-led, "" =
# none) and $baseline_raised when the only baseline edit is a raise, which is no gate change.
# A CLAUDE.md / AGENTS.md counts only when its repo-standards block changed (block_unchanged)
# or an @-import line changed anywhere in it (imports_changed); a file either side imports
# counts whole (import_targets).
# --no-renames (in $changed): a moved file shows both paths.
# nocasematch: ".Claude/" is ".claude/" on a case-insensitive filesystem.
gate_files_touched() {
  local f t imports imported
  touched=""; baseline_raised=""
  imports="$(import_targets)"
  shopt -s nocasematch
  while IFS= read -r -d '' f; do
    if [ "$f" = ".standards/coverage-baseline" ] && raises_baseline; then baseline_raised=1; continue; fi
    imported=""
    while IFS= read -r t; do [ -n "$t" ] && [[ "$f" == "$t" ]] && imported=1; done <<<"$imports"
    [ -z "$imported" ] || { touched="$touched $f"; continue; }
    matches_any "$f" "$GATE_FILES" || continue
    case "${f##*/}" in CLAUDE.md|AGENTS.md) block_unchanged "$f" && ! imports_changed "$f" && continue ;; esac
    touched="$touched $f"
  done < "$changed"
  shopt -u nocasematch
}

# --gate-files: print only the changed gate files (empty line = none) and stop. bin/ship
# labels and records every gate change with it, whoever approved — one detection, not two.
# Fails closed: no base or no diff → exit 1.
if [ "${1:-}" = "--gate-files" ]; then
  [ $diff_ok -eq 1 ] || exit 1
  gate_files_touched
  printf '%s\n' "${touched# }"
  exit 0
fi

# delta_ok <section> <new sha> <old sha>: the delta form may stand (see gate_review); else a miss.
delta_ok() {
  local s="$1" new old
  new="$(git rev-parse -q --verify "$2^{commit}" 2>/dev/null)"; old="$(git rev-parse -q --verify "$3^{commit}" 2>/dev/null)"
  if [ -z "$new" ] || [ "$new" = "$old" ]; then
    miss "$s: 'Reviewed: $2 (delta from $3)': the delta is empty or the new sha is missing — record the sha the reviewers read"; return 1
  fi
  if ! git merge-base --is-ancestor "$old" "$new" 2>/dev/null; then  # bite: delta-ancestor
    miss "$s: 'Reviewed: $2 (delta from $3)': $3 is not an ancestor of $2, so the delta does not cover the branch — review in full"; return 1
  fi
  if ! reviewed_before "$s" "$old"; then  # bite: delta-recorded
    miss "$s: 'Reviewed: $2 (delta from $3)': $3 was never recorded here as the Reviewed sha of a Verdict: PASS — review in full"; return 1
  fi
}

# reviewed_before <section> <full sha>: some commit of decisions.md's history (from HEAD) has, in
# that section, Verdict: PASS with a Reviewed sha (full, or a delta's new sha) that is this commit.
reviewed_before() {
  local c r v
  while IFS= read -r c; do
    git show "$c:$dec" > "$changed.hist" 2>/dev/null || continue
    v="$(section_verdict "$changed.hist" "$1")"
    [ "$v" = PASS ] || continue
    r="$(section_field "$changed.hist" "$1" "Reviewed:")"; r="${r%% *}"
    printf '%s' "$r" | grep -qE '^[0-9a-f]{7,40}$' || continue
    [ "$(git rev-parse -q --verify "$r^{commit}" 2>/dev/null)" = "$2" ] && return 0
  done < <(git log --format=%H HEAD -- "$dec")
  return 1
}

# gate_review <section>: the section in decisions.md passed review — one copy of it and of
# each reviewer line, Verdict PASS, both reviewers PASS (or split with the arbiter PASS),
# and a Reviewed sha that still covers HEAD. Each miss is printed.
gate_review() {
  local s="$1" n p c v a b arb sha delta full later f passes
  n="$(grep -c "^## $s\$" "$dec")"
  [ "$n" -le 1 ] || miss "'## $s' appears $n times in $dec"
  # Only the first of each line is read, so a second one would be silently ignored.
  for p in "- Reviewer A:" "- Reviewer B:" "- Arbiter:" "Reviewed:" "Verdict:"; do
    c="$(section_count "$dec" "$s" "$p")"
    [ "$c" -le 1 ] || miss "'$p' appears $c times in the $s — edit it in place"
  done
  v="$(section_verdict "$dec" "$s")"
  [ "$v" = "PASS" ] && info "ok   $s: PASS" || miss "$s: ${v:-no verdict}"
  a="$(section_field "$dec" "$s" "- Reviewer A:")"
  b="$(section_field "$dec" "$s" "- Reviewer B:")"
  arb="$(section_field "$dec" "$s" "- Arbiter:")"
  passes=0; is_pass "$a" && passes=$((passes + 1)); is_pass "$b" && passes=$((passes + 1))
  if [ $passes -eq 2 ]; then info "ok   $s: both reviewers PASS"
  elif [ $passes -eq 1 ] && is_pass "$arb"; then info "ok   $s: reviewers split; arbiter PASS"
  else miss "$s: need both reviewers PASS, or one PASS and the arbiter PASS (A: ${a:-empty}; B: ${b:-empty}; Arbiter: ${arb:-empty})"
  fi

  # The review must cover HEAD: every file the branch changes (but decisions.md) has the
  # same content at HEAD as at the reviewed commit. A rebase onto unrelated base changes
  # keeps the review; a base change to a reviewed file needs a new one. Only a literal
  # hex sha is accepted — never HEAD, a branch, or a ref that merely looks like hex.
  # A fix round after a PASS may re-review only the delta: "Reviewed: <new sha> (delta from <old
  # sha>)". The new sha is the one that must cover HEAD, exactly as a full review's. The old sha
  # must be a strict ancestor of the new one and must have been recorded in this section, in
  # decisions.md's history, as the Reviewed sha of a Verdict: PASS (reviewed_before): only then do
  # that earlier review and the delta together cover the whole branch — the condition that makes a
  # delta review no weaker than a full one.
  sha="$(section_field "$dec" "$s" "Reviewed:")"
  delta="$(printf '%s\n' "$sha" | sed -n 's/^[0-9a-f]\{7,40\} (delta from \([0-9a-f]\{7,40\}\))$/\1/p')"
  [ -z "$delta" ] || sha="${sha%% *}"
  full="$(git rev-parse -q --verify "$sha^{commit}" 2>/dev/null)"
  if ! printf '%s' "$sha" | grep -qE '^[0-9a-f]{7,40}$'; then
    miss "$s: 'Reviewed:' must be a commit sha, or '<sha> (delta from <sha>)' after a fix round, got '${sha:-empty}'"
  elif [ -n "$delta" ] && ! git cat-file -e "$delta^{commit}" 2>/dev/null; then
    miss "$s: 'Reviewed: $sha (delta from $delta)': $delta is not a commit present locally (fetch it, or review in full)"
  elif [ -n "$delta" ] && ! delta_ok "$s" "$sha" "$delta"; then
    :  # delta_ok printed the miss
  elif [ -z "$full" ] || [ "${full#"$sha"}" = "$full" ]; then
    miss "$s: reviewed commit $sha is not present locally (fetch it, or review again)"
  elif [ $diff_ok -eq 1 ]; then
    later=""
    while IFS= read -r -d '' f; do
      [ "$f" != "$dec" ] || continue
      [ "$(git rev-parse -q --verify "$full:$f")" = "$(git rev-parse -q --verify "HEAD:$f")" ] || later="$later $f"
    done < "$changed"
    [ -z "$later" ] && info "ok   $s: review covers HEAD (reviewed $sha${delta:+, delta from $delta})" || miss "$s: differs from the reviewed commit $sha:$later"
  fi
}

dec="$(decisions_file)"
if [ -z "$dec" ] || [ ! -f "$dec" ]; then
  miss "no single decisions.md for this branch (docs/work/<issue>-<slug>/)"
else
  # a. Pre-merge gate passed: both reviewers PASS, or they split and the arbiter ruled PASS.
  gate_review "Pre-merge gate"
fi

# b. No big call is waiting on the owner, in any file of any folder for this issue
# (decisions.md, spec.md, plan notes — and a second folder cannot hide one). An answered
# flag (owner_answered_re) is closed.
flags=""
while IFS= read -r d; do
  [ -n "$d" ] || continue
  while IFS= read -r f; do
    o="$(owner_flags "$f")"; [ -z "$o" ] || flags="$flags $f: $o;"
  done < <(find "$d" -type f)
done <<<"$(issue_dirs)"
[ -z "$flags" ] && info "ok   no open owner-review flag" || miss "owner review requested:$flags"

# Owner-only flags removed by any commit on the branch (added then deleted counts too).
# -m: a merge commit's diff against each parent, so a flag dropped while merging shows.
# An owner-review flag may go only by turning into an answered line: each removed flag,
# counted by occurrence, is paired with its own answered line carrying the same reason and
# added on this branch (one already on the base closed an earlier flag). owner-approval:
# required has no answered form — removing it always needs the owner.
if [ -n "$base" ]; then
  work="docs/work/$(issue_number)-*"
  if log="$(git log -m -p --format= "$base..HEAD" -- "$work")" \
     && now="$(git diff --no-renames "$base" HEAD -- "$work")"; then
    # Removed lines, minus the diff's "-" marker, judged by the same flag patterns.
    removed="$(printf '%s\n' "$log" | grep -E '^-' | grep -vE '^--- (a/|/dev/null)' | sed 's/^-//')"
    gone_approval="$(printf '%s\n' "$removed" | grep -iE "$(owner_flag_re approval)")"
    # An edited answered line is no removed flag, even if its answer says "required".
    gone_review="$(printf '%s\n' "$removed" | grep -iE "$(owner_flag_re review)" \
      | while IFS= read -r l; do [ -n "$(printf '%s\n' "$l" | owner_answered_lines -)" ] || printf '%s\n' "$l"; done)"
    [ -z "$gone_approval" ] || miss "owner-approval flag removed on this branch: $gone_approval"
    if [ -z "$gone_review" ]; then info "ok   no owner-review flag removed"
    else
      # Answered lines the branch adds (vs base), as reasons; comm pairs equal lines one to one.
      # A reason needs a letter or digit: an empty one would pair with any empty answer.
      printf '%s\n' "$gone_review" | owner_reason | sort > "$changed.gone"
      printf '%s\n' "$now" | grep -E '^\+' | grep -vE '^\+\+\+ ' | sed 's/^+//' | owner_answered_lines - \
        | owner_reason | grep '[[:alnum:]]' | sort > "$changed.answered"
      noreason="$(grep -vc '[[:alnum:]]' "$changed.gone")"
      unpaired="$(grep '[[:alnum:]]' "$changed.gone" | comm -23 - "$changed.answered")"
      safe_rm "$changed.gone" "$changed.answered"
      [ "$noreason" -eq 0 ] || miss "$noreason owner-review flag(s) with no reason removed on this branch — no answered line can pair with it; only the owner can close it (bin/approve <pr>)"
      if [ -z "$unpaired" ]; then [ "$noreason" -ne 0 ] || info "ok   $(printf '%s\n' "$gone_review" | wc -l | tr -d ' ') owner-review flag(s) closed as answered"
      else miss "owner-review flag removed on this branch without its own answered line (reasons: $(printf '%s' "$unpaired" | tr '\n' ';')) — replace each flag with 'owner-review: answered — <reason as in the flag> — <link to the owner's answer> — <the answer, quoted>'"
      fi
    fi
  else miss "git log/diff $base..HEAD failed"
  fi
fi

# c. A gate-file change passed its own review: two more independent reviewers asked only
# whether it weakens, skips or bypasses a check, or widens what agents do without the
# owner, and whether its new RULE_LOG entry says so plainly. The entry is a changed file,
# so the review must cover it like any other. A change that does loosen a check carries
# owner-review: required, caught in b.
if [ $diff_ok -eq 1 ]; then
  gate_files_touched
  [ -z "$baseline_raised" ] || info "ok   coverage baseline only raised"
  # APPROVER (base config) decides who approves a gate change. Owner mode: the owner.
  # Agent mode: the agent, after the gate-change review and a RULE_LOG line.
  if [ -z "$touched" ]; then info "ok   no gate files changed"
  elif [ "$(approver_mode)" != agent ]; then miss "gate files changed:$touched (APPROVER=owner: the owner approves gate changes)"
  elif [ -z "$dec" ] || [ ! -f "$dec" ]; then miss "gate files changed:$touched"
  else
    before=$misses
    gate_review "Gate-change review"
    git diff -U0 --no-renames "$base" HEAD -- "$RULE_LOG" | grep -qE '^\+- [0-9]{4}-[0-9]{2}-[0-9]{2} +[^ ]' \
      || miss "no new entry in $RULE_LOG — add '- YYYY-MM-DD #<issue> — <what the rules now do differently, and why>'"
    [ $misses -eq $before ] && info "ok   gate files changed, approved under APPROVER=agent (gate-change review PASS):$touched" \
      || miss "gate files changed:$touched — APPROVER=agent needs a passing '## Gate-change review' in $dec and a $RULE_LOG line"
  fi
fi

# d. The rule-change log only grows, on every branch: the owner's record is never rewritten.
if [ $diff_ok -eq 1 ] && git diff -U0 --no-renames "$base" HEAD -- "$RULE_LOG" | grep -E '^-' | grep -vqE '^--- '; then
  miss "$RULE_LOG lost or changed a line — it only grows; append instead"
fi

[ $fail -eq 0 ] || { red "FAIL agent-approval: fix the misses above; the owner is needed only to answer an owner-review flag (then close it as answered), for a removed owner-approval flag, no base, or (APPROVER=owner) gate files"; exit 1; }
green "PASS agent-approval"
