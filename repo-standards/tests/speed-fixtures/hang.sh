#!/bin/sh
# Fixture: a test command that hangs. Records its own pid and its child's in hang.pids,
# so the test can check the timeout stopped both.
sleep 30 &
echo "$$ $!" > hang.pids
wait
