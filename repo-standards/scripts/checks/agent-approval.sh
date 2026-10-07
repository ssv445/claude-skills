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
changed="$(mktemp)"; trap 'rm -f "$changed"' EXIT; diff_ok=0
if [ -z "$base" ]; then miss "no base commit (origin/$BASE_BRANCH or $BASE_BRANCH) — the owner decides"
elif git -c core.quotePath=false diff -z --name-only --no-renames "$base" HEAD > "$changed"; then diff_ok=1
else miss "git diff $base HEAD failed"
fi
# gate_review <section>: the section in decisions.md passed review — one copy of it and of
# each reviewer line, Verdict PASS, both reviewers PASS (or split with the arbiter PASS),
# and a Reviewed sha that still covers HEAD. Each miss is printed.
gate_review() {
  local s="$1" n p c v a b arb sha full later f passes
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
  sha="$(section_field "$dec" "$s" "Reviewed:")"
  full="$(git rev-parse -q --verify "$sha^{commit}" 2>/dev/null)"
  if ! printf '%s' "$sha" | grep -qE '^[0-9a-f]{7,40}$'; then
    miss "$s: 'Reviewed:' must be a commit sha, got '${sha:-empty}'"
  elif [ -z "$full" ] || [ "${full#"$sha"}" = "$full" ]; then
    miss "$s: reviewed commit $sha is not present locally (fetch it, or review again)"
  elif [ $diff_ok -eq 1 ]; then
    later=""
    while IFS= read -r -d '' f; do
      [ "$f" != "$dec" ] || continue
      [ "$(git rev-parse -q --verify "$full:$f")" = "$(git rev-parse -q --verify "HEAD:$f")" ] || later="$later $f"
    done < "$changed"
    [ -z "$later" ] && info "ok   $s: review covers HEAD (reviewed $sha)" || miss "$s: differs from the reviewed commit $sha:$later"
  fi
}

dec="$(decisions_file)"
if [ -z "$dec" ] || [ ! -f "$dec" ]; then
  miss "no decisions.md for this branch (docs/work/<issue>-<slug>/)"
else
  # a. Pre-merge gate passed: both reviewers PASS, or they split and the arbiter ruled PASS.
  gate_review "Pre-merge gate"

  # b. Nobody flagged a taste or product call for the owner.
  flags="$(grep -inE "$(owner_flag_re review)" "$dec")"
  [ -z "$flags" ] && info "ok   no owner-review flag" || miss "owner review requested in $dec: $flags"
fi

# Owner-only flags removed by any commit on the branch (added then deleted counts too).
# -m: a merge commit's diff against each parent, so a flag dropped while merging shows.
if [ -n "$base" ]; then
  if log="$(git log -m -p --format= "$base..HEAD" -- "docs/work/$(issue_number)-*")"; then
    # Removed lines, minus the diff's "-" marker, judged by the same flag patterns.
    removed="$(printf '%s\n' "$log" | grep -E '^-' | grep -vE '^--- (a/|/dev/null)' | sed 's/^-//' \
      | grep -iE "$(owner_flag_re review)|$(owner_flag_re approval)")"
    [ -z "$removed" ] && info "ok   no owner flag removed" || miss "owner flag removed on this branch: $removed"
  else miss "git log $base..HEAD failed"
  fi
fi

# raises_baseline: the branch only raises .standards/coverage-baseline — one number on
# base and HEAD, HEAD's >= base's. coverage-baseline.sh asks for exactly that edit; any
# other change to it (lower, extra text, new, deleted) stays a gate change.
raises_baseline() {
  local old new num='^[0-9]+(\.[0-9]+)?$'
  old="$(git show "$base:.standards/coverage-baseline" 2>/dev/null)" || return 1
  new="$(git show "HEAD:.standards/coverage-baseline" 2>/dev/null)" || return 1
  printf '%s\n' "$old" | grep -qE "$num" && [ "$(printf '%s\n' "$old" | wc -l)" -eq 1 ] || return 1
  printf '%s\n' "$new" | grep -qE "$num" && [ "$(printf '%s\n' "$new" | wc -l)" -eq 1 ] || return 1
  awk -v o="$old" -v n="$new" 'BEGIN { exit !(n + 0 >= o + 0) }'
}

# c. A gate-file change passed its own review: two more independent reviewers asked only
# whether it weakens, skips or bypasses a check, or widens what agents do without the
# owner, and whether its new RULE_LOG entry says so plainly. The entry is a changed file,
# so the review must cover it like any other. A change that does loosen a check carries
# owner-review: required, caught in b.
# --no-renames: a moved file shows both paths.
# nocasematch: ".Claude/" is ".claude/" on a case-insensitive filesystem.
if [ $diff_ok -eq 1 ]; then
  touched=""
  shopt -s nocasematch
  while IFS= read -r -d '' f; do
    if [ "$f" = ".standards/coverage-baseline" ] && raises_baseline; then
      info "ok   coverage baseline only raised"; continue
    fi
    matches_any "$f" "$GATE_FILES" && touched="$touched $f"
  done < "$changed"
  shopt -u nocasematch
  # APPROVER (base config) decides who approves a gate change. Owner mode: the owner.
  # Agent mode: the agent, after the gate-change review and a RULE_LOG line. bin/ship
  # reads the "ok" line below to record and label the change; keep its wording.
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

[ $fail -eq 0 ] || { red "FAIL agent-approval: fix the misses above; the owner is needed only for an owner-review flag, a removed owner flag, no base, or (APPROVER=owner) gate files"; exit 1; }
green "PASS agent-approval"
