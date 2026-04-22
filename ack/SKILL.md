---
name: ack
description: "Use when user invokes /ack, or when request is ambiguous, destructive, multi-file, or high-blast-radius. Triggers: ack, acknowledge, confirm first, check before doing, restate, dry run, plan then ask."
---

# Ack (Acknowledge Before Execute)

Restate intent. Get `y`. Then act. Prevents misinterpretation on ambiguous / high-blast-radius requests.

## Flow

1. Parse intent — what, where, scope, side effects
2. Rephrase in 1-3 bullets
3. Ask
4. Wait — no tool calls
5. Execute only after green light
6. Scope change (before OR during) → restart at step 2

## Format

```
Understood:
- [action] [target]
- [scope/constraint]
- [side effect]

Proceed? (y/yes/go/proceed = go | anything else = edit/abort)
```

## Rules

**Pre-confirm tool calls — banned by default.**

Whitelist (only if strictly needed to rephrase):
- `ls` — cwd or user-named dir only. No `ls ~/.ssh`, no `ls /etc`.
- `git status`, `git log` (no args)
- `Read` — only if exact filename/path appears verbatim in user message. Noun ≠ filename. "Refactor auth module" ≠ permission to read `src/auth/*`.

Everything else banned: Grep, Glob, Bash writes, Edit, Write, WebFetch, MCP, subagents.

Whitelist insufficient → ask clarifying question. Not explore.

**Green light:** `y`, `yes`, `go`, `do it`, `proceed`, `ship it`, `lgtm`. Nothing else. No emoji, no silence, no tangent.

**Tweak:** user correction / "actually X" / "also Y" → update rephrase, re-ask.

**Scope drift:** approval = exact bullets only. Mid-task new work → STOP, restart step 2. No silent expansion.

**New request mid-session:** new ack cycle, unless user said "skip acks".

## When

Use: `/ack` invoked, destructive ops, multi-file edits, vague scope, cross-repo / shared state.

Skip: single read on user-named file, explicit numbered plan, inside upstream-approved loop (test-stories, devloop).

## Rationalization Table

| Excuse | Reality |
|---|---|
| "Intent obvious, skip ack" | Skill invoked = user wanted gate. Ack. |
| "Small change" | Size not gate. Scope clarity is. |
| "Need explore to rephrase" | Ask clarifying question. Exploration = tool calls. |
| "User said 'just do it' earlier" | Approved previous scope. New request = new ack. |
| "Already read file for context" | If not on whitelist, was violation. Don't compound. |
| "Read-only, harmless" | Burns tokens + context. Whitelist or question. |
| "User will correct if wrong" | Ack prevents wrong work, not detects it. |
| "Scope grew only little" | Any growth = re-ack. No exceptions. |
| "Auth module named = can read auth files" | Named = exact literal in message. Noun ≠ file. |

## Red Flags — STOP

- Non-whitelisted tool call before `y`
- Rephrase with "and maybe also..." → ask instead
- Silent mid-task scope expansion
- Emoji / thumbs-up / "sure" treated as green light
- Skipping rephrase because "trivial"
