#!/usr/bin/env bash
# ship-checks.sh: bin/ship's slow checks, e2e and perf. Sourced by bin/ship after common.sh and
# parallel.sh. Bash 3.2.
#
# ship_checks: exit 0 when e2e and perf pass. How they run:
#   1. at the same time (parallel.sh): E2E_CMD then SITE_E2E_CMD in one lane (two browser suites
#      may share a port), and PERF_PREP_CMD, perf's untimed half (builds, fixtures, accuracy) when
#      set. None of them measures time, so sharing the machine cannot change their verdict.
#   2. then alone: PERF_CMD, the timed half (or the whole perf run when PERF_PREP_CMD is empty),
#      only when the prep half passed: perf stops at its first failure. It holds the machine-wide
#      `timed` lock and first waits until no other gate is running checks (ship_alone), so its
#      numbers mean what the budgets mean.
#   E2E_EXCLUSIVE=1: e2e holds this repo's e2e lock, so two worktrees' e2e never run at once (a
#   fixed port, one simulator).
# Change classes apply as before: run_part skips what the branch's class does not need.
#
# Verdict reuse (VERDICT_REUSE=1, off by default): a run where all of it passed is recorded; a
# later bin/ship on the same input (ship_verdict_key) reuses it instead of running it again, for
# up to SHIP_VERDICT_MAX_AGE. Any failure on that input voids the record. STANDARDS_RERUN=1
# ignores a record and runs everything.
#
# bin/ship --checks-only (SHIP_CHECKS_ONLY=1): the same run, started by the agent in the
# background while the pre-merge reviewers read, so e2e and perf are done by the time bin/ship
# runs. Only with VERDICT_REUSE=1: reuse is the owner's setting, and without it a recorded pass
# would never be used (bin/ship --checks-only refuses). While it runs, its record says "running"
# with its pid: a bin/ship on the same input waits for it (at most LOCK_WAIT_MAX) instead of
# running e2e and perf a second time.
SHIP_VERDICT_MAX_AGE=86400 # seconds: a day. Tools, browsers and certificates drift in place
SHIP_REUSED=""             # the reuse line, when ship_checks reused a verdict

# ship_verdict_key: prints the inputs e2e and perf depend on, one per line; fails when any cannot
# be read (then nothing is reused or recorded):
#   tree       every tracked file of HEAD (git's blob hashes), except the issue's own
#              decisions.md: e2e and perf never read it (bin/ship's decision-log and approval
#              checks do, and they run every time), and it is where an approval miss gets fixed.
#              Kept when it matches SHARED_GLOBS (a file some test reads).
#   untracked  every untracked, unignored file (a test runner may pick one up)
#   modified   any uncommitted edit (bin/ship refuses them; counted anyway, so the key holds alone)
#   base       the base commit: it sets the change class and what the branch is tested against
#   commands   the e2e and perf commands and E2E_EXCLUSIVE, as bin/ship read them
#   os         uname
#   tools      what VERDICT_KEY_CMD prints (the tool versions e2e and perf depend on); it must
#              exit 0
#   ignored    every gitignored file matching VERDICT_IGNORED_GLOBS (default ".env*": local
#              settings a test may read), path and content
#   env        the values of the environment variables named in VERDICT_ENV (set or unset)
#   deps       the installed dependencies: each lockfile present (content) and each install
#              marker present (VERDICT_DEPS_MARKERS: content and mtime, so a reinstall counts),
#              plus what VERDICT_DEPS_CMD prints (it must exit 0)
# Not covered, so never reused across them: anything else outside git — other gitignored files
# and build output, environment variables not named, services, databases, the network, the
# clock. That is why reuse is off by default and a day at most.
ship_verdict_key() {
  local dec base tree untracked modified tools ignored env deps
  base="$(base_commit)" && [ -n "$base" ] || return 1
  # Empty when the branch names no issue, or two folders: then the whole tree counts.
  dec="$(decisions_file)"
  if [ -n "$dec" ] && ! matches_any "$dec" "$SHARED_GLOBS"; then
    tree="$(set -o pipefail; git ls-tree -r --full-tree HEAD | awk -F'\t' -v p="$dec" '$2 != p' | git hash-object --stdin)" || return 1
    dec="$dec left out"
  else
    tree="$(set -o pipefail; git ls-tree -r --full-tree HEAD | git hash-object --stdin)" || return 1
    dec="${dec:-none} kept"
  fi
  untracked="$(set -o pipefail; git ls-files -z --others --exclude-standard | tr '\0' '\n' \
    | while IFS= read -r f; do printf '%s %s\n' "$(git hash-object -- "$f")" "$f"; done | git hash-object --stdin)" || return 1
  modified="$(set -o pipefail; git diff --binary HEAD | git hash-object --stdin)" || return 1
  if [ -n "${VERDICT_KEY_CMD:-}" ]; then
    tools="$(set -o pipefail; eval "$VERDICT_KEY_CMD" 2>&1 | git hash-object --stdin)" || return 1
  else
    tools="none (VERDICT_KEY_CMD empty)"
  fi
  ignored="$(_ship_key_ignored)" || return 1
  env="$(_ship_key_env)" || return 1
  deps="$(_ship_key_deps)" || return 1
  # One line per input; each "# bite:" line is dropped from a copy by tests/run.sh, which must notice.
  printf 'tree %s (decisions: %s)\n' "$tree" "$dec"  # bite: tree
  printf 'untracked %s\n' "$untracked"  # bite: untracked
  printf 'modified %s\n' "$modified"  # bite: modified
  printf 'base %s\n' "$base"  # bite: base
  printf 'commands %s\n' "$(printf '%s\n' "$E2E_CMD" "${SITE_E2E_CMD:-}" "${PERF_PREP_CMD:-}" "$PERF_CMD" "${E2E_EXCLUSIVE:-}" | git hash-object --stdin)"  # bite: commands
  printf 'os %s\n' "$(uname -srm)"  # bite: os
  printf 'tools %s\n' "$tools"  # bite: tools
  printf 'ignored %s\n' "$ignored"  # bite: ignored
  printf 'env %s\n' "$env"  # bite: env
  printf 'deps %s\n' "$deps"  # bite: deps
}

# _ship_key_ignored: hash of every gitignored file matching VERDICT_IGNORED_GLOBS ("path hash" per
# line). A glob without "/" matches the name at any depth. git lists only what the pathspecs name,
# so a large ignored tree (node_modules) is not hashed whole.
_ship_key_ignored() {
  local g specs=()
  set -f
  for g in ${VERDICT_IGNORED_GLOBS-.env*}; do
    case "$g" in */*) specs+=(":(glob)$g") ;; *) specs+=(":(glob)**/$g") ;; esac
  done
  set +f
  [ ${#specs[@]} -gt 0 ] || { echo "none (VERDICT_IGNORED_GLOBS empty)"; return 0; }
  (set -o pipefail; git ls-files -z --others --ignored --exclude-standard -- "${specs[@]}" | tr '\0' '\n' | sort \
    | while IFS= read -r f; do printf '%s %s\n' "$(git hash-object -- "$f")" "$f"; done | git hash-object --stdin)
}

# _ship_key_env: hash of "NAME=value" (or "NAME unset") for each name in VERDICT_ENV.
_ship_key_env() {
  local n
  [ -n "${VERDICT_ENV:-}" ] || { echo "none (VERDICT_ENV empty)"; return 0; }
  for n in $VERDICT_ENV; do
    printf '%s\n' "$n" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$' || { red "  VERDICT_ENV: '$n' is not a variable name" >&2; return 1; }
    if [ -n "${!n+x}" ]; then printf '%s=%s\n' "$n" "${!n}"; else printf '%s unset\n' "$n"; fi
  done | git hash-object --stdin
}

# _ship_key_deps: hash of the dependency state: lockfiles by content, install markers (written by
# the package manager on every install) by content and mtime, VERDICT_DEPS_CMD's output.
VERDICT_LOCKFILES="pnpm-lock.yaml package-lock.json yarn.lock bun.lockb bun.lock Cargo.lock poetry.lock uv.lock Pipfile.lock Gemfile.lock go.sum composer.lock Package.resolved"
_ship_key_deps() {
  (
    set -o pipefail
    {
      for f in $VERDICT_LOCKFILES; do [ ! -f "$f" ] || printf 'lock %s %s\n' "$f" "$(git hash-object -- "$f")"; done
      for f in ${VERDICT_DEPS_MARKERS-node_modules/.modules.yaml node_modules/.package-lock.json node_modules/.yarn-state.yml node_modules/.yarn-integrity}; do
        [ ! -f "$f" ] || printf 'marker %s %s %s\n' "$f" "$(git hash-object -- "$f")" "$(stat -f %m "$f" 2> /dev/null || stat -c %Y "$f")"
      done
      if [ -n "${VERDICT_DEPS_CMD:-}" ]; then
        out="$(eval "$VERDICT_DEPS_CMD" 2>&1)" || exit 1
        printf 'cmd %s\n' "$(printf '%s\n' "$out" | git hash-object --stdin)"
      fi
    } | git hash-object --stdin
  )
}

# ship_verdict_file <key>: where a verdict for that key is kept: the clone's shared git dir, so
# every worktree sees it and nothing lands in the tree. One small file per input.
ship_verdict_file() {
  local dir
  dir="$(git rev-parse --git-common-dir)" || return 1
  printf '%s/standards-verdicts/ship-%s\n' "$dir" "$(printf '%s\n' "$1" | git hash-object --stdin)"
}

# ship_verdict_fresh <key>: a recorded pass for exactly this key, under SHIP_VERDICT_MAX_AGE old,
# whose run log (<record>.log, the whole output of the run that passed) is still there with the
# hash the record names. Prints "<minutes ago> <commit> <by> <epoch> <log hash> <log path>".
# A record is a file anyone with this clone can write: it cannot be made unforgeable here (a
# speed bump for honest agents, like every local gate). The log hash makes a reuse traceable to
# the run behind it, and a record without one — hand-written, or from an older version — is
# refused, with a line saying so.
ship_verdict_fresh() {
  local f w at head by lh now
  f="$(ship_verdict_file "$1")" && [ -f "$f" ] || return 1
  # The file holds the key itself, then "passed <epoch> <commit> <by> <log hash>"; anything else is no verdict.
  [ "$(sed '$d' "$f")" = "$1" ] || return 1
  read -r w at head by lh <<< "$(tail -1 "$f")"
  [ "$w" = passed ] && printf '%s' "$at" | grep -qE '^[0-9]+$' || return 1
  now=$(date +%s)
  [ $((now - at)) -ge 0 ] && [ $((now - at)) -le "$SHIP_VERDICT_MAX_AGE" ] || return 1
  local logok=1
  printf '%s' "$lh" | grep -qE '^[0-9a-f]{40,64}$' && [ -f "$f.log" ] && [ "$(git hash-object -- "$f.log")" = "$lh" ] || logok=""  # bite: loghash
  if [ -z "$logok" ]; then
    info "refused a recorded pass for this input: no run log matching its hash (${lh:-none}) at $f.log — e2e and perf run" >&2
    return 1
  fi
  printf '%s %s %s %s %s %s\n' "$(((now - at) / 60))" "$head" "${by:-ship}" "$at" "$lh" "$f.log"
}

# ship_verdict_save <key> <by> <log>: records a pass, by bin/ship or checks-only, with the hash of
# its run log, which is kept beside the record.
ship_verdict_save() {
  local f lh
  f="$(ship_verdict_file "$1")" || return 1
  mkdir -p "$(dirname "$f")" || return 1
  if [ "$3" != "$f.log" ]; then cp "$3" "$f.log" || return 1; fi
  lh="$(git hash-object -- "$f.log")" || return 1
  printf '%s\npassed %s %s %s %s\n' "$1" "$(date +%s)" "$(git rev-parse HEAD)" "${2:-ship}" "$lh" > "$f"
}

# _ship_utc <epoch>: ISO time in UTC (BSD date, then GNU).
_ship_utc() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }

# ship_verdict_running <key>: --checks-only is running on this input: "running <epoch> <pid>
# <start time>", so a bin/ship on the same input waits for it. Not a pass: a run that dies
# leaves a record whose process is gone, which is no verdict.
ship_verdict_running() {
  local f
  f="$(ship_verdict_file "$1")" || return 1
  mkdir -p "$(dirname "$f")" && printf '%s\nrunning %s %s %s\n' "$1" "$(date +%s)" "$$" "$(_ship_start "$$")" > "$f"
}
# _ship_start <pid>: that process's start time, spaces trimmed (it is read back with `read`).
_ship_start() { _gate_start "$1" | sed 's/^ *//; s/ *$//'; }

# ship_verdict_wait <key>: while another process (bin/ship --checks-only) is running e2e and perf
# on exactly this input, wait for it, printing progress every 30 s. Returns at once when nothing
# runs, and treats the run as unfinished (this gate then runs its own) when its process is gone,
# its pid now names another process, it is stopped (state T: a background job that read the
# terminal), its record is older than LOCK_WAIT_MAX, or this wait passes LOCK_WAIT_MAX.
ship_verdict_wait() {
  local f w at pid start s n max="${LOCK_WAIT_MAX:-1800}" said=""
  f="$(ship_verdict_file "$1")" || return 0
  s=$(date +%s)
  while [ -f "$f" ] && [ "$(sed '$d' "$f")" = "$1" ]; do
    read -r w at pid start <<< "$(tail -1 "$f")"
    [ "$w" = running ] && [ "$pid" != "$$" ] && kill -0 "$pid" 2> /dev/null \
      && [ "$(_ship_start "$pid")" = "$start" ] || return 0
    if ps -o stat= -p "$pid" 2> /dev/null | grep -q '^ *T'; then  # bite: wait-stopped
      info "bin/ship --checks-only (pid $pid) is stopped: treated as unfinished; e2e and perf run here"; return 0
    fi
    if ! printf '%s' "$at" | grep -qE '^[0-9]+$' || [ $(($(date +%s) - at)) -gt "$max" ]; then  # bite: wait-stale
      info "bin/ship --checks-only (pid $pid) started over ${max}s ago (LOCK_WAIT_MAX): treated as unfinished; e2e and perf run here"; return 0
    fi
    n=$(($(date +%s) - s))
    if [ "$n" -ge "$max" ]; then  # bite: wait-max
      info "waited ${n}s (LOCK_WAIT_MAX) for bin/ship --checks-only (pid $pid): e2e and perf run here"; return 0
    fi
    if [ -z "$said" ] || [ $((n - said)) -ge 30 ]; then
      info "wait bin/ship --checks-only (pid $pid) is running e2e and perf on this input — using its verdict (${n}s so far)"
      said=$n
    fi
    sleep 1
  done
  [ -z "$said" ] || info "bin/ship --checks-only finished after $(($(date +%s) - s))s waiting"
}

# ship_verdict_unfinished <key>: a --checks-only run that ends without a verdict (the input changed
# under it) replaces its "running" record, so nothing waits on it.
ship_verdict_unfinished() {
  local f
  f="$(ship_verdict_file "$1")" || return 1
  [ ! -e "$f" ] || printf 'unfinished %s %s\n' "$(date +%s)" "$(git rev-parse HEAD)" > "$f"
}

# ship_verdict_void <key>: a failure on this input overwrites any pass recorded for it. Overwritten,
# not deleted: the record lives in .git/, where safe_rm (rightly) deletes nothing, and a file whose
# last line is not "passed …" is no verdict to ship_verdict_fresh.
ship_verdict_void() {
  local f
  f="$(ship_verdict_file "$1")" || return 1
  [ ! -e "$f" ] || printf 'failed %s %s\n' "$(date +%s)" "$(git rev-parse HEAD)" > "$f"
}

# ship_alone <command...>: runs the timed checks alone on the machine: holds the `timed` lock and
# first waits until no other gate (another worktree's pre-push or bin/ship) is running checks;
# gates that start meanwhile wait for it (parallel.sh, gate locks).
ship_alone() {
  local rc
  gate_lock timed || { red "FAIL cannot take the timed lock in $(_gate_dir)"; return 1; }
  gate_wait_idle || { gate_unlock timed; red "FAIL cannot clear stale busy marks in $(_gate_dir)"; return 1; }  # bite: idle
  # The load before and after, so a reader can see the run had the machine to itself (work outside
  # the gates, such as a build by hand, is not locked out: the rulebook asks for none).
  info "alone now, so no other gate skews the timings ($(uptime | sed 's/.*load/load/'))"
  # A gate the timed checks start is nested in this one: it must not wait on this gate's lock.
  (_gate_nested || export STANDARDS_GATE_BUSY=$$; "$@")
  rc=$?
  info "timed checks done ($(uptime | sed 's/.*load/load/'))"
  gate_unlock timed
  return $rc
}

# _ship_e2e: E2E_CMD by change class, under this repo's e2e lock when E2E_EXCLUSIVE=1.
_ship_e2e() {
  local rc lock
  if [ "${E2E_EXCLUSIVE:-}" != 1 ] || [ -z "$E2E_CMD" ] || ! checks_for app; then
    run_part e2e app "$E2E_CMD"
    return
  fi
  lock="e2e-$(_gate_repo_id)" || return 1
  gate_lock "$lock" || { red "FAIL e2e: cannot take the $lock lock in $(_gate_dir)"; return 1; }
  run_cmd e2e "$E2E_CMD"
  rc=$?
  gate_unlock "$lock"
  return $rc
}

# _ship_run: e2e beside perf prep, then perf; exit 0 when all passed.
_ship_run() {
  local ok=1
  par_reset
  par_job e2e e2e _ship_e2e
  par_job e2e site-e2e 'run_part site-e2e site-change "$SITE_E2E_CMD"'
  [ -z "${PERF_PREP_CMD:-}" ] || par_job perf perf-prep 'run_part perf-prep app "$PERF_PREP_CMD"'
  par_run ship || ok=0
  if [ -n "${PERF_PREP_CMD:-}" ] && [ "$(par_rc perf-prep)" != 0 ]; then
    red "FAIL perf not run: perf-prep failed (perf stops at its first failure)"
    ok=0
  elif [ -n "$PERF_CMD" ] && checks_for app; then
    ship_alone run_cmd perf "$PERF_CMD" || ok=0
  else
    run_part perf app "$PERF_CMD" || ok=0
  fi
  [ $ok -eq 1 ]
}

ship_checks() {
  local key="" seen ok=1 mins commit by at lh lp rec="" vf
  SHIP_REUSED=""; SHIP_REUSED_KEY=""
  # rec: verdicts are reused and recorded only with VERDICT_REUSE=1; off, nothing is read or written.
  [ "${VERDICT_REUSE:-}" = 1 ] && rec=1
  if [ -z "$rec" ]; then
    key=""
  elif ! key="$(ship_verdict_key)"; then
    key=""
    info "verdict key could not be read (VERDICT_KEY_CMD or VERDICT_DEPS_CMD failed?): e2e and perf run, nothing is reused or recorded"
  elif [ -z "${STANDARDS_RERUN:-}" ]; then
    ship_verdict_wait "$key"
    if seen="$(ship_verdict_fresh "$key")"; then
      read -r mins commit by at lh lp <<< "$seen"
      [ "$by" = checks-only ] && by=" by bin/ship --checks-only" || by=""
      # Every reuse says what it stands on: when the run was, its commit, its log and the key.
      SHIP_REUSED="e2e and perf passed $mins min ago ($(_ship_utc "$at")) on commit $commit$by with the same input (files but decisions.md, ignored files in VERDICT_IGNORED_GLOBS, VERDICT_ENV, deps, base, commands, OS, tools) — reused, not re-run (STANDARDS_RERUN=1 re-runs them); run log $lp, git hash $lh"
      SHIP_REUSED_KEY="$key"
      green "PASS e2e + perf: $SHIP_REUSED"
      printf '%s\n' "$key" | sed 's/^/  key  /'
      return 0
    fi
  fi
  [ -z "$key" ] || [ -z "${SHIP_CHECKS_ONLY:-}" ] || ship_verdict_running "$key" \
    || info "warn could not mark this --checks-only run in the verdict store; a bin/ship meanwhile runs its own"

  # A run that may be recorded keeps its whole output as the record's log (tee); others stream.
  if [ -n "$key" ] && [ -n "$rec" ] && vf="$(ship_verdict_file "$key")" && mkdir -p "$(dirname "$vf")"; then
    (set -o pipefail; _ship_run 2>&1 | tee "$vf.run.$$") || ok=0
  else
    vf=""; _ship_run || ok=0
  fi
  # A failure on this input voids any pass recorded for it earlier (a forced re-run that failed):
  # an old pass must never stand in for a run that has since failed.
  if [ $ok -eq 0 ]; then
    [ -z "$key" ] || ship_verdict_void "$key"
    [ -z "$vf" ] || mv -f "$vf.run.$$" "$vf.failed.log" 2> /dev/null
    return 1
  fi
  [ -n "$key" ] && [ -n "$rec" ] && [ -n "$vf" ] || return 0
  # Recorded only when the input is still the one the run started on (nothing edited meanwhile).
  # The run log moves into place under the record's name (a rename, never a delete in .git/).
  if [ "$(ship_verdict_key)" = "$key" ] && mv -f "$vf.run.$$" "$vf.log" \
     && ship_verdict_save "$key" "${SHIP_CHECKS_ONLY:+checks-only}" "$vf.log"; then
    info "recorded: e2e and perf passed on this input (a re-run on the same input reuses it); run log $vf.log"
  else
    mv -f "$vf.run.$$" "$vf.unrecorded.log" 2> /dev/null
    [ -z "${SHIP_CHECKS_ONLY:-}" ] || ship_verdict_unfinished "$key"
    info "warn verdict not recorded (the input changed during the run, or it could not be written); a re-run runs e2e and perf again"
  fi
  return 0
}
