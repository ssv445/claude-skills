---
name: run-detached
description: Run any slash command or prompt in a fresh `claude -p` subprocess inside a detached tmux session so it owns its own context and subagent budget. Use when a skill that itself spawns subagents (test-stories, quality-loop, nightshift) needs to be invoked from inside another subagent, or when you want heavy work off the main loop's context. Sessions are named `detached-run-claude-<id>` and show up in claude-wormhole + `tmux ls`.
version: 0.2.0
allowed-tools:
  - Bash
  - Read
---

# run-detached

Spawn fresh `claude -p` in detached tmux session running `$ARGUMENTS`, wait for completion, return result.

**You are a disposable subagent.** Main loop should have dispatched you via Agent tool. If you ARE main loop — stop, spawn an Agent first to invoke this.

## Why tmux

- User can `tmux attach -r -t detached-run-claude-<id>` to watch live (read-only)
- Shows in claude-wormhole automatically
- Live output streamed through `format-stream.py` — renders stream-json as readable colored text
- Survives subagent kill — session keeps running, reattach on next poll

## Inputs

`$ARGUMENTS` — prompt for child `claude -p`. Slash commands or raw prompts both work.

## Prerequisites

`tmux`, `claude`, `python3` on PATH. Spawn script verifies, aborts if missing.

## Steps

**Use the pre-built scripts** (`run-detached.sh`, `run-worker.py`, `format-stream.py`). Do NOT re-implement spawn logic inline — scripts handle shell quoting, stream-json formatting, absolute-path pitfalls with `tmux pipe-pane`, and marker-file signaling. Every inline rewrite has broken.

### 1. Spawn

Pipe `$ARGUMENTS` on stdin via heredoc:

```bash
META=$(~/.claude/skills/run-detached/run-detached.sh <<'RUN_DETACHED_EOF'
$ARGUMENTS
RUN_DETACHED_EOF
)
RUN_ID=$(echo "$META"      | awk -F= '/^run_id=/{print $2}')
SESSION=$(echo "$META"     | awk -F= '/^session_name=/{print $2}')
RUN_DIR=$(echo "$META"     | awk -F= '/^run_dir=/{print $2}')
LOG=$(echo "$META"         | awk -F= '/^log_path=/{print $2}')
MARKER=$(echo "$META"      | awk -F= '/^marker_path=/{print $2}')
ATTACH_CMD=$(echo "$META"  | awk -F= '/^attach_cmd=/{print $2}')
echo "$META"
```

> **Heredoc:** Use exact sentinel `RUN_DETACHED_EOF` with **single quotes**. Prevents shell expansion of `$`, backticks inside prompt.

Non-zero exit → abort, report stderr. Report to caller: `run_id`, `session_name`, `log_path`, `attach_cmd`.

### 2. Poll until done

Loop ~30s interval. Hard cap: 4h (480 iterations).

```bash
if [ -f "$MARKER" ]; then
  EXIT_CODE=$(cat "$MARKER")
  echo "DONE (exit=$EXIT_CODE)"
else
  echo "RUNNING"
fi
```

When DONE, break. Between polls, do nothing else.

**Optional sanity tail** every few polls: `tail -c 2048 "$LOG" 2>/dev/null` — observe output, don't act on content.

**Timeout** at 4h cap: `tmux kill-session -t "$SESSION"`, return `exit_status: timeout`.

### 3. Read result

```bash
EXIT_CODE=$(cat "$MARKER")
```

Read `$LOG` via Read tool. Final answer is last `─── success …` block followed by `result` text. Strip ANSI if needed: `sed 's/\x1b\[[0-9;]*m//g'`.

### 4. Return to caller

```
run_id: <id>
session_name: detached-run-claude-<id>
log_path: <absolute path>
exit_status: <EXIT_CODE> | timeout
attach_cmd: tmux attach -r -t detached-run-claude-<id>
output_tail: |
  <last ~4KB of log, ANSI-stripped>
```

If caller asked for specific synthesis, Read more of `$LOG` and synthesize — don't just dump tail.

## Files

| File | Purpose |
|---|---|
| `run-detached.sh` | Entry point. Creates paths, spawns tmux, attaches log capture, prints metadata. Reads prompt from stdin. |
| `run-worker.py` | Runs inside tmux pane. Invokes `claude -p` via subprocess (prompt as literal argv), pipes through formatter, writes done marker. |
| `format-stream.py` | Renders stream-json events as readable colored text. |

## Failure modes

| Situation | Action |
|---|---|
| `tmux`/`claude`/`python3` missing | Script aborts. Do not fall back. |
| Session fails to start | Script exits non-zero. Abort, relay stderr. |
| Marker never appears | Check `tmux has-session -t "$SESSION"` — alive → keep polling; dead → `exit_status=crashed`, return log tail. |
| 4h cap | `tmux kill-session`, `exit_status=timeout`. |

## Caveats (surface in return message)

- Child runs `--dangerously-skip-permissions` — full tool access.
- Child has own token budget + cost. Nested calls multiply. Final `─── success • N turns • Ts • $X.XXXX` shows spend.
- cwd inherited from this subagent.
- Live view: `tmux attach -r -t <session>` or claude-wormhole.
