#!/usr/bin/env bash
# Changed source files stay under MAX_FILE_LINES (locality; forces the split early), and new
# evidence images under docs/work/ stay under EVIDENCE_MAX_KB (they belong on the PR).
# Only changed files are checked, and a file already over the limit on the base is
# grandfathered: it blocks only when the branch makes it longer. Without that, the first
# small fix to any legacy big file would block the push until someone split it.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

over=0; n=0; base="$(base_commit)"
# Renames on the branch, "<old>\t<new>" per line (git's rename detection): a grandfathered file
# moved to a new path keeps its base length, or a pure move would block like a new file.
renames="$([ -n "$base" ] && git -c core.quotePath=false diff --name-status -M --diff-filter=R "$base" HEAD | cut -f2-)"
for f in $(changed_files); do
  matches_any "$f" "$FILE_SIZE_GLOBS" || continue
  n=$((n + 1))
  lines=$(wc -l < "$f" | tr -d ' ')
  [ "$lines" -gt "$MAX_FILE_LINES" ] || continue
  # Length on the base, at the same path or (renamed) the old one; empty when the file is new.
  was=""; from="$f"
  if [ -n "$base" ] && ! git cat-file -e "$base:$f" 2>/dev/null; then
    from="$(printf '%s\n' "$renames" | awk -F'\t' -v f="$f" '$2 == f { print $1; exit }')"
  fi
  if [ -n "$from" ] && [ -n "$base" ] && git cat-file -e "$base:$from" 2>/dev/null; then was="$(git show "$base:$from" | wc -l | tr -d ' ')"; fi
  as=""; [ "$from" = "$f" ] || as=" as $from"
  if [ -n "$was" ] && [ "$was" -gt "$MAX_FILE_LINES" ] && [ "$lines" -le "$was" ]; then
    if [ -n "$as" ]; then info "over limit but not grown: $f ($lines lines; was $was$as)"
    else info "over limit but not grown: $f ($lines lines)"; fi
  elif [ -n "$was" ] && [ "$was" -gt "$MAX_FILE_LINES" ]; then
    red "  over $f: $lines lines, was $was on base$as (max $MAX_FILE_LINES) — keep it at $was lines or fewer, or split it"; over=1
  else
    red "  over $f: $lines lines (max $MAX_FILE_LINES)"; over=1
  fi
done
info "file-size: $n changed source file(s) checked"

# Evidence: screenshots and recordings go on the PR, not into git (one repo had 36 MB of them
# under docs/work/). A new image or video there over EVIDENCE_MAX_KB fails; a small diagram may
# stay. Only files new at their path (added, or renamed/moved in): evidence already there on
# the base is not this branch's to move.
max_kb="${EVIDENCE_MAX_KB:-300}"; imgs=0; big=0
while IFS= read -r f; do
  case "$f" in docs/work/*) ;; *) continue ;; esac
  case "$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')" in *.png|*.jpg|*.jpeg|*.gif|*.webp|*.heic|*.mp4|*.mov|*.webm) ;; *) continue ;; esac
  imgs=$((imgs + 1))
  kb=$(( ($(wc -c < "$f") + 1023) / 1024 ))
  [ "$kb" -le "$max_kb" ] || { red "  over $f: $kb KB (max $max_kb KB) — attach it to the PR instead (gh pr create|edit --attach ./$f) and remove it from the branch"; big=1; }
done < <([ -n "$base" ] && git -c core.quotePath=false diff -z --name-only -M --diff-filter=AR "$base" HEAD | tr '\0' '\n')
info "file-size: $imgs new image(s) under docs/work/ checked"

[ $over -eq 0 ] || red "FAIL file-size: split the file(s) above, or (already over on base) do not make them longer"
[ $big -eq 0 ] || red "FAIL file-size: evidence images belong on the PR, not in git"
[ $((over + big)) -eq 0 ] || exit 1
green "PASS file-size"
