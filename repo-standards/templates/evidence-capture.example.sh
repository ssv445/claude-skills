#!/usr/bin/env bash
# evidence-capture.sh: this repo's one way to capture the standard evidence set for a PR (rulebook,
# stage 8): a screenshot of each page at each supported viewport in each theme, from the running
# app, into a new temp dir. Prints the files it wrote, one per line, last on stdout (everything else
# goes to stderr), so they can be attached with `gh pr edit <pr> --attach <file>`. Exits non-zero
# when any capture failed. Set EVIDENCE_CMD="scripts/evidence-capture.sh" in .standards/config.sh.
# Template from the repo-standards skill: adapt the variables below, keep the contract. Bash 3.2.
#
# Usage: scripts/evidence-capture.sh [--dry-run] [path ...]
#   path ...    pages to capture, relative to BASE_URL (default: PAGES below)
#   --dry-run   print each planned capture and the file list; runs no browser, writes nothing
#
# Driven by agent-browser in its own session, which it closes at the end. Viewport screenshots,
# not full-page ones: stitching a full page repeats sticky headers and footers mid-page.
set -u

# --- Adapt to the repo (each can also be set from the environment) ---
BASE_URL="${EVIDENCE_BASE_URL:-http://localhost:3000}"      # the app running locally; never production
PAGES="${EVIDENCE_PAGES:-/}"                                # space-separated paths to capture
VIEWPORTS="${EVIDENCE_VIEWPORTS:-390x844 360x740 844x390}"  # WxH, each viewport the product supports
THEMES="${EVIDENCE_THEMES:-light dark}"                     # each theme the product ships
# How a theme is applied. Empty: THEMES are colour-scheme names (light, dark), set with
# `agent-browser set media`. Otherwise JavaScript run in the page, with {theme} replaced by the
# theme's name, e.g.  document.documentElement.dataset.theme = "{theme}"
THEME_JS="${EVIDENCE_THEME_JS:-}"
SETTLE_MS="${EVIDENCE_SETTLE_MS:-500}"                       # wait after each change (fonts, animations)

dry=""
if [ "${1:-}" = --dry-run ]; then dry=1; shift; fi
[ $# -eq 0 ] || PAGES="$*"

say() { printf '%s\n' "$*" >&2; }
# slug <path>: a file-name part for a page: "/" is "home", "/settings/team" is "settings-team".
slug() {
  local s
  s="$(printf '%s' "$1" | sed 's#^/*##; s#/*$##; s#[^A-Za-z0-9._-]#-#g')"
  printf '%s\n' "${s:-home}"
}

# Every viewport is checked before anything runs, so a typo never wastes a capture run.
for vp in $VIEWPORTS; do
  printf '%s\n' "$vp" | grep -qE '^[0-9]+x[0-9]+$' || { say "FAIL evidence: viewport '$vp' is not WxH (e.g. 390x844)"; exit 2; }
done
[ -n "$PAGES" ] && [ -n "$THEMES" ] || { say "FAIL evidence: PAGES and THEMES must name at least one each"; exit 2; }

if [ -n "$dry" ]; then
  out="${TMPDIR:-/tmp}"; out="${out%/}/evidence.DRY-RUN"
else
  command -v agent-browser > /dev/null || { say "FAIL evidence: agent-browser is not installed"; exit 2; }
  out="$(mktemp -d "${TMPDIR:-/tmp}/evidence.XXXXXX")" || { say "FAIL evidence: cannot make a temp dir"; exit 2; }
  session="evidence-$$"
  # ab <args>: one agent-browser command in this script's own session; its output to stderr.
  ab() { agent-browser --session "$session" "$@" >&2; }
  trap 'agent-browser --session "$session" close > /dev/null 2>&1' EXIT
  ab open about:blank || { say "FAIL evidence: agent-browser cannot start a browser"; exit 2; }
fi

# apply_theme <theme>: as THEME_JS says (see above).
apply_theme() {
  if [ -z "$THEME_JS" ]; then ab set media "$1"
  else ab eval "${THEME_JS//\{theme\}/$1}"; fi
}

files=(); failed=0
for page in $PAGES; do
  for vp in $VIEWPORTS; do
    w="${vp%x*}"; h="${vp#*x}"
    for theme in $THEMES; do
      file="$out/$(slug "$page")-${w}x${h}-$theme.png"
      if [ -n "$dry" ]; then
        say "would set viewport ${w}x${h} and theme $theme, then load $BASE_URL$page → $file"
        files+=("$file"); continue
      fi
      # Size and theme first, then a fresh load per capture: the page renders at that size in that
      # theme from its first paint, and nothing one capture left behind shows in the next. A
      # THEME_JS theme lives in the page's origin (storage, attributes), so it is set on the loaded
      # page and the page is loaded again.
      if ab set viewport "$w" "$h" && { [ -n "$THEME_JS" ] || apply_theme "$theme"; } && ab open "$BASE_URL$page" \
         && { [ -z "$THEME_JS" ] || { apply_theme "$theme" && ab reload; }; } \
         && ab wait "$SETTLE_MS" && ab screenshot "$file" && [ -s "$file" ]; then
        say "ok   $page ${w}x${h} $theme"
        files+=("$file")
      else
        say "FAIL $page ${w}x${h} $theme"
        failed=$((failed + 1))
      fi
    done
  done
done

[ ${#files[@]} -eq 0 ] || printf '%s\n' "${files[@]}"
if [ $failed -gt 0 ]; then say "FAIL evidence: $failed capture(s) failed; the files above are the ones that worked"; exit 1; fi
say "${dry:+DRY RUN: }${#files[@]} file(s) in $out"
