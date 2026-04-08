---
name: run-detached
description: Run any slash command or prompt in a fresh `claude -p` subprocess inside a detached tmux session so it owns its own context and subagent budget. Use when a skill that itself spawns subagents (test-stories, quality-loop, nightshift) needs to be invoked from inside another subagent, or when you want heavy work off the main loop's context. Sessions are named `detached-run-claude-<id>` and show up in claude-wormhole + `tmux ls`.
version: 0.2.0
allowed-tools:
  - Bash
  - Read
---

# run-detached

Spawn a fresh `claude -p` process inside a detached tmux session running `$ARGUMENTS`, wait for it to finish, return the result.

**You are expected to be a disposable subagent when running this.** The main loop should have dispatched you via the `Agent` tool specifically so you can block on this and keep main context clean. If you are the main loop, stop and reconsider — you probably want to spawn an Agent first and have *it* invoke this skill.

## Why tmux

- User can `tmux attach -r -t detached-run-claude-<id>` any time to watch live (read-only).
- Appears in claude-wormhole UI automatically (wormhole lists all tmux sessions).
- Live output is streamed through a formatter (`format-stream.py`) that renders `claude -p --output-format stream-json` events as readable colored text — tool calls, results, partial assistant text, final summary. Much nicer than raw JSON.
- Survives your subagent being killed — session keeps running, you can reattach on next poll.

## Inputs

`$ARGUMENTS` — the prompt to pass to the child `claude -p`. Usually a slash command, but any raw prompt works since `claude -p` accepts natural-language input too. Examples:

- `/test-stories TS-001 TS-002`
- `/quality-loop "polish feed" 5`
- `/nightshift:run 142`
- `Compute 7 times 8. Output only the number.`

## Prerequisites

- `tmux`, `claude`, and `python3` must be on `PATH`. The spawn script verifies this and aborts if any is missing.

## Steps

You **must** run the pre-built scripts that ship with this skill (`run-detached.sh`, `run-worker.py`, `format-stream.py`). Do **not** re-implement the spawn logic inline — the scripts handle shell quoting of arbitrary prompts, stream-json formatting, absolute-path pitfalls with `tmux pipe-pane`, and a marker-file signal that's more reliable than `tmux has-session` for detecting completion. Every time an agent has tried to rewrite the spawn step, it has broken in a new way. Use the scripts.

### 1. Spawn

Invoke `run-detached.sh` and pipe `$ARGUMENTS` on stdin via a heredoc. The script prints metadata as `key=value` lines on stdout — capture the output, then parse the values you need.

```bash
META=$(~/.claude/skills/run-detached/run-detached.sh <<'RUN_DETACHED_EOF'
$ARGUMENTS
RUN_DETACHED_EOF
)
# Parse the fields you'll need
RUN_ID=$(echo "$META"      | awk -F= '/^run_id=/{print $2}')
SESSION=$(echo "$META"     | awk -F= '/^session_name=/{print $2}')
RUN_DIR=$(echo "$META"     | awk -F= '/^run_dir=/{print $2}')
LOG=$(echo "$META"         | awk -F= '/^log_path=/{print $2}')
MARKER=$(echo "$META"      | awk -F= '/^marker_path=/{print $2}')
ATTACH_CMD=$(echo "$META"  | awk -F= '/^attach_cmd=/{print $2}')
echo "$META"  # show the caller
```

> **Heredoc note.** Use the exact sentinel `RUN_DETACHED_EOF` with **single quotes** around it. Single quotes prevent the shell from expanding `$`, backticks, etc., inside the prompt — critical when the prompt contains shell syntax, other skill invocations, or JSON.

If the script exits non-zero, abort and report its stderr to the caller.

Report to caller: `run_id`, `session_name`, `log_path`, `attach_cmd`.

### 2. Poll until done

Loop. Interval: ~30s. Hard cap: 4h (480 iterations).

Each iteration, check for the marker file. It appears when the worker process exits cleanly; its content is the child claude's exit code.

```bash
if [ -f "$MARKER" ]; then
  EXIT_CODE=$(cat "$MARKER")
  echo "DONE (exit=$EXIT_CODE)"
else
  echo "RUNNING"
fi
```

When `DONE`, break.

Between polls, do nothing else. Just wait and poll. Do not start other work.

**Optional sanity tail** every few polls:

```bash
tail -c 2048 "$LOG" 2>/dev/null
```

Useful to notice the child is producing output (vs hung) — but don't act on the content, just observe.

**Timeout:** if the 4h cap is hit, kill the session and return `exit_status: timeout`:

```bash
tmux kill-session -t "$SESSION"
```

### 3. Read the result

Once `DONE`:

```bash
EXIT_CODE=$(cat "$MARKER")  # 0 on success, non-zero otherwise
```

Use the `Read` tool on `$LOG` (absolute path) to pull out whatever the caller asked for. The log is colored/formatted text with ANSI escapes — they're harmless but you can strip them with `sed 's/\x1b\[[0-9;]*m//g'` if you need plain text.

The final answer from the child is always the last `─── success …` block in the log, followed by the child's `result` text.

### 4. Return to caller

Compact summary:

```
run_id: <id>
session_name: detached-run-claude-<id>
log_path: <absolute path>
exit_status: <EXIT_CODE from marker> | timeout
attach_cmd: tmux attach -r -t detached-run-claude-<id>
output_tail: |
  <last ~4KB of log, ANSI-stripped>
```

If the caller asked for a specific synthesis (e.g. *"return the test-stories report"*), `Read` more of `$LOG` and synthesize — don't just dump the tail.

## Files that ship with this skill

| File | Purpose |
|---|---|
| `SKILL.md` | This doc. |
| `run-detached.sh` | Entry point. Creates paths, spawns the tmux session, attaches log capture, prints metadata. Reads prompt from stdin. |
| `run-worker.py` | Runs inside the tmux pane. Invokes `claude -p` via Python subprocess (prompt as literal argv — no shell quoting), pipes stream-json output through the formatter, writes the done marker on exit. |
| `format-stream.py` | Renders `claude -p --output-format stream-json` events as readable colored text (tool calls, results, partial assistant text, final summary). |

## Failure modes

| Situation | Action |
|---|---|
| `tmux`/`claude`/`python3` missing | `run-detached.sh` aborts with clear error. Do not fall back. |
| Session fails to start | `run-detached.sh` exits non-zero. Abort, relay stderr. |
| Marker file never appears | Either the worker crashed before writing it, or the tmux session is still alive. Check `tmux has-session -t "$SESSION"` — if alive, keep polling; if dead, treat as `exit_status=crashed` and return the tail of the log. |
| 4h cap reached | `tmux kill-session`, return `exit_status=timeout`. |

## Caveats to surface in your return message

- Child runs with `--dangerously-skip-permissions` — full tool access.
- Child has its own token budget + cost. Nested run-detached calls multiply this; the final `─── success • N turns • Ts • $X.XXXX` line from each level tells you what you spent.
- cwd inherited from this subagent.
- Live view is available via `tmux attach -r -t <session>` or claude-wormhole. The pane shows the formatted stream in real time.

## Example flow

Main loop spawns an Agent:

> "Run `/test-stories TS-001 TS-002` via the `run-detached` skill. Return the final test-stories report as a concise summary — pass/fail per story, key issues."

Agent subagent:

1. Pipes `/test-stories TS-001 TS-002` into `~/.claude/skills/run-detached/run-detached.sh`, captures the metadata.
2. Session `detached-run-claude-20260408-143022-test-stories-TS-001` is now visible in `tmux ls` and in claude-wormhole; pane shows live tool calls and assistant output via the formatter.
3. Polls `test -f "$MARKER"` every 30s for however long test-stories takes.
4. On completion, reads the relevant sections of `output.log`, synthesizes the requested summary, returns it.

Main loop receives only the summary. Its context stays clean. User could have watched the whole thing live via wormhole if curious.
