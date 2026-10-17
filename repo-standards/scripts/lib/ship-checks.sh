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
ship_verdict_key() {
  local dec base tree untracked modified tools
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
  # One line per input; each "# bite:" line is dropped from a copy by tests/run.sh, which must notice.
  printf 'tree %s (decisions: %s)\n' "$tree" "$dec"  # bite: tree
  printf 'untracked %s\n' "$untracked"  # bite: untracked
  printf 'modified %s\n' "$modified"
  printf 'base %s\n' "$base"  # bite: base
  printf 'commands %s\n' "$(printf '%s\n' "$E2E_CMD" "${SITE_E2E_CMD:-}" "${PERF_PREP_CMD:-}" "$PERF_CMD" "${E2E_EXCLUSIVE:-}" | git hash-object --stdin)"
  printf 'os %s\n' "$(uname -srm)"
  printf 'tools %s\n' "$tools"  # bite: tools
}

# ship_verdict_file <key>: where a verdict for that key is kept: the clone's shared git dir, so
# every worktree sees it and nothing lands in the tree. One small file per input.
ship_verdict_file() {
  local dir
  dir="$(git rev-parse --git-common-dir)" || return 1
  printf '%s/standards-verdicts/ship-%s\n' "$dir" "$(printf '%s\n' "$1" | git hash-object --stdin)"
}

# ship_verdict_fresh <key>: a recorded pass for exactly this key, under SHIP_VERDICT_MAX_AGE old.
# Prints "<minutes ago> <commit>".
ship_verdict_fresh() {
  local f w at head now
  f="$(ship_verdict_file "$1")" && [ -f "$f" ] || return 1
  # The file holds the key itself, then "passed <epoch> <commit>"; anything else is no verdict.
  [ "$(sed '$d' "$f")" = "$1" ] || return 1
  read -r w at head <<< "$(tail -1 "$f")"
  [ "$w" = passed ] && printf '%s' "$at" | grep -qE '^[0-9]+$' || return 1
  now=$(date +%s)
  [ $((now - at)) -ge 0 ] && [ $((now - at)) -le "$SHIP_VERDICT_MAX_AGE" ] || return 1
  printf '%s %s\n' "$(((now - at) / 60))" "$head"
}

ship_verdict_save() {
  local f
  f="$(ship_verdict_file "$1")" || return 1
  mkdir -p "$(dirname "$f")" && printf '%s\npassed %s %s\n' "$1" "$(date +%s)" "$(git rev-parse HEAD)" > "$f"
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
  "$@"
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

ship_checks() {
  local key="" seen ok=1
  SHIP_REUSED=""
  if [ "${VERDICT_REUSE:-}" = 1 ]; then
    if ! key="$(ship_verdict_key)"; then
      key=""
      info "verdict key could not be read (VERDICT_KEY_CMD failed?): e2e and perf run, nothing is reused or recorded"
    elif [ -z "${STANDARDS_RERUN:-}" ] && seen="$(ship_verdict_fresh "$key")"; then
      SHIP_REUSED="e2e and perf passed ${seen%% *} min ago on commit ${seen##* } with the same input (files but decisions.md, base, commands, OS, tools) — reused, not re-run (STANDARDS_RERUN=1 re-runs them)"
      green "PASS e2e + perf: $SHIP_REUSED"
      printf '%s\n' "$key" | sed 's/^/  key  /'
      return 0
    fi
  fi

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
  # A failure on this input voids any pass recorded for it earlier (a forced re-run that failed):
  # an old pass must never stand in for a run that has since failed.
  if [ $ok -eq 0 ]; then
    [ -z "$key" ] || ship_verdict_void "$key"
    return 1
  fi
  [ -n "$key" ] || return 0
  # Recorded only when the input is still the one the run started on (nothing edited meanwhile).
  if [ "$(ship_verdict_key)" = "$key" ] && ship_verdict_save "$key"; then
    info "recorded: e2e and perf passed on this input (a re-run on the same input reuses it)"
  else
    info "warn verdict not recorded (the input changed during the run, or it could not be written); a re-run runs e2e and perf again"
  fi
  return 0
}
