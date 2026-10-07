#!/usr/bin/env bash
# decision-log.sh "<section>" ["<section>" ...]: each section of the issue's decisions.md
# must end in "Verdict: PASS".
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

[ -n "$(issue_number)" ] || { red "FAIL decision-log: branch must be named <type>/<issue>-<slug>"; exit 1; }
dec="$(decisions_file)"
[ -n "$dec" ] && [ -f "$dec" ] || { red "FAIL decision-log: docs/work/$(issue_number)-<slug>/decisions.md missing"; exit 1; }

fail=0
for s in "$@"; do
  v="$(section_verdict "$dec" "$s")"
  if [ "$v" = "PASS" ]; then info "ok   $s: PASS"
  else red "  miss $s: ${v:-no verdict}"; fail=1
  fi
done
[ $fail -eq 0 ] || { red "FAIL decision-log ($dec)"; exit 1; }
green "PASS decision-log ($dec)"
