#!/usr/bin/env bash
# DATA ONLY for tests/run.sh: stands in for DEPLOY_CMD and LIVE_CHECK_CMD. Logs the step, where
# it ran and the commit there to $PROBE_LOG, and exits with PROBE_DEPLOY_RC / PROBE_LIVE_RC
# (default 0). It leaves one untracked file, as a real build does, so the checkout is dirty
# when bin/ship removes it.
step="$1"
: > probe-build-output
printf '%s %s %s\n' "$step" "$(pwd -P)" "$(git rev-parse HEAD)" >> "$PROBE_LOG"
case "$step" in
  deploy) exit "${PROBE_DEPLOY_RC:-0}" ;;
  live) exit "${PROBE_LIVE_RC:-0}" ;;
esac
exit 2
