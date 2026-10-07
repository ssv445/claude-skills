#!/usr/bin/env bash
# agent-approval.sh: may the agent approve this branch itself? Exit 0 = yes; otherwise
# prints each reason the owner's approval is needed. bin/ship asks it when the PR has no
# owner `approved` label.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

# Files holding the rules that judge a change, and inputs those rules read. An agent never
# approves a change to them. Not covered: scripts that E2E_CMD / PERF_CMD call.
GATE_FILES="bin/* .standards/* .claude/* .github/* CLAUDE.md */CLAUDE.md AGENTS.md */AGENTS.md docs/guidelines/repo-standards.md docs/doc-map.txt"

fail=0
miss() { red "  miss $*"; fail=1; }
# A verdict is PASS only as a whole word: "PASS", "PASS — why", "PASS—why". Not "PASSABLE".
is_pass() { case "$1" in PASS|PASS\ *|PASS—*) return 0 ;; *) return 1 ;; esac; }

base="$(base_commit)"
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

  # The review must cover HEAD: after the reviewed commit, only decisions.md may change.
  sha="$(section_field "$dec" "Pre-merge gate" "Reviewed:")"
  if [ -z "$sha" ] || ! git rev-parse -q --verify "$sha^{commit}" >/dev/null; then
    miss "no valid 'Reviewed: <sha>' in the Pre-merge gate (${sha:-empty})"
  elif ! git merge-base --is-ancestor "$sha" HEAD; then
    miss "reviewed commit $sha is not in this branch's history"
  else
    later="$(git diff --name-only --no-renames "$sha" HEAD | grep -vxF "$dec" | tr '\n' ' ')"
    [ -z "$later" ] && info "ok   review covers HEAD (reviewed $sha)" || miss "changed after the reviewed commit $sha: $later"
  fi

  # b. Nobody flagged a taste or product call for the owner.
  flags="$(grep -nE '^(- )?owner-review: required' "$dec")"
  [ -z "$flags" ] && info "ok   no owner-review flag" || miss "owner review requested in $dec: $flags"
fi

# Owner-only flags removed by any commit on the branch (added then deleted counts too).
removed="$(git log -p --format= "$base..HEAD" -- "docs/work/$(issue_number)-*" \
  | grep -E '^-((- )?owner-review: required|owner-approval: required)')"
[ -z "$removed" ] && info "ok   no owner flag removed" || miss "owner flag removed on this branch: $removed"

# c. The diff leaves the gate files alone. --no-renames: a moved file shows both paths.
touched=""
while IFS= read -r f; do
  matches_any "$f" "$GATE_FILES" && touched="$touched $f"
done < <(git diff --name-only --no-renames "$base" HEAD)
[ -z "$touched" ] && info "ok   no gate files changed" || miss "gate files changed:$touched"

[ $fail -eq 0 ] || { red "FAIL agent-approval: owner approval needed"; exit 1; }
green "PASS agent-approval"
