#!/bin/sh
# DATA ONLY for tests/run.sh: a repo's own pre-push check in .standards/local/pre-push.d/.
# Prints what it scanned, then exits with LOCAL_RC (default 0).
echo "local-probe: scanned src/"
exit "${LOCAL_RC:-0}"
