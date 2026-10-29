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

# run_timed <seconds> <command...>: runs the command in its own process group (set -m), so
# a timeout stops it and everything it started — and nothing else. Returns its exit code;
# on timeout sets timed_out=1 and returns 124. macOS ships no `timeout`, hence this. A
# watcher polls once a second; a command that ends sooner returns at once. stdin is
# /dev/null: under job control the job would otherwise share the terminal's.
run_timed() {
  local secs="$1" pid watcher rc flag old_int old_term
  shift
  timed_out=""
  flag="$(mktemp "${TMPDIR:-/tmp}/standards-timeout.XXXXXX")"; rm -f "$flag"
  set -m
  ( "$@" ) </dev/null &
  pid=$!
  set +m
  ( s=0
    while kill -0 "$pid" 2>/dev/null; do
      if [ "$s" -ge "$secs" ]; then
        : > "$flag"; kill -TERM -- "-$pid" 2>/dev/null; sleep 2; kill -KILL -- "-$pid" 2>/dev/null; exit 0
      fi
      sleep 1; s=$((s + 1))
    done ) &
  watcher=$!
  # Ctrl-C reaches only the terminal's foreground group, which the job is not in: pass it
  # on. The caller's own INT/TERM traps are put back afterwards, not reset.
  old_int="$(trap -p INT)"; old_term="$(trap -p TERM)"
  trap 'kill -TERM -- "-$pid" 2>/dev/null; kill "$watcher" 2>/dev/null; exit 130' INT TERM
  wait "$pid"; rc=$?
  trap - INT TERM
  eval "$old_int"; eval "$old_term"
  # On a timeout let the watcher finish, so its KILL reaches anything that ignored TERM.
  if [ -e "$flag" ]; then wait "$watcher"; rm -f "$flag"; timed_out=1; return 124; fi
  # Reaped here, quietly: otherwise bash reports the killed watcher ("Terminated") later.
  kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null
  return $rc
}

# bad_secs <label> <value>: a timeout must be empty (no limit) or a whole number of seconds
# above zero. Anything else ("10m", "0", "1.5") is reported and returns 0, so the caller
# fails its gate instead of running with no limit.
bad_secs() {
  case "$2" in
    '') return 1 ;;
    *[!0-9]*|0*) red "FAIL $1: timeout '$2' is not a whole number of seconds above zero (CMD_TIMEOUT / CLASS_<name>_TIMEOUT)"; return 0 ;;
  esac
  return 1
}

# run_limit <seconds or empty> <command...>: run_timed, or with no limit a plain subshell.
run_limit() {
  local secs="$1"; shift
  timed_out=""
  if [ -n "$secs" ]; then run_timed "$secs" "$@"; else ( "$@" ); fi
}

# run_cmd <label> <command string> [timeout seconds, default CMD_TIMEOUT]. Empty command =
# N/A in config, reported as SKIP. With a timeout, a command still running at it is
# stopped, with everything it started, and fails the gate. No timeout set: the command
# runs exactly as it always did.
run_cmd() {
  local label="$1" cmd="$2" secs="${3:-${CMD_TIMEOUT:-}}" start rc
  if [ -z "$cmd" ]; then info "SKIP $label (N/A in config)"; return 0; fi
  ! bad_secs "$label" "$secs" || return 1
  start=$(date +%s)
  info "RUN  $label: $cmd"
  timed_out=""
  if [ -n "$secs" ]; then run_timed "$secs" eval "$cmd"; else eval "$cmd"; fi
  rc=$?
  if [ -n "$timed_out" ]; then red "FAIL $label: timed out after ${secs}s and was stopped — $cmd"; return 1; fi
  if [ $rc -ne 0 ]; then red "FAIL $label (exit $rc)"; return 1; fi
  green "PASS $label ($(( $(date +%s) - start ))s)"
}

# heavy_lock_warn: WARN when HEAVY_LOCK (a lock file or dir the repo's heavy jobs hold) is
# older than HEAVY_LOCK_MAX_AGE seconds — a run that hung or died holding it. Warns only.
# GNU stat first: BSD stat has no -c and fails cleanly, while GNU's -f means something else.
heavy_lock_warn() {
  local m age max="${HEAVY_LOCK_MAX_AGE:-3600}"
  [ -n "${HEAVY_LOCK:-}" ] && [ -e "$HEAVY_LOCK" ] || return 0
  m="$(stat -c %Y "$HEAVY_LOCK" 2>/dev/null || stat -f %m "$HEAVY_LOCK" 2>/dev/null)" || return 0
  age=$(( $(date +%s) - m ))
  [ "$age" -le "$max" ] || red "WARN heavy lock $HEAVY_LOCK held ${age}s (max ${max}s) — a run may have hung or died holding it"
  return 0
}

# Every path the branch touches — added, edited, deleted, and both sides of a rename — one
# per line. Unlike changed_files, a deletion counts: removing code changes what tests see.
branch_files() {
  git -c core.quotePath=false diff -z --name-only --no-renames "$(base_commit)" HEAD | tr '\0' '\n'
}

# class_get <class> <field>: CLASS_<class>_<field> from config.sh, or empty.
class_get() { local v="CLASS_$1_$2"; printf '%s' "${!v}"; }

# class_key <class> <stage> <command>: the result-cache key — one hash over the class, stage
# and command, and every file under the class's paths at HEAD (path and blob id), minus
# IGNORE_PATHS. Files outside the paths (base-only standards changes, an unrelated rebase)
# leave it unchanged; any change under them, tests included, or to the command, does not.
class_key() {
  local paths line f t=$'\t'
  paths="$(class_get "$1" PATHS)"
  { printf '%s\n%s\n%s\n' "$1" "$2" "$3"
    git -c core.quotePath=false ls-tree -r -z HEAD | while IFS= read -r -d '' line; do
      f="${line#*"$t"}"
      matches_any "$f" "$paths" && ! matches_any "$f" "$IGNORE_PATHS" && printf '%s\n' "$line"
    done
  } | git hash-object --stdin
}

# state_dir: local run state (result cache, bin/chain results), in the git dir every
# worktree of this clone shares — so a pass in one worktree counts in the others — and
# never in the working tree.
state_dir() { printf '%s/standards-state\n' "$(cd "$(git rev-parse --git-common-dir)" && pwd -P)"; }

# run_classes <stage>: each class in TEST_CLASSES with a CLASS_<name>_<STAGE>_CMD runs only
# when the branch touches one of its paths (minus IGNORE_PATHS), and not again for content
# that already passed in this clone (state_dir/results, keyed by class_key, PASS only).
# With no base commit nothing can be compared, so every class runs. The full runs on the
# base branch nightly and before each release are what make skipping safe.
run_classes() {
  local stage="$1" up c cmd paths f hit key prev secs nobase="" rc=0 results
  results="$(state_dir)/results"
  up="$(printf '%s' "$stage" | tr '[:lower:]' '[:upper:]')"
  [ -n "$TEST_CLASSES" ] && [ -z "$(base_commit)" ] && { nobase=1; info "classes: no base commit to compare against — every class runs"; }
  for c in $TEST_CLASSES; do
    case "$c" in *[!A-Za-z0-9_]*) red "FAIL class '$c': a name is letters, digits and _ only"; rc=1; continue ;; esac
    cmd="$(class_get "$c" "${up}_CMD")"
    [ -n "$cmd" ] || continue
    secs="$(class_get "$c" TIMEOUT)"; secs="${secs:-${CMD_TIMEOUT:-}}"
    if bad_secs "$c $stage" "$secs"; then rc=1; continue; fi
    paths="$(class_get "$c" PATHS)"
    hit="$nobase"
    [ -n "$hit" ] || while IFS= read -r f; do
      [ -n "$f" ] && matches_any "$f" "$paths" && ! matches_any "$f" "$IGNORE_PATHS" && { hit="$f"; break; }
    done < <(branch_files)
    if [ -z "$hit" ]; then info "SKIP $c $stage (branch changes none of: $paths)"; continue; fi
    key="$(class_key "$c" "$stage" "$cmd")"
    prev="$(sed -n "s/^$key //p" "$results" 2>/dev/null | head -1)"
    if [ -n "$prev" ]; then info "ok   $c $stage: cached — same content passed at $prev"; continue; fi
    if run_cmd "$c $stage" "$cmd" "$secs"; then
      mkdir -p "${results%/*}" && printf '%s %s\n' "$key" "$(git rev-parse --short HEAD)" >> "$results"
    else rc=1
    fi
  done
  return $rc
}

# The files maintenance mode may skip tests for: the standards and their docs. Narrower
# than GATE_FILES on purpose — repos keep product code in bin/ and docs sites in docs/.
# Read from the base's copy of this file (standards_scan), so a branch cannot widen it.
# docs/work/* holds the branch's own spec and decision log, which every branch must carry.
STANDARDS_PATHS=".standards/* bin/ship bin/approve bin/chain bin/preflight .claude/settings.json CLAUDE.md */CLAUDE.md AGENTS.md */AGENTS.md docs/guidelines/* docs/templates/* docs/doc-map.txt docs/rule-changes.md docs/work/*"

# standards_scan: is this a standards-only branch, the only kind maintenance mode skips
# tests for? Sets std_files (every file the branch touches), std_other (those outside the
# base's STANDARDS_PATHS) and std_reason (why it cannot tell, e.g. no base: then nothing
# counts as standards-only — fail closed).
standards_scan() {
  local base paths
  std_files=""; std_other=""; std_reason=""
  base="$(base_commit)"; [ -n "$base" ] || { std_reason="no base commit to compare against"; return; }
  paths="$(git show "$base:.standards/lib/common.sh" 2>/dev/null | sed -n 's/^STANDARDS_PATHS="\(.*\)"$/\1/p')"
  [ -n "$paths" ] || { std_reason="the base's standards define no STANDARDS_PATHS (upgrade the base first)"; return; }
  std_files="$(branch_files)"
  std_other="$(printf '%s\n' "$std_files" | while IFS= read -r f; do
    [ -n "$f" ] && ! matches_any "$f" "$paths" && printf '%s\n' "$f"; done)"
}

# file_list <newline-separated files>: one line, at most 5 names, then how many more.
file_list() {
  local n
  n="$(printf '%s\n' "$1" | grep -c .)"
  printf '%s' "$(printf '%s\n' "$1" | grep . | head -5 | tr '\n' ' ')"
  [ "$n" -le 5 ] || printf '…and %s more' "$((n - 5))"
}

# review_covers_head <decisions file> <section>: the section's "Reviewed:" names a literal
# hex commit present locally, and every file the branch changes (the decisions file aside)
# has the same content there as at HEAD. A rebase onto unrelated base changes keeps the
# review; a later change to a reviewed file does not. Never HEAD, a branch, or a ref that
# merely looks like hex. Prints one line: the ok text, or the reason it fails (return 1).
review_covers_head() {
  local dec="$1" s="$2" sha full f later="" list
  sha="$(section_field "$dec" "$s" "Reviewed:")"
  full="$(git rev-parse -q --verify "$sha^{commit}" 2>/dev/null)"
  if ! printf '%s' "$sha" | grep -qE '^[0-9a-f]{7,40}$'; then
    printf "%s: 'Reviewed:' must be a commit sha, got '%s'\n" "$s" "${sha:-empty}"; return 1
  elif [ -z "$full" ] || [ "${full#"$sha"}" = "$full" ]; then
    printf '%s: reviewed commit %s is not present locally (fetch it, or review again)\n' "$s" "$sha"; return 1
  fi
  list="$(mktemp)"
  if ! git -c core.quotePath=false diff -z --name-only --no-renames "$(base_commit)" HEAD > "$list" 2>/dev/null; then
    rm -f "$list"; printf '%s: could not list the branch changes to compare with %s\n' "$s" "$sha"; return 1
  fi
  while IFS= read -r -d '' f; do
    [ "$f" != "$dec" ] || continue
    [ "$(git rev-parse -q --verify "$full:$f")" = "$(git rev-parse -q --verify "HEAD:$f")" ] || later="$later $f"
  done < "$list"
  rm -f "$list"
  [ -z "$later" ] || { printf '%s: differs from the reviewed commit %s:%s\n' "$s" "$sha" "$later"; return 1; }
  printf '%s: review covers HEAD (reviewed %s)\n' "$s" "$sha"
}

# label_check <issue-or-pr number> <label> <issue|pr>: stdout = time the label was last
# added; messages go to stderr so callers can capture the time. Needs gh and jq.
label_check() {
  local ev
  [ -n "${repo:-}" ] || repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)" || return 1
  # --slurp wraps all pages in one array, so "last" is the last event overall — gh's -q
  # would run the filter per page (30 events each) and miss or misattribute the label.
  ev="$(gh api "repos/$repo/issues/$1/events" --paginate --slurp \
        | jq -r "[.[][] | select(.event==\"labeled\" and .label.name==\"$2\")] | last | \"\(.actor.login) \(.created_at)\"")"
  gh "$3" view "$1" --json labels -q '.labels[].name' | grep -qx "$2" || ev=""
  set -- "$1" "$2" "$3" $ev
  if [ -z "$4" ] || [ "$4" = "null" ]; then red "  miss #$1 has no '$2' label" >&2; return 1; fi
  if [ -n "$OWNER" ] && [ "$4" != "$OWNER" ]; then red "  miss '$2' on #$1 was added by $4, not $OWNER" >&2; return 1; fi
  info "ok   '$2' on #$1 by $4 at $5" >&2
  printf '%s\n' "$5"
}
