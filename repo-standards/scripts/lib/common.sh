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
  local secs="$1" pid watcher rc flag
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
  # Ctrl-C reaches only the terminal's foreground group, which the job is not in: pass it on.
  trap 'kill -TERM -- "-$pid" 2>/dev/null; kill "$watcher" 2>/dev/null; exit 130' INT TERM
  wait "$pid"; rc=$?
  trap - INT TERM
  # On a timeout let the watcher finish, so its KILL reaches anything that ignored TERM.
  if [ -e "$flag" ]; then wait "$watcher"; rm -f "$flag"; timed_out=1; return 124; fi
  # Reaped here, quietly: otherwise bash reports the killed watcher ("Terminated") later.
  kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null
  return $rc
}

# run_cmd <label> <command string> [timeout seconds, default CMD_TIMEOUT]. Empty command =
# N/A in config, reported as SKIP. A command still running at the timeout is stopped, with
# everything it started, and fails the gate.
run_cmd() {
  local label="$1" cmd="$2" secs="${3:-${CMD_TIMEOUT:-1800}}" start rc
  if [ -z "$cmd" ]; then info "SKIP $label (N/A in config)"; return 0; fi
  start=$(date +%s)
  info "RUN  $label: $cmd"
  run_timed "$secs" eval "$cmd"
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

# run_classes <stage>: each class in TEST_CLASSES with a CLASS_<name>_<STAGE>_CMD runs only
# when the branch touches one of its paths (minus IGNORE_PATHS), and not again for content
# that already passed here (.standards/state/results, keyed by class_key, PASS only). The
# full runs on the base branch nightly and before each release are what make skipping safe.
run_classes() {
  local stage="$1" up c cmd paths f hit key prev rc=0 results="$ROOT/.standards/state/results"
  up="$(printf '%s' "$stage" | tr '[:lower:]' '[:upper:]')"
  for c in $TEST_CLASSES; do
    case "$c" in *[!A-Za-z0-9_]*) red "FAIL class '$c': a name is letters, digits and _ only"; rc=1; continue ;; esac
    cmd="$(class_get "$c" "${up}_CMD")"
    [ -n "$cmd" ] || continue
    paths="$(class_get "$c" PATHS)"
    hit=""
    while IFS= read -r f; do
      [ -n "$f" ] && matches_any "$f" "$paths" && ! matches_any "$f" "$IGNORE_PATHS" && { hit="$f"; break; }
    done < <(branch_files)
    if [ -z "$hit" ]; then info "SKIP $c $stage (branch changes none of: $paths)"; continue; fi
    key="$(class_key "$c" "$stage" "$cmd")"
    prev="$(sed -n "s/^$key //p" "$results" 2>/dev/null | head -1)"
    if [ -n "$prev" ]; then info "ok   $c $stage: cached — same content passed at $prev"; continue; fi
    if run_cmd "$c $stage" "$cmd" "$(class_get "$c" TIMEOUT)"; then
      mkdir -p "${results%/*}" && printf '%s %s\n' "$key" "$(git rev-parse --short HEAD)" >> "$results"
    else rc=1
    fi
  done
  return $rc
}

# nonstandard_files: the files the branch touches that are not standards paths — the base's
# GATE_FILES (from its agent-approval.sh, so a branch cannot widen the list) or docs/*. Empty
# = a standards-only branch, the only kind maintenance mode skips tests for. Fails closed:
# with no base or no GATE_FILES on it, it prints a reason, so nothing counts as standards-only.
nonstandard_files() {
  local base gates f
  base="$(base_commit)"; [ -n "$base" ] || { echo "(no base commit)"; return; }
  gates="$(git show "$base:.standards/checks/agent-approval.sh" 2>/dev/null | sed -n 's/^GATE_FILES="\(.*\)"$/\1/p')"
  [ -n "$gates" ] || { echo "(no GATE_FILES on the base)"; return; }
  branch_files | while IFS= read -r f; do
    [ -n "$f" ] && ! matches_any "$f" "$gates docs/*" && printf '%s\n' "$f"
  done
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
