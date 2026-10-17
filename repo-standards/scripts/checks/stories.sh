#!/usr/bin/env bash
# User stories (optional): runs only when docs/user-stories/ exists. Every "Covered by" line
# names real tests, so a renamed or deleted test cannot leave a story claiming coverage:
#   **Covered by:** `tests/x.test.ts` "test name" and "other name"; `e2e/run.mjs` "check 3"
#   **Covered by:** manual only (haptics cannot be checked in simulators)
# Each test file (a relative path with a / and an .ext, backticked or bare) must exist; each
# "quoted name" after it must appear literally in that file (a trailing "..." cuts it short:
# the rest must appear). A line naming no file must say "manual only". Lines in code fences
# or indented 4+ spaces are examples and skipped.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

dir="docs/user-stories"
[ -d "$dir" ] || { green "PASS stories (N/A: no docs/user-stories/)"; exit 0; }
set -- "$dir"/*.md
[ -f "$1" ] || { green "PASS stories (N/A: no .md file in $dir/)"; exit 0; }

# One record per line, fields split by \037 (tab would collapse empty fields in read):
#   C src line id                 a Covered by line
#   F src line id file            a file it names
#   N src line id file name       a test name, with the file before it (empty: none)
#   X src line id                 neither a file nor "manual only"
# Bytes, not characters (LC_ALL=C): stories hold non-ASCII text, which BSD awk can fail to
# decode mid-line; every delimiter looked for here is ASCII (curly quotes are matched as bytes).
records="$(LC_ALL=C awk '
  # A test file: a relative path with a directory and an extension. `/ws` (a route) and
  # `synced.all` (a name) are not.
  function isfile(t) { return t !~ /^\// && t ~ /\// && t ~ /\.[A-Za-z0-9]+$/ }
  FNR == 1 { fence = 0; id = "" }
  /^[ \t]*(```|~~~)/ { fence = !fence; next }
  fence || /^(    |\t)/ { next }
  /^#+[ \t]+US-[A-Z0-9]+-[0-9]+/ { match($0, /US-[A-Z0-9]+-[0-9]+/); id = substr($0, RSTART, RLENGTH); next }
  /^(   |  | )?([-*][ \t]+)?(\*\*|__)?Covered by/ {
    r = substr($0, index($0, "Covered by") + 10)
    gsub(/“|”/, "\"", r)
    S = "\037"; pre = FILENAME S FNR S id
    print "C" S pre
    file = ""; nf = 0; i = 1; n = length(r)
    while (i <= n) {
      c = substr(r, i, 1)
      if (c == "\"" || c == "`") {
        j = index(substr(r, i + 1), c); if (!j) break
        tok = substr(r, i + 1, j - 1); i += j + 1
        if (c == "`") { if (isfile(tok)) { file = tok; nf++; print "F" S pre S file } }
        else if (tolower(tok) != "manual only") print "N" S pre S file S tok
        continue
      }
      if (c ~ /[ \t]/) { i++; continue }
      # A bare word: a path when it looks like one, once wrapping punctuation is dropped.
      tok = substr(r, i); sub(/[ \t"`].*/, "", tok); i += length(tok)
      sub(/^[(]+/, "", tok); sub(/[,;:.)]+$/, "", tok)
      if (isfile(tok)) { file = tok; nf++; print "F" S pre S file }
    }
    if (!nf && tolower(r) !~ /manual only/) print "X" S pre
  }
' "$@")" || { red "FAIL stories: could not read $dir/*.md"; exit 1; }

# name_in <name> <file>: the name appears literally in the file. "..." (or "…") cuts a long
# name short, at the end or in the middle: then each part between the dots must appear.
name_in() {
  local rest="${1//…/...}" part seen=""
  while [ -n "$rest" ]; do
    part="${rest%%...*}"
    if [ "$part" = "$rest" ]; then rest=""; else rest="${rest#*...}"; fi
    while [ "${part# }" != "$part" ]; do part="${part# }"; done
    while [ "${part% }" != "$part" ]; do part="${part% }"; done
    [ -n "$part" ] || continue
    grep -qF -- "$part" "$2" || return 1
    seen=1
  done
  [ -n "$seen" ]
}

lines=0; files=0; names=0; bad=0
while IFS=$'\037' read -r kind src line id file name; do
  at="$src:$line${id:+ ($id)}"
  case "$kind" in
    C) lines=$((lines + 1)) ;;
    F) files=$((files + 1))
       [ -f "$file" ] || { red "  miss $at: $file does not exist — fix the path in the Covered by line"; bad=1; } ;;
    N) names=$((names + 1))
       if [ -z "$file" ]; then red "  miss $at: \"$name\" has no \`<test file>\` before it — name the file first"; bad=1
       elif [ -f "$file" ] && ! name_in "$name" "$file"; then
         red "  miss $at: $file has no \"$name\" — use the test's exact name, or fix the Covered by line"; bad=1
       fi ;;
    X) red "  miss $at: Covered by names no test file — write \`<test file>\` \"<test name>\", or manual only"; bad=1 ;;
  esac
done <<<"$records"
info "stories: $lines Covered by line(s), $files file reference(s), $names test name(s) checked in $dir/"
[ $bad -eq 0 ] || { red "FAIL stories: fix the Covered by lines above (same PR as the test change)"; exit 1; }
green "PASS stories"
