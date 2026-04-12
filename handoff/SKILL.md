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

## Save Mode (`/handoff` or `/handoff save`)

### When to Use
- Conversation getting long, user wants `/clear` without losing progress
- User says: "handoff", "save state", "compress context", "handoff save"

### Steps

1. **Ensure `./.tmp/handoff/` exists.** Create if missing. Verify `.tmp` in `.gitignore`.

2. **Generate timestamp** via `date +%Y%m%d-%H%M%S`.

3. **Select load-bearing content only:**
   - **Goal** — what user is trying to do
   - **State** — done / wip / next
   - **Decisions** — locked choices + brief why
   - **Files** — paths + one-line purpose
   - **Open** — blockers, questions, things to verify
   - **Background** — running processes (PIDs, tmux sessions), active loops/schedules, monitoring with thresholds/kill conditions
   - **Env** — branch, servers, key state
   - **Exclude**: chit-chat, dead ends, framework details, re-derivable info

4. **Compress to caveman format.** Drop articles, use symbols (`→ = & w/`), abbreviate. Include enough detail that resume mode can start working without re-exploring the codebase.

5. **Write** to `./.tmp/handoff/context-<timestamp>.md`. **Symlink as latest:**
   ```bash
   ln -sf context-<timestamp>.md ./.tmp/handoff/context-latest.md
   ```

6. **Estimate compression.** Rough token estimate: `words * 1.3`. Report:
   ```
   Compressed: ~<session_tokens> → ~<handoff_tokens> tokens (<ratio>% reduction)
   ```

7. **Copy to clipboard:**
   ```bash
   printf '%s' "/handoff resume" | pbcopy
   ```

8. **Output:**
   ```
   Handoff saved: .tmp/handoff/context-<timestamp>.md
   Compressed: ~150K → ~600 tokens (99.6% reduction)
   Now run /clear, then paste to resume.
   ```
   Stop. Do not continue the original task.

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

## Load Mode (`/handoff resume`)

### When to Use
- After `/clear`, user pastes `/handoff resume`
- User says: "handoff resume", "handoff load", "handoff continue"

### Steps

1. **Read the handoff file into context.** Use Read tool on `./.tmp/handoff/context-latest.md`. If missing, find latest:
   ```bash
   ls -t .tmp/handoff/context-*.md | grep -v latest | head -1
   ```
   The file MUST be loaded in full — it IS the context for this session.

2. **Announce resume** — one-line summary:
   ```
   Resumed from ctx-<timestamp>. Goal: <goal>. Next: <next items>.
   ```

3. **Jump to work immediately** on STATE.wip or STATE.next items. Don't ask "what should I do?" — the handoff file already says what's next.

### Resume Priority
- OPEN blockers → address first
- STATE.wip → continue
- STATE.next → start first item
- Everything done → tell user, ask what's next

---

## Common Mistakes

- **Over-including in save.** Load-bearing only. Size should match complexity — simple task ~300 tokens, complex multi-day work ~800 tokens.
- **Skipping symlink.** `context-latest.md` enables fast resume without glob.
- **Asking user what to do on resume.** Handoff has NEXT items. Start.
- **Continuing task after save.** Stop — next session takes over.
