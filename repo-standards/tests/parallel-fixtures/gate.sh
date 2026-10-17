#!/usr/bin/env bash
# gate.sh <step>...: a stand-in gate for the speed cases in tests/run.sh. Sources the installed
# common.sh of the repo it runs in (the cwd), then parallel.sh and ship-checks.sh from
# $STANDARDS_LIB (default that repo's .standards/lib, so a case can point at a weakened copy),
# and runs the steps in order; the first that fails ends it with exit 1.
#   job=<lane>:<label>:<command>  queue a check; it first touches $PAR_MARKS/<label> when set
#   run                           par_run the queued checks as "set"; later steps still run, and
#                                 its exit code is the script's (unless a step fails)
#   repo-id                       print _gate_repo_id (the per-clone lock id)
#   rc=<label>                    print "rc <label>=<par_rc>"
#   failed                        print "failed=<par_failed>"
#   lock=<name> / unlock=<name>   gate_lock / gate_unlock; lock prints "locked <name> after <s>s"
#   idle                          gate_wait_idle, then print "idle after <s>s"
#   busy-on / busy-off            gate_busy_on / gate_busy_off
#   marked                        print "marked" or "unmarked": this gate's busy mark exists
#   held=<dir>                    print "held" or "free" (_gate_held)
#   alone=<command>               ship_alone on the command
#   ship                          ship_checks (bin/ship's e2e and perf step)
#   inner=<step>                  this script again, as a child, with that one step: "inner exit <rc>"
#   log=<word>                    append "<word> <epoch> $GATE_NAME" to $GATE_LOG
#   sleep=<seconds>
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh" || exit 9
lib="${STANDARDS_LIB:-$ROOT/.standards/lib}"
. "$lib/parallel.sh" && . "$lib/ship-checks.sh" || exit 9
self="$0"
case "$self" in /*) ;; *) self="$PWD/$self" ;; esac

step() {
  local s
  case "$1" in
    job=*)
      s="${1#job=}"
      local lane="${s%%:*}" rest="${s#*:}"
      local label="${rest%%:*}" cmd="${rest#*:}"
      par_job "$lane" "$label" "[ -z \"\${PAR_MARKS:-}\" ] || : > \"\$PAR_MARKS/$label\"; $cmd" ;;
    run) par_run set; last=$? ;;
    repo-id) _gate_repo_id ;;
    rc=*) echo "rc ${1#rc=}=$(par_rc "${1#rc=}")" ;;
    failed) echo "failed=$(par_failed)" ;;
    lock=*) s=$(date +%s); gate_lock "${1#lock=}" && echo "locked ${1#lock=} after $(($(date +%s) - s))s" ;;
    unlock=*) gate_unlock "${1#unlock=}" ;;
    idle) s=$(date +%s); gate_wait_idle && echo "idle after $(($(date +%s) - s))s" ;;
    busy-on) gate_busy_on ;;
    busy-off) gate_busy_off ;;
    marked) if [ -e "$(_gate_dir)/busy/$$" ]; then echo marked; else echo unmarked; fi ;;
    held=*) if _gate_held "${1#held=}"; then echo held; else echo free; fi ;;
    alone=*) ship_alone eval "${1#alone=}" ;;
    ship) ship_checks ;;
    inner=*) "$self" "${1#inner=}"; echo "inner exit $?" ;;
    log=*) printf '%s %s %s\n' "${1#log=}" "$(date +%s)" "${GATE_NAME:-}" >> "$GATE_LOG" ;;
    sleep=*) sleep "${1#sleep=}" ;;
    *) echo "gate.sh: unknown step $1"; return 2 ;;
  esac
}
for a in "$@"; do
  step "$a" || { echo "gate.sh: step failed: $a"; exit 1; }
done
exit "${last:-0}"
