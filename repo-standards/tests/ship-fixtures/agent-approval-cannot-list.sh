#!/usr/bin/env bash
# Test stub for .standards/checks/agent-approval.sh: it cannot list the branch's gate files
# (as with no base, or a failed git diff), and never approves. bin/ship must then not merge.
[ "${1:-}" = "--gate-files" ] && exit 1
echo "  miss stub: the agent never approves"
exit 1
