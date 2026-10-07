#!/usr/bin/env bash
# Claude Code PreToolUse guard (Bash tool). Reads the hook JSON on stdin; exit 2 blocks
# the call and shows stderr to the agent. A speed bump for agents, not a security
# boundary: agents share the owner's shell and gh login.
cmd="$(jq -r '.tool_input.command // ""')"

block() { printf 'repo-standards guard: %s\n' "$1" >&2; exit 2; }

printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge' \
  && block "merge only through bin/ship, which runs the pre-merge gates."
printf '%s' "$cmd" | grep -Eq -- '--no-verify|core\.hooksPath|HUSKY=0|LEFTHOOK=0|SKIP_HOOKS' \
  && block "hooks are the gates; fix what they report instead of bypassing them."
printf '%s' "$cmd" | grep -Eq 'bin/approve' \
  && block "approval is the owner's — ask them to run bin/approve at their terminal."
printf '%s' "$cmd" | grep -Eq -- '--(add|remove)-label[= ]+[^ ]*approved|gh[[:space:]]+(api|label)[^|;&]*approved' \
  && block "approved / spec-approved labels are the owner's alone."
exit 0
