#!/usr/bin/env bash
# User stories (optional): runs only when docs/user-stories/ exists. Every "Covered by" line
# names real tests, so a renamed or deleted test cannot leave a story claiming coverage:
#   **Covered by:** `tests/x.test.ts` "test name" and "other name"; `e2e/run.mjs` "check 3"
#   **Covered by:** manual only (haptics cannot be checked in simulators)
# Each test file (a relative path with a / and an .ext, never a URL: backticked, or bare when it
# matches TEST_GLOBS) must exist; each "quoted name" after it must appear literally in that file
# ("..." cuts it short). Other bare words are prose. A line naming no file must say "manual
# only", and a line that starts with it is not path-checked. Code fences and lines indented 4+
# spaces are skipped.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

dir="docs/user-stories"
[ -d "$dir" ] || { green "PASS stories (N/A: no docs/user-stories/)"; exit 0; }
set -- "$dir"/*.md
[ -f "$1" ] || { green "PASS stories (N/A: no .md file in $dir/)"; exit 0; }

# One record per line, fields split by \037 (tab would collapse empty fields in read):
#   C src line id                 a Covered by line
#   F src line id file            a backticked file it names
#   B src line id word            a bare word that looks like a path (a file if it matches TEST_GLOBS)
#   N src line id - name          a test name (bash pairs it with the file before it)
#   E src line id manual          end of the line; manual = 1 when it says "manual only"
# Bytes, not characters (LC_ALL=C): stories hold non-ASCII text, which BSD awk can fail to
# decode mid-line; every delimiter looked for here is ASCII (curly quotes are matched as bytes).
records="$(LC_ALL=C awk '
  # A test file (only ever a backticked token): a relative path with a directory and an
  # extension. `/ws` (a route), `synced.all` (a name) and anything with :// (a URL) are not.
  function isfile(t) { return t !~ /^\// && t !~ /:\/\// && t ~ /\// && t ~ /\.[A-Za-z0-9]+$/ }
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
    # "Covered by: manual only ..." is never path-checked: whatever follows is a note.
    lead = tolower(r); sub(/^[:*_ \t]+/, "", lead)
    if (index(lead, "manual only") == 1) n = 0
    while (i <= n) {
      c = substr(r, i, 1)
      if (c == "\"" || c == "`") {
        j = index(substr(r, i + 1), c); if (!j) break
        tok = substr(r, i + 1, j - 1); i += j + 1
        if (c == "`") { if (isfile(tok)) print "F" S pre S tok }
        else if (tolower(tok) != "manual only") print "N" S pre S S tok
        continue
      }
      if (c ~ /[ \t]/) { i++; continue }
      # A bare word: offered to bash, which keeps it only when it matches TEST_GLOBS.
      tok = substr(r, i); sub(/[ \t"`].*/, "", tok); i += length(tok)
      sub(/^[(]+/, "", tok); sub(/[,;:.)]+$/, "", tok)
      if (isfile(tok)) print "B" S pre S tok
    }
    print "E" S pre S (tolower(r) ~ /manual only/ ? 1 : 0)
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

lines=0; files=0; names=0; bad=0; cur=""; nf=0
while IFS=$'\037' read -r kind src line id file name; do
  at="$src:$line${id:+ ($id)}"
  # A bare word is a test file only when it matches TEST_GLOBS: a URL or a "v1.2/v1.3" note is not.
  if [ "$kind" = B ]; then matches_any "$file" "$TEST_GLOBS" && kind=F || continue; fi
  case "$kind" in
    C) lines=$((lines + 1)); cur=""; nf=0 ;;
    F) files=$((files + 1)); cur="$file"; nf=1
       [ -f "$file" ] || { red "  miss $at: $file does not exist — fix the path in the Covered by line"; bad=1; } ;;
    N) names=$((names + 1))
       if [ -z "$cur" ]; then red "  miss $at: \"$name\" has no \`<test file>\` before it — name the file first"; bad=1
       elif [ -f "$cur" ] && ! name_in "$name" "$cur"; then
         red "  miss $at: $cur has no \"$name\" — use the test's exact name, or fix the Covered by line"; bad=1
       fi ;;
    E) if [ "$nf" = 0 ] && [ "$file" = 0 ]; then
         red "  miss $at: Covered by names no test file — write \`<test file>\` (a TEST_GLOBS path, or any path in backticks), then \"<test name>\"; or manual only"; bad=1
       fi ;;
  esac
done <<<"$records"
info "stories: $lines Covered by line(s), $files file reference(s), $names test name(s) checked in $dir/"
[ $bad -eq 0 ] || { red "FAIL stories: fix the Covered by lines above (same PR as the test change)"; exit 1; }
green "PASS stories"
