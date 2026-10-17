#!/usr/bin/env bash
# DATA ONLY for tests/run.sh: an unmerged edit of the repo's deploy script. bin/ship must never
# run it: the deploy runs the base's copy. Logs "branch-copy" so a test can see if it ran.
printf 'branch-copy %s\n' "$(pwd -P)" >> "$PROBE_LOG"
exit 0
