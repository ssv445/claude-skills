#!/usr/bin/env bash
# Shared helpers for .standards/ scripts. Bash 3.2 compatible (macOS default): no
# associative arrays, no mapfile.

ROOT="$(git rev-parse --show-toplevel)" || exit 1
cd "$ROOT" || exit 1
# shellcheck source=/dev/null
. "$ROOT/.standards/config.sh"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
info()  { printf '  %s\n' "$*"; }

# Base commit the branch is compared against: the merge-base with the remote base
# branch when it exists, else the local one.
base_commit() {
  git merge-base "origin/$BASE_BRANCH" HEAD 2>/dev/null || git merge-base "$BASE_BRANCH" HEAD
}

# Files added/copied/modified/renamed on this branch, one per line.
changed_files() {
  git diff --name-only --diff-filter=ACMR "$(base_commit)" HEAD
}

# matches_any <file> <space-separated globs>. Globs are matched with [[ == ]], where
# * also matches "/", so "src/*" covers every depth under src/.
matches_any() {
  local f="$1" g
  set -f
  for g in $2; do
    # shellcheck disable=SC2053
    if [[ "$f" == $g ]]; then set +f; return 0; fi
  done
  set +f
  return 1
}

# Issue number from a branch named <type>/<issue>-<slug>.
issue_number() {
  git rev-parse --abbrev-ref HEAD | sed -n 's#^[a-z]*/\([0-9][0-9]*\)-.*#\1#p'
}

# docs/work/<issue>-<slug>/ for the current branch, or empty.
issue_dir() {
  local n d
  n="$(issue_number)"
  [ -n "$n" ] || return 0
  for d in docs/work/"$n"-*/; do
    [ -d "$d" ] && { printf '%s\n' "${d%/}"; return 0; }
  done
}

decisions_file() {
  local d
  d="$(issue_dir)"
  [ -n "$d" ] && printf '%s/decisions.md\n' "$d"
}

# section_verdict <file> <section heading text> → prints the Verdict value, or nothing.
section_verdict() {
  awk -v h="## $2" '
    $0 == h { inside = 1; next }
    inside && /^## / { inside = 0 }
    inside && /^Verdict:/ { sub(/^Verdict:[ \t]*/, ""); print; exit }
  ' "$1"
}

# section_field <file> <section heading text> <line prefix> → prints what follows the
# first line in that section starting with the prefix, e.g. "- Reviewer A:".
section_field() {
  awk -v h="## $2" -v p="$3" '
    $0 == h { inside = 1; next }
    inside && /^## / { inside = 0 }
    inside && index($0, p) == 1 { s = substr($0, length(p) + 1); sub(/^[ \t]*/, "", s); print s; exit }
  ' "$1"
}

# owner_flag_re <review|approval>: ERE (use with grep -i, after "^") for an owner flag
# line, tolerant of case, spacing after the colon, a "- " bullet and * / _ emphasis.
owner_flag_re() { printf '(- )?[*_]*owner-%s:[[:space:]]*required' "$1"; }

# run_cmd <label> <command string>. Empty command = N/A in config, reported as SKIP.
run_cmd() {
  local label="$1" cmd="$2" start rc
  if [ -z "$cmd" ]; then info "SKIP $label (N/A in config)"; return 0; fi
  start=$(date +%s)
  info "RUN  $label: $cmd"
  eval "$cmd"
  rc=$?
  if [ $rc -ne 0 ]; then red "FAIL $label (exit $rc)"; return 1; fi
  green "PASS $label ($(( $(date +%s) - start ))s)"
}
