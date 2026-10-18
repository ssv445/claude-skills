#!/bin/sh
# Test fake uname for the speed cases in tests/run.sh: prints FAKE_UNAME, so a case can change
# the "os" line of the verdict key without another machine.
echo "${FAKE_UNAME:-FakeOS 1.0 x86_64}"
