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

# approver_mode: APPROVER from the base's config.sh — "agent" only if it says so, else
# "owner". Read from the base, not the working copy, so a branch cannot switch the mode
# that judges it.
approver_mode() {
  local b m
  b="$(base_commit)"; [ -n "$b" ] || { echo owner; return; }
  m="$(git show "$b:.standards/config.sh" 2>/dev/null | sed -n 's/^APPROVER="\([a-z]*\)".*/\1/p' | tail -1)"
  [ "$m" = agent ] && echo agent || echo owner
}

# Files added/copied/modified/renamed on this branch, one per line, unquoted: -z keeps
# git from C-quoting non-ASCII names ("caf\303\251"), which would never match a glob.
changed_files() {
  git -c core.quotePath=false diff -z --name-only --diff-filter=ACMR "$(base_commit)" HEAD | tr '\0' '\n'
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

# owner_flag_re <review|approval>: anchored ERE (use with grep -i) for an owner flag line.
# Fails closed: any line naming the flag with "required" later on it counts, whatever the
# markdown around it — except lines indented 4+ spaces or a tab (the templates' examples).
# For approval, "required" must come before any "#" comment and not as "not-required", so
# the spec template's default "owner-approval: not-required   # required if: …" is no flag.
owner_flag_re() {
  case "$1" in
    review)   printf '^ {0,3}([^ \t].*)?owner-review.*required' ;;
    approval) printf '^ {0,3}([^ \t].*)?owner-approval([^#]*[^#-])?required' ;;
  esac
}

# section_count <file> <section heading text> <line prefix> → how many lines in that
# section start with the prefix.
section_count() {
  awk -v h="## $2" -v p="$3" '
    $0 == h { inside = 1; next }
    inside && /^## / { inside = 0 }
    inside && index($0, p) == 1 { n++ }
    END { print n + 0 }
  ' "$1"
}

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
