---
name: handoff-context
description: Use when the user wants to shorten/compress/handoff conversation context to continue fresh — writes a caveman-compressed summary to ./.tmp/ and puts a kickoff line on the clipboard, then reminds to /clear
---

# Handoff Context

## Overview
Compress the current conversation into a minimal handoff artifact so work can resume in a fresh session without re-exploration. Uses caveman-distillate compression, writes to `./.tmp/` in the current working directory, and puts a one-line kickoff message on the clipboard.

## When to Use
- User says: "handoff", "shorten context", "compress context", "save state", "continue fresh", "hand off"
- Conversation is getting long and the user wants to `/clear` without losing progress
- Switching from research/exploration phase into a fresh implementation phase

**Do NOT use** for short conversations where `/clear` alone would lose nothing.

## Steps

1. **Ensure `./.tmp/` exists** in the current working directory. Create it if missing. Check `.gitignore` — if `.tmp/` is not already ignored, add it (one line, separate commit if the repo is clean).

2. **Generate timestamp** via `date +%Y%m%d-%H%M%S` → e.g. `20260407-143022`.

3. **Select load-bearing content only.** Include ONLY what the next session needs to continue the work:
   - **Goal** — what the user is ultimately trying to do
   - **State** — done / in-progress / next
   - **Decisions** — choices locked in, with a brief *why*
   - **Files** — paths touched + one-line purpose each
   - **Open** — unresolved questions, blockers, things to verify
   - **Exclude**: chit-chat, abandoned dead ends, obvious framework details, anything re-derivable from the code

4. **Compress to caveman format.** Apply the `caveman-distillate` skill's rules (invoke it via the Skill tool if the rules aren't already active in context). Target ~65% token reduction vs. normal prose: drop articles, use symbols (`→ = & w/`), abbreviate, keep semantic content only.

5. **Write the file** to `./.tmp/context-<timestamp>.md` using the template below.

6. **Copy kickoff to clipboard** (macOS):
   ```bash
   printf '%s' "Read ./.tmp/context-<timestamp>.md and continue." | pbcopy
   ```
   Linux fallback: `xclip -selection clipboard` or `wl-copy`.

7. **Remind the user to clear.** Output a short message like:
   ```
   Handoff: .tmp/context-20260407-143022.md
   Clipboard ready. Run /clear, then paste to resume.
   ```
   Stop there. Do not continue the original task in this session.

## Output Template

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
- path/to/file.ts = <purpose>

OPEN:
- <question / blocker / thing to verify>
```

## Common Mistakes

- **Over-including.** Dumping the full conversation defeats the purpose. Load-bearing only.
- **Skipping `.gitignore` check.** `.tmp/` leaking into commits is the #1 failure mode.
- **Skipping the clipboard step.** The whole point is zero-friction paste after `/clear`.
- **Continuing the task after handoff.** Once the file + clipboard are ready, stop — the next session takes over.
- **Using `pbcopy` on non-macOS.** Detect platform or fall back gracefully.
