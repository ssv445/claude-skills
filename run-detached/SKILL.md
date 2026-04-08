---
name: run-detached
description: Run any slash command in a fresh `claude -p` subprocess inside a detached tmux session so it owns its own context and subagent budget. Use when a skill that itself spawns subagents (test-stories, quality-loop, nightshift) needs to be invoked from inside another subagent, or when you want heavy work off the main loop's context. Sessions are named `claude-run-<id>` and show up in claude-wormhole + `tmux ls`.
version: 0.1.0
allowed-tools:
  - Bash
  - Read
---

# run-detached

Spawn a fresh `claude -p` process inside a detached tmux session running `$ARGUMENTS` (a slash command + args), wait for it to finish, return the result.

**You are expected to be a disposable subagent when running this.** The main loop should have dispatched you via the `Agent` tool specifically so you can block on this and keep main context clean. If you are the main loop, stop and reconsider — you probably want to spawn an Agent first and have *it* invoke this skill.

## Why tmux

- User can `tmux attach -r -t claude-run-<id>` any time to watch live (read-only).
- Appears in claude-wormhole UI automatically (wormhole lists all tmux sessions).
- Survives your subagent being killed — session keeps running, you can reattach on next poll.
- Plays nicely with existing `cld.sh` / wormhole workflow.

## Inputs

`$ARGUMENTS` — the full slash command + args to run inside the child. Examples:

- `/test-stories TS-001 TS-002`
- `/quality-loop "polish feed" 5`
- `/nightshift:run 142`

Must start with `/`. If not, abort and tell the caller.

## Prerequisites

- `tmux` must be on PATH. Check `command -v tmux`. If missing, abort with a clear error — do NOT silently fall back.

## Steps

### 1. Generate run id + paths

```bash
SLUG=$(echo "$ARGUMENTS" | tr -c 'a-zA-Z0-9' '-' | cut -c1-24 | sed 's/-*$//')
RUN_ID="$(date +%Y%m%d-%H%M%S)-$SLUG"
RUN_DIR=".tmp/claude-runs/$RUN_ID"
mkdir -p "$RUN_DIR"
LOG="$RUN_DIR/output.log"
SESSION="claude-run-$RUN_ID"
```

Report to caller: `run_id`, `session_name`, `log_path`, and the attach command.

### 2. Spawn detached tmux session

```bash
tmux new-session -d -s "$SESSION" -c "$PWD" \
  "claude -p \"$ARGUMENTS\" --dangerously-skip-permissions 2>&1 | tee \"$LOG\"; exit"
```

Verify it came up:

```bash
tmux has-session -t "$SESSION" && echo "UP" || echo "FAILED"
```

If failed, abort with error.

### 3. Poll until done

Loop. Interval: ~30s. Hard cap: 4h (480 iterations).

Each iteration, run:

```bash
tmux has-session -t "$SESSION" 2>/dev/null && echo "RUNNING" || echo "DONE"
```

When `DONE`, break.

Between polls, do nothing else. Just wait and poll. Do not start other work.

**Optional sanity tail** every few polls:

```bash
tail -c 2048 "$LOG" 2>/dev/null
```

Useful if you want to notice the child is producing output (vs hung) — but don't act on the content, just observe.

**Timeout:** if 4h cap hit, kill the session:

```bash
tmux kill-session -t "$SESSION"
```

Return `exit_status: timeout`.

### 4. Determine exit status

tmux doesn't surface child exit code after session ends. Heuristic:

- `Read` the last ~8KB of `$LOG`.
- If log ends with obvious errors (`Error:`, `Traceback`, `permission denied`, etc.), set `exit_status=error`.
- Otherwise `exit_status=0`.

This is a heuristic — caller should read the log themselves if they need certainty.

### 5. Return to caller

Compact summary:

```
run_id: <id>
session_name: claude-run-<id>
log_path: .tmp/claude-runs/<id>/output.log
exit_status: 0 | error | timeout
attach_cmd: tmux attach -r -t claude-run-<id>
output_tail: |
  <last ~4KB of log>
```

If the caller asked for a specific synthesis (e.g. *"return the test-stories report"*), `Read` more of `$LOG` and synthesize — don't just dump the tail.

## Failure modes

| Situation | Action |
|---|---|
| `tmux` not installed | Abort with clear error. Do not fall back. |
| `$ARGUMENTS` doesn't start with `/` | Abort, tell caller. |
| Session fails to start | Abort, return stderr. |
| Log file missing after session ends | Return `exit_status=log-missing`. |
| 4h cap reached | `tmux kill-session`, return `exit_status=timeout`. |

## Caveats to surface in your return message

- Child runs with `--dangerously-skip-permissions` — full tool access.
- Child has its own token budget + cost.
- cwd inherited from this subagent.
- No live streaming to main loop. User can `tmux attach -r -t <session>` or open claude-wormhole to watch live.
- Exit status is heuristic (log-based). Caller should verify from log content if it matters.

## Example flow

Main loop spawns an Agent:

> "Run `/test-stories TS-001 TS-002` via the `run-detached` skill. Return the final test-stories report as a concise summary — pass/fail per story, key issues."

Agent subagent:

1. Invokes `/run-detached /test-stories TS-001 TS-002`.
2. Follows steps above. Session `claude-run-20260408-143022-test-stories-TS-001` is now visible in `tmux ls` and in claude-wormhole.
3. Polls every 30s for however long test-stories takes.
4. On completion, reads relevant sections of `output.log`, synthesizes the requested summary, returns it.

Main loop receives only the summary. Its context stays clean. User could have watched the whole thing live via wormhole if curious.
