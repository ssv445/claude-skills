#!/usr/bin/env bash
# safe_rm from the installed .standards/lib/common.sh of the repo this runs in (the cwd),
# arguments passed through. tests/run.sh deletes and probes safe_rm only through this.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"
safe_rm "$@"
