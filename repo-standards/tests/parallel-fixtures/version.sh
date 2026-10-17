#!/bin/sh
# Test fake VERDICT_KEY_CMD for the speed cases in tests/run.sh: prints the tool version held in
# FAKE_VERSION, so a case can change a "tool" without installing anything; FAKE_VERSION=fail
# makes it fail, as a broken version command would.
[ "${FAKE_VERSION:-}" != fail ] || { echo "version: cannot read"; exit 1; }
echo "tool ${FAKE_VERSION:-v0}"
