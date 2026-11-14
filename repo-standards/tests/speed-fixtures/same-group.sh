#!/bin/sh
# Fixture: passes only when this process is in the same process group as pid $1 (the
# pre-push hook) — i.e. the command ran plainly, not in a separate timed group.
[ "$(ps -o pgid= -p $$ | tr -d ' ')" = "$(ps -o pgid= -p "$1" | tr -d ' ')" ]
