#!/bin/sh
# Test fake for the speed cases in tests/run.sh: copied in under the name of a check (lint.sh,
# e2e.sh, perf.sh, …). It records how it was called, with start and end times, sleeps FAKE_SLEEP
# seconds (default 0), creates the empty file FAKE_TOUCH when set (a check that changes the tree
# while it runs), and exits 1 when "<name> <args>" contains FAKE_FAIL (a plain substring, never
# run), 0 otherwise. With FAKE_LIST set to a dir, it also writes "<name> <args>: <entries>" to
# $FAKE_LOG.list (what a gate's busy dir holds while this check runs). It runs nothing it is given.
call="$(basename "$0") $*"
log="${FAKE_LOG:-/dev/null}"
printf 'start %s %s\n' "$(date +%s)" "$call" >> "$log"
[ -z "${FAKE_LIST:-}" ] || printf '%s: %s\n' "$call" "$(ls "$FAKE_LIST" 2> /dev/null | tr '\n' ' ')" >> "$log.list"
[ -z "${FAKE_SLEEP:-}" ] || sleep "$FAKE_SLEEP"
[ -z "${FAKE_TOUCH:-}" ] || : > "$FAKE_TOUCH"
printf 'end %s %s\n' "$(date +%s)" "$call" >> "$log"
printf '%s\n' "$call" >> "$log.calls"
case "$call" in
  *"${FAKE_FAIL:-<no fail>}"*) echo "fake: failing on purpose: $call"; exit 1 ;;
esac
echo "fake: ran $call"
exit 0
