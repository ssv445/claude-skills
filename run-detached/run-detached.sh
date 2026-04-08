#!/bin/bash
# run-detached.sh — spawn a detached `claude -p` tmux session for the
# run-detached skill. Reads the prompt from stdin and prints metadata
# key=value lines for the caller to parse.
#
# Usage:
#   run-detached.sh <<'EOF'
#   multi-line prompt content
#   goes here, can contain any characters
#   EOF
#
# Output (stdout, one per line):
#   run_id=<id>
#   session_name=detached-run-claude-<id>
#   run_dir=<absolute path>
#   log_path=<absolute path to formatted output log>
#   prompt_path=<absolute path to prompt file>
#   marker_path=<absolute path — file appears when claude exits>
#   attach_cmd=tmux attach -r -t <session_name>
#
# The caller should poll `test -f <marker_path>` every ~30s and read the
# log when it appears. The marker file's content is claude's exit code.
set -euo pipefail

# Prereqs
for cmd in tmux claude python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: $cmd not on PATH" >&2
    exit 1
  fi
done

# Prompt comes from stdin so the caller never has to shell-escape it.
PROMPT=$(cat)
if [ -z "${PROMPT// /}" ]; then
  echo "error: empty prompt (expected on stdin)" >&2
  exit 1
fi

# Paths — all absolute. tmux pipe-pane runs its command from the tmux
# server's cwd, so relative log paths silently write to the wrong place.
SLUG=$(printf '%s' "$PROMPT" | tr -c 'a-zA-Z0-9' '-' | cut -c1-24 | sed 's/-*$//')
[ -z "$SLUG" ] && SLUG="run"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$SLUG"
RUN_DIR="$(pwd)/.tmp/claude-runs/$RUN_ID"
mkdir -p "$RUN_DIR"
LOG="$RUN_DIR/output.log"
PROMPT_FILE="$RUN_DIR/prompt.txt"
MARKER="$RUN_DIR/done"
SESSION="detached-run-claude-$RUN_ID"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMATTER="$SCRIPT_DIR/format-stream.py"
WORKER="$SCRIPT_DIR/run-worker.py"

for f in "$FORMATTER" "$WORKER"; do
  if [ ! -f "$f" ]; then
    echo "error: missing $f" >&2
    exit 1
  fi
done

# Persist the prompt to disk so the worker can read it as a file
# (avoids every form of shell/tmux quoting trap).
printf '%s' "$PROMPT" > "$PROMPT_FILE"

# Spawn. Python worker handles the claude subprocess via argv — no shell.
# The `; exit` at the end makes the tmux pane's shell quit after the
# worker returns, which tears the session down on completion.
tmux new-session -d -s "$SESSION" -c "$(pwd)" \
  -e "WORKER_DONE_MARKER=$MARKER" \
  "python3 '$WORKER' '$PROMPT_FILE' '$FORMATTER'; exit"

# Sanity check
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "error: tmux session failed to start" >&2
  exit 1
fi

# Capture the formatted pane output to the log file (absolute path required).
tmux pipe-pane -t "$SESSION" -o "cat >> '$LOG'"

# Metadata for caller
cat <<EOF
run_id=$RUN_ID
session_name=$SESSION
run_dir=$RUN_DIR
log_path=$LOG
prompt_path=$PROMPT_FILE
marker_path=$MARKER
attach_cmd=tmux attach -r -t $SESSION
EOF
