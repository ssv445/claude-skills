#!/usr/bin/env bash
# Claude Code PreToolUse guard (Bash tool). Reads the hook JSON on stdin; exit 2 blocks
# the call and shows stderr to the agent. A speed bump for agents, not a security
# boundary: agents share the owner's shell and gh login.
#
# It judges only commands aimed at this repo (the one holding .standards/guard.sh): a
# command that starts with `cd <dir>` or uses `git -C <dir>` outside it, runs from a
# session cwd outside it, or names another GitHub repo with -R/--repo, is not its business.
# It reads the hook JSON with jq. Without jq (or on JSON jq cannot read) it cannot tell what
# a command does, so from a session cwd in this repo it blocks everything but installing jq.
block() { printf 'repo-standards guard: %s\n' "$1" >&2; exit 2; }

json="$(cat)"
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
root="$(cd "$root" && pwd -P)"

# raw_field <key>: a top-level-looking "key":"value" read without jq. Only values with no
# quote or backslash are read; anything else reads as empty (and so counts as this repo).
raw_field() { printf '%s' "$json" | sed -nE 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]*)".*/\1/p' | head -1; }
if ! command -v jq >/dev/null 2>&1; then
  c="$(raw_field cwd)"
  if [ -n "$c" ] && t="$(cd "$c" 2>/dev/null && pwd -P)"; then
    case "$t/" in "$root"/*) ;; *) exit 0 ;; esac
  fi
  # The way out: a command that is only a package-manager install of jq, nothing chained.
  raw_field command | grep -Eqx '[[:space:]]*(sudo[[:space:]]+)?(brew|apt-get|apt|dnf|yum|apk|pacman|port)[[:space:]]+(install|add|-S)([[:space:]]+-[^[:space:];&|]+)*[[:space:]]+jq[[:space:]]*' && exit 0
  block "guard needs jq to read commands aimed at this repo — install it (macOS: brew install jq; Debian/Ubuntu: sudo apt-get install jq). That install command is allowed; everything else here is blocked until then."
fi
# jq failing (malformed hook JSON) would leave the command empty and pass every check below.
cmd="$(printf '%s' "$json" | jq -r '.tool_input.command // ""')" \
  && cwd="$(printf '%s' "$json" | jq -r '.cwd // ""')" \
  || block "could not read the hook JSON (jq failed) — the command cannot be judged, so it is blocked."

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
# Setting or unsetting core.hooksPath, not reading it. The install's own setup line
# (`git config [--local] core.hooksPath .standards/hooks`, exactly, ending the command) points
# hooks AT the gates, so it is dropped first; anything else chained to it is still judged.
# A read (`git config --get[-all|-regexp] core.hooksPath`) is dropped the same way — only that
# segment, so a read cannot excuse a write chained after it.
# Lowercased first: git config section and key names are case-insensitive (core.HOOKSPATH is
# core.hooksPath).
hp="$(printf '%s\n' "$cmd" | tr '[:upper:]' '[:lower:]' | sed -E \
  -e 's#git[[:space:]]+config[[:space:]]+(--local[[:space:]]+)?core\.hookspath[[:space:]]+\.standards/hooks([[:space:]]*([;&|]|$))#\2#g' \
  -e 's#git[[:space:]]+config[[:space:]]+(--local[[:space:]]+)?--get(-all|-regexp)?[[:space:]]+core\.hookspath([[:space:]]*([;&|]|$))#\3#g')"
if printf '%s' "$hp" | grep -Eq -- 'core\.hookspath[[:space:]]*=|--unset(-all)?[[:space:]]+core\.hookspath|core\.hookspath[[:space:]]+[^;&|[:space:]]'; then
  block "hooks are the gates; fix what they report instead of bypassing them."
fi
printf '%s' "$cmd" | grep -Eq "${at_cmd}([^;&|[:space:]]*/)?bin/approve([[:space:]]|$)" \
  && block "approval is the owner's — ask them to run bin/approve at their terminal."
printf '%s' "$cmd" | grep -Eq -- '--(add|remove)-label[= ]+[^ ]*approved|gh[[:space:]]+(api|label)[^|;&]*approved' \
  && block "approved / spec-approved labels are the owner's alone."
exit 0
