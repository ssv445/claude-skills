#!/usr/bin/env bash
# Fixture: a caller with its own TERM trap runs a timed command, then prints its TERM trap.
# run_timed must put the caller's trap back, not reset it.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"
trap 'echo caller-trap' TERM
CMD_TIMEOUT=5
run_cmd probe true >/dev/null
trap -p TERM
