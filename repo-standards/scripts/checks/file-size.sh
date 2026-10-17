#!/usr/bin/env bash
# Changed source files stay under MAX_FILE_LINES (locality; forces the split early).
# Only changed files are checked, and a file already over the limit on the base is
# grandfathered: it blocks only when the branch makes it longer. Without that, the first
# small fix to any legacy big file would block the push until someone split it.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

over=0; n=0; base="$(base_commit)"
for f in $(changed_files); do
  matches_any "$f" "$FILE_SIZE_GLOBS" || continue
  n=$((n + 1))
  lines=$(wc -l < "$f" | tr -d ' ')
  [ "$lines" -gt "$MAX_FILE_LINES" ] || continue
  # Length on the base; empty when the file is new there (a rename counts as new).
  was=""
  if [ -n "$base" ] && git cat-file -e "$base:$f" 2>/dev/null; then was="$(git show "$base:$f" | wc -l | tr -d ' ')"; fi
  if [ -n "$was" ] && [ "$was" -gt "$MAX_FILE_LINES" ] && [ "$lines" -le "$was" ]; then
    info "over limit but not grown: $f ($lines lines)"
  elif [ -n "$was" ] && [ "$was" -gt "$MAX_FILE_LINES" ]; then
    red "  over $f: $lines lines, was $was on base (max $MAX_FILE_LINES) — keep it at $was lines or fewer, or split it"; over=1
  else
    red "  over $f: $lines lines (max $MAX_FILE_LINES)"; over=1
  fi
done
info "file-size: $n changed source file(s) checked"
[ $over -eq 0 ] || { red "FAIL file-size: split the file(s) above, or (already over on base) do not make them longer"; exit 1; }
green "PASS file-size"
