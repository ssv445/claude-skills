#!/usr/bin/env bash
# agent-approval.sh: may the agent approve this branch itself? Exit 0 = yes; otherwise
# prints each reason the owner's approval is needed. bin/ship asks it when the PR has no
# owner `approved` label.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

# Files holding the rules that judge a change, and inputs those rules read. An agent never
# approves a change to them. Not covered: scripts and lint/test config that the *_CMD
# commands in config.sh read.
GATE_FILES="bin/* .standards/* .claude/* .github/* .husky/* lefthook.yml lefthook.yaml .pre-commit-config.yaml CLAUDE.md */CLAUDE.md AGENTS.md */AGENTS.md docs/guidelines/repo-standards.md docs/doc-map.txt"

fail=0
miss() { red "  miss $*"; fail=1; }
# A verdict is PASS only as a whole word: "PASS", "PASS — why", "PASS—why". Not "PASSABLE".
is_pass() { case "$1" in PASS|PASS\ *|PASS—*) return 0 ;; *) return 1 ;; esac; }

# Fail closed: without a base, or if git cannot list the branch's changes, nothing below
# can be trusted, so the owner decides.
# The list is NUL-separated in a file: -z and quotePath=false keep git from C-quoting
# non-ASCII names, which would match no glob and resolve to no blob.
base="$(base_commit)"
changed="$(mktemp)"; trap 'rm -f "$changed"' EXIT; diff_ok=0
if [ -z "$base" ]; then miss "no base commit (origin/$BASE_BRANCH or $BASE_BRANCH)"
elif git -c core.quotePath=false diff -z --name-only --no-renames "$base" HEAD > "$changed"; then diff_ok=1
else miss "git diff $base HEAD failed"
fi
dec="$(decisions_file)"
if [ -z "$dec" ] || [ ! -f "$dec" ]; then
  miss "no decisions.md for this branch (docs/work/<issue>-<slug>/)"
else
  # a. Pre-merge gate passed: both reviewers PASS, or they split and the arbiter ruled PASS.
  n="$(grep -c '^## Pre-merge gate$' "$dec")"
  [ "$n" -le 1 ] || miss "'## Pre-merge gate' appears $n times in $dec"
  v="$(section_verdict "$dec" "Pre-merge gate")"
  [ "$v" = "PASS" ] && info "ok   Pre-merge gate: PASS" || miss "Pre-merge gate: ${v:-no verdict}"
  a="$(section_field "$dec" "Pre-merge gate" "- Reviewer A:")"
  b="$(section_field "$dec" "Pre-merge gate" "- Reviewer B:")"
  arb="$(section_field "$dec" "Pre-merge gate" "- Arbiter:")"
  passes=0; is_pass "$a" && passes=$((passes + 1)); is_pass "$b" && passes=$((passes + 1))
  if [ $passes -eq 2 ]; then info "ok   both reviewers PASS"
  elif [ $passes -eq 1 ] && is_pass "$arb"; then info "ok   reviewers split; arbiter PASS"
  else miss "need both reviewers PASS, or one PASS and the arbiter PASS (A: ${a:-empty}; B: ${b:-empty}; Arbiter: ${arb:-empty})"
  fi

  # The review must cover HEAD: every file the branch changes (but decisions.md) has the
  # same content at HEAD as at the reviewed commit. A rebase onto unrelated base changes
  # keeps the review; a base change to a reviewed file needs a new one. Only a literal
  # hex sha is accepted — never HEAD, a branch, or a ref that merely looks like hex.
  sha="$(section_field "$dec" "Pre-merge gate" "Reviewed:")"
  full="$(git rev-parse -q --verify "$sha^{commit}" 2>/dev/null)"
  if ! printf '%s' "$sha" | grep -qE '^[0-9a-f]{7,40}$'; then
    miss "'Reviewed:' must be a commit sha, got '${sha:-empty}'"
  elif [ -z "$full" ] || [ "${full#"$sha"}" = "$full" ]; then
    miss "reviewed commit $sha is not present locally (fetch it, or review again)"
  elif [ $diff_ok -eq 1 ]; then
    later=""
    while IFS= read -r -d '' f; do
      [ "$f" != "$dec" ] || continue
      [ "$(git rev-parse -q --verify "$full:$f")" = "$(git rev-parse -q --verify "HEAD:$f")" ] || later="$later $f"
    done < "$changed"
    [ -z "$later" ] && info "ok   review covers HEAD (reviewed $sha)" || miss "differs from the reviewed commit $sha:$later"
  fi

  # b. Nobody flagged a taste or product call for the owner.
  flags="$(grep -inE "^$(owner_flag_re review)" "$dec")"
  [ -z "$flags" ] && info "ok   no owner-review flag" || miss "owner review requested in $dec: $flags"
fi

# Owner-only flags removed by any commit on the branch (added then deleted counts too).
# -m: a merge commit's diff against each parent, so a flag dropped while merging shows.
if [ -n "$base" ]; then
  if log="$(git log -m -p --format= "$base..HEAD" -- "docs/work/$(issue_number)-*")"; then
    removed="$(printf '%s\n' "$log" | grep -iE "^-($(owner_flag_re review)|$(owner_flag_re approval))")"
    [ -z "$removed" ] && info "ok   no owner flag removed" || miss "owner flag removed on this branch: $removed"
  else miss "git log $base..HEAD failed"
  fi
fi

# c. The diff leaves the gate files alone. --no-renames: a moved file shows both paths.
if [ $diff_ok -eq 1 ]; then
  touched=""
  while IFS= read -r -d '' f; do
    matches_any "$f" "$GATE_FILES" && touched="$touched $f"
  done < "$changed"
  [ -z "$touched" ] && info "ok   no gate files changed" || miss "gate files changed:$touched"
fi

[ $fail -eq 0 ] || { red "FAIL agent-approval: owner approval needed"; exit 1; }
green "PASS agent-approval"
