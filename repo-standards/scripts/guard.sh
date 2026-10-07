#!/usr/bin/env bash
# Claude Code PreToolUse guard (Bash tool). Reads the hook JSON on stdin; exit 2 blocks
# the call and shows stderr to the agent. A speed bump for agents, not a security
# boundary: agents share the owner's shell and gh login.
#
# It judges only commands aimed at this repo (the one holding .standards/guard.sh): a
# command that starts with `cd <dir>` or uses `git -C <dir>` outside it, runs from a
# session cwd outside it, or names another GitHub repo with -R/--repo, is not its business.
json="$(cat)"
cmd="$(printf '%s' "$json" | jq -r '.tool_input.command // ""')"
cwd="$(printf '%s' "$json" | jq -r '.cwd // ""')"

block() { printf 'repo-standards guard: %s\n' "$1" >&2; exit 2; }

root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
root="$(cd "$root" && pwd -P)"

# Heredoc bodies are data (file contents, messages), never commands: drop them.
cmd="$(printf '%s\n' "$cmd" | awk '
  d != "" { t = $0; sub(/^\t+/, "", t); if (t == d) d = ""; next }
  { print }
  match($0, /<<-?[ \t]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*/) {
    d = substr($0, RSTART, RLENGTH); sub(/^<<-?[ \t]*["'"'"']?/, "", d)
  }')"

# Target dir: a leading `cd <dir>`, else `git -C <dir>`, else the session cwd. No cwd in
# the hook JSON → this repo (fail closed).
dir="$(printf '%s' "$cmd" | sed -nE '1s/^[[:space:]]*cd[[:space:]]+([^;&|[:space:]]+).*/\1/p')"
[ -n "$dir" ] || dir="$(printf '%s' "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^;&|[:space:]]+).*/\1/p' | head -1)"
dir="${dir%\"}"; dir="${dir#\"}"; dir="${dir%\'}"; dir="${dir#\'}"
case "$dir" in "~") dir="$HOME" ;; "~/"*) dir="$HOME/${dir#\~/}" ;; esac
base="${cwd:-$root}"
[ -z "$dir" ] && dir="$base"
case "$dir" in /*) ;; *) dir="$base/$dir" ;; esac
# A dir that does not resolve counts as this repo (fail closed).
if target="$(cd "$dir" 2>/dev/null && pwd -P)"; then
  case "$target/" in "$root"/*) ;; *) exit 0 ;; esac
fi

# -R / --repo naming a GitHub repo other than this one's origin.
other="$(printf '%s' "$cmd" | sed -nE 's/.*(^|[[:space:]])(-R|--repo)[=[:space:]]+([^;&|[:space:]]+).*/\3/p' | head -1)"
if [ -n "$other" ]; then
  slug() { printf '%s' "$1" | sed -E 's#^(https?://)?(www\.)?github\.com[:/]##; s#^git@github\.com:##; s#\.git$##' | tr '[:upper:]' '[:lower:]'; }
  mine="$(slug "$(git -C "$root" remote get-url origin 2>/dev/null)")"
  [ -n "$mine" ] && [ "$(slug "$other")" != "$mine" ] && exit 0
fi

# Command position: start of a line, or after ; & | ( — optionally via bash/sh/zsh.
at_cmd='(^|[;&|(])[[:space:]]*((bash|sh|zsh)[[:space:]]+)?'

printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge' \
  && block "merge only through bin/ship, which runs the pre-merge gates."
printf '%s' "$cmd" | grep -Eq -- '--no-verify|HUSKY=0|LEFTHOOK=0|SKIP_HOOKS' \
  && block "hooks are the gates; fix what they report instead of bypassing them."
# Setting or unsetting core.hooksPath, not reading it.
if printf '%s' "$cmd" | grep -Eq -- 'core\.hooksPath[[:space:]]*=|--unset(-all)?[[:space:]]+core\.hooksPath|core\.hooksPath[[:space:]]+[^;&|[:space:]]' \
   && ! printf '%s' "$cmd" | grep -Eq -- '--get(-all|-regexp)?[[:space:]]+core\.hooksPath'; then
  block "hooks are the gates; fix what they report instead of bypassing them."
fi
printf '%s' "$cmd" | grep -Eq "${at_cmd}([^;&|[:space:]]*/)?bin/approve([[:space:]]|$)" \
  && block "approval is the owner's — ask them to run bin/approve at their terminal."
printf '%s' "$cmd" | grep -Eq -- '--(add|remove)-label[= ]+[^ ]*approved|gh[[:space:]]+(api|label)[^|;&]*approved' \
  && block "approved / spec-approved labels are the owner's alone."
exit 0
