#!/usr/bin/env bash
# decision-log.sh "<section>" ["<section>" ...]: each section of the issue's decisions.md
# must end in "Verdict: PASS".
# Docs-only lane: on a branch that touches docs and nothing else (docs_only in common.sh),
# "Spec gate" and "Plan gate" may be absent or say "Verdict: N/A — docs-only": there is no
# behaviour to specify or plan, and filling them with "N/A — same reason" is ceremony. Every
# other section, the pre-merge gate included, is still required.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

[ -n "$(issue_number)" ] || { red "FAIL decision-log: branch must be named <type>/<issue>-<slug>"; exit 1; }
dec="$(decisions_file)"
[ -n "$dec" ] && [ -f "$dec" ] || { red "FAIL decision-log: docs/work/$(issue_number)-<slug>/decisions.md missing"; exit 1; }

docs=""
docs_only && docs=1
fail=0
for s in "$@"; do
  v="$(section_verdict "$dec" "$s")"
  if [ "$v" = "PASS" ]; then info "ok   $s: PASS"
  elif [ -n "$docs" ] && { [ "$s" = "Spec gate" ] || [ "$s" = "Plan gate" ]; }; then
    if ! grep -qx "## $s" "$dec"; then info "ok   $s: not needed (docs-only branch)"
    else
      case "$v" in
        "N/A — docs-only"*) info "ok   $s: $v" ;;
        *) red "  miss $s: ${v:-no verdict} — docs-only branch: delete the section or set 'Verdict: N/A — docs-only'"; fail=1 ;;
      esac
    fi
  else red "  miss $s: ${v:-no verdict}"; fail=1
  fi
done
[ $fail -eq 0 ] || { red "FAIL decision-log ($dec)"; exit 1; }
green "PASS decision-log ($dec)"
