# run-detached — design

**Date:** 2026-04-08
**Status:** approved

## Problem

Some skills (e.g. `test-stories`, `quality-loop`, `nightshift`) spawn their own subagents. When such a skill is itself invoked from inside a subagent, nested-subagent limits and main-loop context bloat become problems. We need a way to run a slash command in a **fresh `claude -p` process** so it owns its own context and its own subagent budget.

## Goal

A generic utility skill, `/run-detached`, that:

1. Takes any slash command + args as input.
2. Spawns a fresh `claude -p` process running that command with `--dangerously-skip-permissions`.
3. Waits for it to finish (arbitrary duration — may run hours).
4. Returns raw stdout + log path + exit status to its caller.

Caller is expected to be a **disposable Agent subagent**, not the main loop. That keeps the heavy waiting/polling out of main context.

## Non-goals

- No multi-run registry, no resume, no queueing.
- No streaming to main loop. One shot in, one summary out.
- Not a replacement for the `Agent` tool. Only use when the child skill itself spawns subagents.

## Topology

```
main loop
  └─ Agent subagent (disposable)
       └─ /run-detached /test-stories <args>
            └─ claude -p (fresh process — owns its context + subagents)
```

Main loop spawns an Agent with a prompt like: *"Run `/test-stories <args>` via `/run-detached` and return the final report."* The subagent invokes the skill, polls, returns summary.

## Inputs

- `$ARGUMENTS` = the full slash command + args the child should execute (e.g. `/test-stories TS-001 TS-002`).

## Execution — tmux only

Single mode. No bash background fallback.

1. Generate run id: `YYYYMMDD-HHMMSS-<slug>`. Session name: `claude-run-<id>`.
2. `mkdir -p .tmp/claude-runs/<id>`
3. `tmux new-session -d -s claude-run-<id> -c "$PWD" 'claude -p "<ARGUMENTS>" --dangerously-skip-permissions 2>&1 | tee .tmp/claude-runs/<id>/output.log; exit'`
4. Verify with `tmux has-session`. Abort if it failed to come up.
5. Poll every ~30s: `tmux has-session -t claude-run-<id>` → exits 1 when child finished.
6. Read log, return tail + path + heuristic exit status + session name.

### Why tmux-only

- Survives the polling subagent being killed. Session keeps running; a new subagent could in theory reattach via log file.
- Listed automatically in `claude-wormhole` (wormhole's `listSessionsWithInfo` in `src/lib/tmux.ts` calls `tmux list-sessions` with no filter).
- User can `tmux attach -r -t claude-run-<id>` or open wormhole any time to watch live.
- Plays nicely with existing `cld.sh` workflow.
- `tmux` is already a hard dep of the user's workflow (wormhole + cld.sh both require it), so assuming availability is safe.

### Exit status caveat

`tmux` does not surface the child's exit code after the session ends. We use a heuristic: scan the log tail for error markers (`Error:`, `Traceback`, `permission denied`, etc.). Caller should read the log itself if certainty matters.

## Polling

- Interval: 30s.
- Sanity cap: 4h. After cap, kill child (`KillShell` or `tmux kill-session`), return timeout error.
- Between polls, subagent should not do other work — just wait and poll.

## Outputs returned to caller subagent

```
run_id: <id>
session_name: claude-run-<id>
log_path: .tmp/claude-runs/<id>/output.log
attach_cmd: tmux attach -r -t claude-run-<id>
exit_status: 0|error|timeout
output_tail: |
  <last ~4KB of log>
```

The subagent's return message to main loop is whatever summary main asked for, synthesized from `output_tail` (or full log if it reads it).

## Failure modes

| Failure | Handling |
|---|---|
| Child errors (heuristic) | Return `exit_status=error` + log tail. No retry. |
| Log file missing | Return error `log-missing`. |
| Poll loop hits 4h cap | `tmux kill-session`, return `timeout`. |
| tmux not installed | Abort with clear error. No fallback. |
| Session fails to start | Abort, return stderr. |

## Files

- `run-detached/SKILL.md` — skill entry point. Frontmatter + step-by-step instructions for the subagent invoking it.
- Runtime: `.tmp/claude-runs/<id>/output.log` (gitignored via existing `.tmp/` rule).

## Caveats

- `--dangerously-skip-permissions` means the child process has full tool access. Only use when you trust the slash command being run.
- Child inherits cwd from the skill invocation. Document this.
- Child has its own token budget and cost. Running many detached children in parallel can get expensive.
- No live progress streaming back to main loop. Users wanting live view `tmux attach -r -t <session>` or open claude-wormhole.
- Exit status is heuristic (log scan). Callers needing certainty should read the log themselves.
