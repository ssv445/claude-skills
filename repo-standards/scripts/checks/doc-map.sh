#!/usr/bin/env bash
# Doc map: code that changed must carry its mapped doc change in the same branch,
# or a "docs-unchanged: <doc> — reason" line in decisions.md.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

map="docs/doc-map.txt"
[ -f "$map" ] || { red "FAIL doc-map: $map missing"; exit 1; }

changed="$(changed_files)"
dec="$(decisions_file)"
missing=0; checked=0
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  pattern="${line%% -> *}"; doc="${line#* -> }"
  hit=""
  for f in $changed; do
    # shellcheck disable=SC2053
    [[ "$f" == $pattern ]] && { hit="$f"; break; }
  done
  [ -n "$hit" ] || continue
  checked=$((checked + 1))
  if printf '%s\n' "$changed" | grep -qxF "$doc"; then
    info "ok   $pattern → $doc (updated)"
  elif [ -n "$dec" ] && [ -f "$dec" ] && grep -qF "docs-unchanged: $doc — " "$dec" && grep -F "docs-unchanged: $doc — " "$dec" | grep -q '^docs-unchanged: .* — [^<]'; then
    info "ok   $pattern → $doc (docs-unchanged recorded)"
  else
    red "  miss $pattern changed ($hit) but $doc did not"; missing=$((missing + 1))
  fi
done < "$map"

info "doc-map: $checked mapped area(s) touched"
[ $missing -eq 0 ] || { red "FAIL doc-map: $missing doc(s) drifted — update them (doc sync stage)"; exit 1; }
green "PASS doc-map"
