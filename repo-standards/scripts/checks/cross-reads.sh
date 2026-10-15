#!/usr/bin/env bash
# Cross-reads: a check skipped by change class must not read a changed file. App tests that read
# site or docs files, and site code that reads docs files, make those files shared: they must be
# in SHARED_GLOBS (config.sh), so changing one runs everything. Runs on every class, because a
# new cross-read arrives in a test file of either side.
# What it sees: every quoted literal holding a "/" (leading ../ stripped), classed with
# file_part; a directory counts by the files under it. A path built from parts is not seen.
# Off (SKIP) while change classes are off or CROSS_READS_APP_FILES / CROSS_READS_SITE_FILES are empty.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

[ -n "$SITE_GLOBS$DOCS_GLOBS" ] || { info "SKIP cross-reads (change classes not configured)"; exit 0; }
[ -n "$CROSS_READS_APP_FILES$CROSS_READS_SITE_FILES" ] || { info "SKIP cross-reads (no CROSS_READS_*_FILES in config)"; exit 0; }

# literals <pathspec...>: the quoted path literals in the tracked files matching them, one per
# line. Tracked files only: installed packages and build output are not the repo's code.
literals() {
  git ls-files -z -- "$@" \
    | xargs -0 grep -hoE "[\"'\`](\.\./)*[A-Za-z0-9_.@-]+(/[A-Za-z0-9_.@ -]+)+/?[\"'\`]" 2>/dev/null \
    | sed -E "s#^[\"'\`](\.\./)*##; s#/?[\"'\`]\$##" | sort -u
}

# part_of <path>: file_part of the path, or of a file under it when it is a directory.
part_of() {
  if [ -d "$1" ]; then file_part "$1/x"; else file_part "$1"; fi
}

# Fails closed: a configured side with no file to scan means the listing broke, not that
# nothing reads across.
count() { git ls-files -- "$@" | wc -l | tr -d ' '; }
app_files=0; site_files=0
if [ -n "$CROSS_READS_APP_FILES" ]; then
  # shellcheck disable=SC2086
  app_files="$(count $CROSS_READS_APP_FILES)"
  [ "$app_files" -gt 0 ] || { red "FAIL cross-reads: no file matches CROSS_READS_APP_FILES ($CROSS_READS_APP_FILES)"; exit 1; }
fi
if [ -n "$CROSS_READS_SITE_FILES" ]; then
  # shellcheck disable=SC2086
  site_files="$(count $CROSS_READS_SITE_FILES)"
  [ "$site_files" -gt 0 ] || { red "FAIL cross-reads: no file matches CROSS_READS_SITE_FILES ($CROSS_READS_SITE_FILES)"; exit 1; }
fi

miss=""; n=0   # miss: one "\n  <side> reads <path>" per path
if [ -n "$CROSS_READS_APP_FILES" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n=$((n + 1))
    case "$(part_of "$p")" in site | docs) miss="$miss\n  app tests read $p" ;; esac
  # shellcheck disable=SC2086
  done <<<"$(literals $CROSS_READS_APP_FILES)"
fi
if [ -n "$CROSS_READS_SITE_FILES" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n=$((n + 1))
    [ "$(part_of "$p")" = docs ] && miss="$miss\n  site reads $p"
  # shellcheck disable=SC2086
  done <<<"$(literals $CROSS_READS_SITE_FILES)"
fi

info "cross-reads: $n path literal(s) in $app_files app and $site_files site file(s) checked"
if [ -n "$miss" ]; then
  red "FAIL cross-reads: add these to SHARED_GLOBS in .standards/config.sh, or a skipped check could read a changed file:"
  printf '%b\n' "${miss#\\n}"
  exit 1
fi
green "PASS cross-reads"
