---
name: handoff
description: "Context handoff across /clear boundaries. Three steps: (1) /handoff or /handoff save — compress conversation to .tmp/handoff/. (2) user runs /clear. (3) /handoff resume — read latest handoff, auto-start next items. Triggers: handoff, handoff save, handoff start, handoff compress, handoff resume, handoff load, handoff continue"
---

# Handoff

3-step context continuity: **save → clear → load**.

## Mode Detection

- Args contain `resume`, `load`, or `continue` → **Load mode**
- Everything else → **Save mode**
- `/clear` is manual (step 2) — no automation exists yet (anthropics/claude-code#35150)

---

## Save Mode

1. Ensure `./.tmp/handoff/` exists. Verify `.tmp` in `.gitignore`.

2. `date +%Y%m%d-%H%M%S` → timestamp.

3. Extract load-bearing content only:
   - **Goal** — what user is doing
   - **State** — done / wip / next
   - **Decisions** — locked choices + brief why
   - **Files** — paths + one-line purpose
   - **Open** — blockers, questions, things to verify
   - **Background** — running processes (PIDs, tmux), active loops/schedules, monitoring w/ thresholds/kill conditions
   - **Env** — branch, servers, key state
   - **Exclude**: chit-chat, dead ends, framework details, re-derivable info

4. Compress to caveman format. Drop articles, use symbols (`→ = & w/`). Include enough detail for resume to start working without re-exploring codebase.

5. Write to `./.tmp/handoff/context-<timestamp>.md`. Symlink:
   ```bash
   ln -sf context-<timestamp>.md ./.tmp/handoff/context-latest.md
   ```

6. Estimate compression. `words * 1.3` ≈ tokens. Report ratio.

7. Copy to clipboard:
   ```bash
   printf '%s' "/handoff resume" | pbcopy
   ```

8. Output:
   ```
   Handoff saved: .tmp/handoff/context-<timestamp>.md
   Compressed: ~150K → ~600 tokens (99.6% reduction)
   Now run /clear, then paste to resume.
   ```
   Stop. Do not continue original task.

Size should match complexity — simple task ~300 tokens, complex multi-day ~800 tokens. Never skip symlink.

### Template

```markdown
# ctx-<timestamp>

GOAL: <one line>

STATE:
- done: ...
- wip: ...
- next: ...

DECISIONS:
- X → Y (why: ...)

FILES:
- path/to/file = purpose

OPEN:
- question / blocker

BACKGROUND:
- runner PID <pid>, tmux session <name>, what it's doing
- /loop or ScheduleWakeup: prompt, interval, purpose
- monitoring: what to watch, thresholds, kill conditions
- cron/scheduled agents: task, schedule, status
(omit section if nothing running)

ENV:
- branch, servers, state
```

---

## Load Mode

1. Read `./.tmp/handoff/context-latest.md` in full. If missing:
   ```bash
   ls -t .tmp/handoff/context-*.md | grep -v latest | head -1
   ```

2. Announce: `Resumed from ctx-<timestamp>. Goal: <goal>. Next: <next items>.`

3. Jump to work immediately. Don't ask "what should I do?" — handoff says what's next.

### Resume Priority
- OPEN blockers → first
- STATE.wip → continue
- STATE.next → start
- Everything done → tell user, ask what's next
