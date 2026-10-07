#!/usr/bin/env bash
# Changed source files stay under MAX_FILE_LINES (locality; forces the split early).
# Only changed files are checked, so an existing large file blocks only when touched.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

over=0; n=0
for f in $(changed_files); do
  matches_any "$f" "$FILE_SIZE_GLOBS" || continue
  n=$((n + 1))
  lines=$(wc -l < "$f" | tr -d ' ')
  if [ "$lines" -gt "$MAX_FILE_LINES" ]; then red "  over $f: $lines lines (max $MAX_FILE_LINES)"; over=1; fi
done
info "file-size: $n changed source file(s) checked"
[ $over -eq 0 ] || { red "FAIL file-size: split the file(s) above"; exit 1; }
green "PASS file-size"
