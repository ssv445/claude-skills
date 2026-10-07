#!/usr/bin/env bash
# agent-approval.sh: may the agent approve this branch itself? Exit 0 = yes; otherwise
# prints each reason the owner's approval is needed. bin/ship asks it when the PR has no
# owner `approved` label.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

# Files holding the rules that judge a change. An agent never approves a change to them.
GATE_FILES="bin/* .standards/* .claude/* .github/* CLAUDE.md */CLAUDE.md AGENTS.md */AGENTS.md docs/guidelines/repo-standards.md"

fail=0
miss() { red "  miss $*"; fail=1; }
starts_pass() { case "$1" in PASS*) return 0 ;; *) return 1 ;; esac; }

dec="$(decisions_file)"
if [ -z "$dec" ] || [ ! -f "$dec" ]; then
  miss "no decisions.md for this branch (docs/work/<issue>-<slug>/)"
else
  # a. Pre-merge gate passed, by both reviewers or by the arbiter's ruling.
  v="$(section_verdict "$dec" "Pre-merge gate")"
  [ "$v" = "PASS" ] && info "ok   Pre-merge gate: PASS" || miss "Pre-merge gate: ${v:-no verdict}"
  a="$(section_field "$dec" "Pre-merge gate" "- Reviewer A:")"
  b="$(section_field "$dec" "Pre-merge gate" "- Reviewer B:")"
  arb="$(section_field "$dec" "Pre-merge gate" "- Arbiter:")"
  if starts_pass "$a" && starts_pass "$b"; then info "ok   both reviewers PASS"
  elif starts_pass "$arb"; then info "ok   reviewers disagreed; arbiter PASS"
  else miss "reviewers not both PASS and no arbiter PASS (A: ${a:-empty}; B: ${b:-empty}; Arbiter: ${arb:-empty})"
  fi
  # b. Nobody flagged a taste or product call for the owner.
  flags="$(grep -n '^owner-review: required' "$dec")"
  [ -z "$flags" ] && info "ok   no owner-review flag" || miss "owner review requested in $dec: $flags"
fi

# c. The diff leaves the gate files alone (deletions count too).
touched=""
while IFS= read -r f; do
  matches_any "$f" "$GATE_FILES" && touched="$touched $f"
done < <(git diff --name-only "$(base_commit)" HEAD)
[ -z "$touched" ] && info "ok   no gate files changed" || miss "gate files changed:$touched"

[ $fail -eq 0 ] || { red "FAIL agent-approval: owner approval needed"; exit 1; }
green "PASS agent-approval"
