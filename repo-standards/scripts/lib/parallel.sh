#!/usr/bin/env bash
# parallel.sh: runs independent checks at the same time, each with its own log, and gives one
# combined verdict. Sourced by the pre-push hook and bin/ship, after common.sh (it deletes only
# through safe_rm). Bash 3.2 (macOS default): indexed arrays only, no `wait -n`.
#
#   par_reset                          forget the queued checks
#   par_job <lane> <label> <command>   queue a check. Checks in one lane run in turn, in queue
#                                      order (for checks that write the same files); the lanes
#                                      run at the same time.
#   par_run <title>                    run every queued check. Prints what it runs before it
#                                      starts, then each check's log in queue order, then one
#                                      PASS/FAIL line per check and a final line. Exit 0 only
#                                      when every check exited 0.
#   par_rc <label>                     that check's exit code in the last par_run (1 when it left
#                                      none, or no such check ran)
#   par_failed                         the labels that failed in the last par_run
#
# Same rules as running them one after another: every queued check runs whatever the others do,
# and any failure fails the set. Fails closed: a check passes only when it wrote exit code 0
# itself; one whose lane died first (a signal, a crash) fails. Each check runs in its own
# subshell with stdin from /dev/null, so an `exit` ends only that check and none can read input
# meant for the gate (pre-push's ref list). Logs go under PAR_LOG_DIR (default: a new temp dir,
# removed when every check passed, kept and named when one failed).

PAR_LANES=()
PAR_LABELS=()
PAR_CMDS=()
PAR_RCS=() # each check's exit code from the last par_run, empty when it left none
PAR_DIR=""
PAR_PIDS=""
PAR_FAILED=""

par_reset() {
  PAR_LANES=()
  PAR_LABELS=()
  PAR_CMDS=()
  PAR_RCS=()
  PAR_FAILED=""
}

par_job() {
  local n=${#PAR_LABELS[@]}
  PAR_LANES[$n]="$1"
  PAR_LABELS[$n]="$2"
  PAR_CMDS[$n]="$3"
}

# _par_file <index>: the log / exit-code file stem for a check; the label, made safe for a name.
_par_file() {
  printf '%s/%02d-%s' "$PAR_DIR" "$1" "$(printf '%s' "${PAR_LABELS[$1]}" | tr -c 'A-Za-z0-9._-' '_')"
}

# _par_lane <lane>: runs that lane's checks in queue order; records "<exit> <seconds>" for each.
_par_lane() {
  local i s rc f
  for ((i = 0; i < ${#PAR_LABELS[@]}; i++)); do
    [ "${PAR_LANES[$i]}" = "$1" ] || continue
    f="$(_par_file "$i")"
    s=$(date +%s)
    (eval "${PAR_CMDS[$i]}") < /dev/null > "$f.log" 2>&1
    rc=$?
    printf '%s %s\n' "$rc" "$(($(date +%s) - s))" > "$f.rc"
    printf '  done %s: exit %s (%ss)\n' "${PAR_LABELS[$i]}" "$rc" "$(($(date +%s) - s))"
  done
}

# _par_tree <pid>: that process and everything under it, parents first.
_par_tree() {
  local c
  echo "$1"
  for c in $(pgrep -P "$1" 2> /dev/null); do _par_tree "$c"; done
}

# Ctrl-C or TERM during a run: background lanes ignore SIGINT in a non-interactive shell, so stop
# them here instead of leaving them running. TERM first, to every process the lanes started (so a
# check's own EXIT trap runs and can stop what it started), then KILL what is left after 10 s.
_par_stop() {
  local p c all="" alive
  for p in $PAR_PIDS; do all="$all $(_par_tree "$p")"; done
  # shellcheck disable=SC2086
  kill -TERM $all 2> /dev/null
  for _ in $(seq 1 100); do
    alive=""
    for c in $all; do kill -0 "$c" 2> /dev/null && alive=1; done
    [ -n "$alive" ] || break
    sleep 0.1
  done
  for c in $all; do kill -KILL "$c" 2> /dev/null; done
  [ "$GATE_BUSY_DEPTH" -eq 0 ] || GATE_BUSY_DEPTH=1
  _gate_busy_off
  echo "parallel: stopped"
  exit 130
}

# --- Machine-wide gate locks. Gates in other worktrees (and other repos) share this machine's CPU:
#   - a gate about to run checks (pre-push, bin/ship's parallel set) marks itself busy, but first
#     waits while another gate holds the `timed` lock (running its timed checks, or waiting to);
#   - bin/ship's timed checks (PERF_CMD) take the `timed` lock (gate_lock), then wait until no
#     other gate is busy (gate_wait_idle). A gate drops its busy mark before it asks for `timed`,
#     so two gates that both want it never wait on each other; new gates wait behind a held
#     `timed` lock, so a waiting timed half is not starved by them.
# A lock or busy mark records its process's pid and start time; one whose process is gone (or
# whose pid now names a later process) is removed. Fails closed: a gate that cannot make its busy
# mark or the lock fails, since a timed check elsewhere would otherwise run under its load.
# A gate started by a check of another gate (a test suite that runs the hooks) is exempt from
# both: its outer gate already counts. STANDARDS_GATE_BUSY holds the outer gate's pid, honoured
# only when that process is alive and an ancestor of this one.
#   STANDARDS_LOCK_DIR  default /tmp/repo-standards-locks-<uid>. /tmp, not $TMPDIR: a sandbox or
#                       session may set its own TMPDIR, which would split the lock silently. It
#                       must be a dir safe_rm may delete in (a temp dir or inside the repo).
GATE_WAITED=0 # seconds the last _gate_busy_on waited for another gate's timed checks
_gate_dir() { printf '%s\n' "${STANDARDS_LOCK_DIR:-/tmp/repo-standards-locks-$(id -u)}"; }
_gate_start() { ps -o lstart= -p "$1" 2> /dev/null; }
_gate_mtime() { stat -f %m "$1" 2> /dev/null || stat -c %Y "$1" 2> /dev/null || echo 0; }
# _gate_repo_id: one id for every worktree of this clone (its shared git dir), for per-repo locks.
_gate_repo_id() {
  (cd "$(git rev-parse --git-common-dir)" && pwd -P) | git hash-object --stdin | cut -c1-12
}
# _gate_alive <pid> [start]: that process runs, and (when given) started at that time.
_gate_alive() {
  [ -n "$1" ] && kill -0 "$1" 2> /dev/null || return 1
  [ -z "${2:-}" ] || [ "$(_gate_start "$1")" = "$2" ]
}
# _gate_nested: this gate runs inside another registered gate (see above).
_gate_nested() {
  local want="${STANDARDS_GATE_BUSY:-}"
  [ -n "$want" ] && _gate_alive "$want" && _gate_ancestor "$want"
}
# _gate_ancestor <pid>: that process is this one or one of its ancestors.
_gate_ancestor() {
  local p=$$
  [ -n "$1" ] || return 1
  for _ in $(seq 1 40); do
    [ "$p" = "$1" ] && return 0
    p="$(ps -o ppid= -p "$p" 2> /dev/null | tr -d ' ')"
    [ -n "$p" ] && [ "$p" -gt 1 ] || return 1
  done
  return 1
}
# _gate_held <lock dir>: held by a live process other than this gate. A lock with no pid yet,
# under 10 s old, counts as held: its maker is writing the pid.
_gate_held() {
  local h
  [ -d "$1" ] || return 1
  h="$(cat "$1/pid" 2> /dev/null)"
  if [ -z "$h" ]; then
    [ $(($(date +%s) - $(_gate_mtime "$1"))) -lt 10 ]
    return
  fi
  [ "$h" != "$$" ] && _gate_alive "$h" "$(cat "$1/start" 2> /dev/null)"
}
# _gate_dir_ok: the lock dir exists (made if needed) and safe_rm may clear stale entries in it;
# otherwise a stale lock could never be removed and every gate would wait on it forever.
_gate_dir_ok() {
  local d
  d="$(_gate_dir)"
  mkdir -p "$d/busy" 2> /dev/null && safe_rm --check "$d/busy/probe" 2> /dev/null
}

# gate_lock <name>: wait until this gate holds <name>, one holder on the machine.
gate_lock() {
  local d l said=""
  d="$(_gate_dir)"
  _gate_dir_ok || return 1
  l="$d/$1.lock"
  until mkdir "$l" 2> /dev/null; do
    # Gone between the two looks (its holder just let go): try again; fail only when the dir
    # cannot be written, so this never loops on a lock it can never make.
    if [ ! -d "$l" ]; then
      [ -w "$d" ] || return 1
      continue
    fi
    if ! _gate_held "$l"; then
      [ "$(cat "$l/pid" 2> /dev/null)" = "$$" ] && return 0
      safe_rm "$l" || return 1
      continue
    fi
    # Held by the gate this one runs inside: waiting would never end.
    if _gate_ancestor "$(cat "$l/pid" 2> /dev/null)"; then
      echo "FAIL the $1 lock is held by this gate's own outer gate (pid $(cat "$l/pid" 2> /dev/null)); a nested gate needs its own STANDARDS_LOCK_DIR"
      return 1
    fi
    [ -n "$said" ] || echo "  wait the $1 lock is held by pid $(cat "$l/pid" 2> /dev/null) ($(cat "$l/what" 2> /dev/null))"
    said=1
    sleep 1
  done
  printf '%s\n' "$PWD" > "$l/what" && _gate_start $$ > "$l/start" && printf '%s\n' "$$" > "$l/pid"
}
gate_unlock() {
  local l
  l="$(_gate_dir)/$1.lock"
  [ "$(cat "$l/pid" 2> /dev/null)" = "$$" ] && safe_rm "$l"
  return 0
}

# gate_wait_idle: wait until no other gate is running checks (the timed lock holder calls it).
gate_wait_idle() {
  local d f p busy said=""
  d="$(_gate_dir)/busy"
  while :; do
    busy=""
    for f in "$d"/*; do
      [ -e "$f" ] || continue
      p="$(basename "$f")"
      [ "$p" != "$$" ] && [ "$p" != "${STANDARDS_GATE_BUSY:-}" ] || continue
      if _gate_alive "$p" "$(cat "$f" 2> /dev/null)"; then busy="$busy $p"; else safe_rm "$f" || return 1; fi
    done
    [ -n "$busy" ] || return 0
    [ -n "$said" ] || echo "  wait other gates are running checks (pid$busy); the timed checks start when they finish"
    said=1
    sleep 2
  done
}

# gate_busy_on / gate_busy_off: mark this gate busy for longer than one par_run (pre-push keeps
# its mark through diff-coverage, coverage-baseline and tdd). Nested calls count: the mark goes
# at the last off.
GATE_BUSY_DEPTH=0
gate_busy_on() { _gate_busy_on; }
gate_busy_off() { _gate_busy_off; }
_gate_busy_on() {
  local d said="" s
  if [ "$GATE_BUSY_DEPTH" -gt 0 ]; then
    GATE_BUSY_DEPTH=$((GATE_BUSY_DEPTH + 1))
    return 0
  fi
  GATE_WAITED=0
  if _gate_nested; then
    GATE_BUSY_DEPTH=1
    return 0
  fi
  d="$(_gate_dir)"
  _gate_dir_ok || return 1
  s=$(date +%s)
  while :; do
    # Mark first, then look: a timed half that locks after this line sees the mark and waits.
    _gate_start $$ > "$d/busy/$$" || return 1
    if ! _gate_held "$d/timed.lock"; then
      GATE_WAITED=$(($(date +%s) - s))
      GATE_BUSY_DEPTH=1
      return 0
    fi
    safe_rm "$d/busy/$$" || return 1
    if _gate_ancestor "$(cat "$d/timed.lock/pid" 2> /dev/null)"; then
      echo "  the timed lock is held by this gate's own outer gate; a nested gate needs its own STANDARDS_LOCK_DIR"
      return 1
    fi
    [ -n "$said" ] || echo "  wait timed checks are running or waiting (pid $(cat "$d/timed.lock/pid" 2> /dev/null), $(cat "$d/timed.lock/what" 2> /dev/null)); these start when they finish"
    said=1
    sleep 2
  done
}
_gate_busy_off() {
  [ "$GATE_BUSY_DEPTH" -gt 0 ] || return 0
  GATE_BUSY_DEPTH=$((GATE_BUSY_DEPTH - 1))
  [ "$GATE_BUSY_DEPTH" -eq 0 ] || return 0
  _gate_nested || safe_rm "$(_gate_dir)/busy/$$"
}

par_run() {
  local title="$1" lanes="" l i p start wall rc secs line fails=0 own="" n=${#PAR_LABELS[@]}
  PAR_FAILED=""
  PAR_RCS=()
  if [ "$n" -eq 0 ]; then echo "FAIL $title: no check queued"; return 1; fi
  if [ -n "${PAR_LOG_DIR:-}" ]; then PAR_DIR="$PAR_LOG_DIR"
  else l="${TMPDIR:-/tmp}"; PAR_DIR="$(mktemp -d "${l%/}/standards-par.XXXXXX")" && own=1; fi
  mkdir -p "$PAR_DIR" 2> /dev/null || { echo "FAIL $title: cannot create the log dir $PAR_DIR"; return 1; }
  for ((i = 0; i < n; i++)); do
    case " $lanes " in *" ${PAR_LANES[$i]} "*) ;; *) lanes="$lanes ${PAR_LANES[$i]}" ;; esac
    # A reused PAR_LOG_DIR may hold an earlier run's exit codes; one must never count for this run.
    [ -n "$own" ] || safe_rm "$(_par_file "$i").rc" || return 1
  done
  # What runs, before anything runs.
  echo "$title: running $n check(s) at once, in these lanes (each lane in turn); logs in $PAR_DIR"
  for l in $lanes; do
    line=""
    for ((i = 0; i < n; i++)); do [ "${PAR_LANES[$i]}" = "$l" ] && line="$line ${PAR_LABELS[$i]} →"; done
    echo "  lane $l:${line% →}"
  done
  PAR_PIDS=""
  trap _par_stop INT TERM
  if ! _gate_busy_on; then
    trap - INT TERM
    echo "FAIL $title: cannot mark this gate busy in $(_gate_dir) (another gate's timed checks would run under its load)"
    return 1
  fi
  start=$(date +%s)
  for l in $lanes; do
    (
      # Gates a check starts are nested in this one (see _gate_nested).
      _gate_nested || export STANDARDS_GATE_BUSY=$$
      _par_lane "$l"
    ) &
    PAR_PIDS="$PAR_PIDS $!"
  done
  for p in $PAR_PIDS; do wait "$p"; done
  _gate_busy_off
  trap - INT TERM
  PAR_PIDS=""
  wall=$(($(date +%s) - start))
  # Each check's own output, whole, in queue order.
  for ((i = 0; i < n; i++)); do
    echo "----- ${PAR_LABELS[$i]} (lane ${PAR_LANES[$i]}): ${PAR_CMDS[$i]}"
    cat "$(_par_file "$i").log" 2> /dev/null
  done
  echo "----- $title verdict: ran $n check(s) in ${wall}s"
  for ((i = 0; i < n; i++)); do
    rc=""
    secs=""
    [ -f "$(_par_file "$i").rc" ] && read -r rc secs < "$(_par_file "$i").rc"
    PAR_RCS[$i]="$rc"
    if [ "$rc" = 0 ]; then
      echo "  PASS ${PAR_LABELS[$i]} (${secs}s)"
      continue
    fi
    if [ -z "$rc" ]; then echo "  FAIL ${PAR_LABELS[$i]} (no exit code: its lane stopped before it finished)"
    else echo "  FAIL ${PAR_LABELS[$i]} (exit $rc, ${secs}s; log $(_par_file "$i").log)"; fi
    fails=$((fails + 1))  # bite: count (tests/run.sh drops this line from a copy; cases must notice)
    PAR_FAILED="$PAR_FAILED ${PAR_LABELS[$i]}"
  done
  PAR_FAILED="${PAR_FAILED# }"
  if [ $fails -eq 0 ]; then
    echo "PASS $title: all $n check(s) passed"
    # Every log was printed above; a temp dir of our own is noise once nothing failed.
    [ -z "$own" ] || safe_rm "$PAR_DIR"
    return 0
  fi
  echo "FAIL $title: $fails of $n check(s) failed: $PAR_FAILED"
  return 1
}

par_rc() {
  local i rc=""
  for ((i = 0; i < ${#PAR_LABELS[@]}; i++)); do
    [ "${PAR_LABELS[$i]}" = "$1" ] || continue
    rc="${PAR_RCS[$i]:-}"
    break
  done
  printf '%s\n' "${rc:-1}"
}

par_failed() { printf '%s\n' "$PAR_FAILED"; }
