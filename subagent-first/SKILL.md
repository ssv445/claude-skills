---
name: subagent-first
description: "Best-effort guidance: prefer delegating exploration, long-running commands, MCP calls, reviews, and research to specialized subagents to keep main-agent context clean. Heuristic, not a hard rule — use judgment. Triggers: subagent-first, delegate, keep context clean, offload, orchestrator mode, orchestrate"
---

# Subagent-First (Best-Effort Guidance)

**Heuristic, not law.** Prefer delegation when the goal is to reduce noise in main. Skip when following the rule would hurt more than help.

Main guiding idea: **delegate reads whose output is an answer. Keep reads whose output is the file itself.** Subagents give you signal; they can't replace context you need for precise edits.

## When Delegation Usually Pays Off

Not a "must" — a nudge. If any of these match, consider spawning a subagent:

| Situation | Likely subagent |
|------|----------|
| Bash command expected to spew >20 lines (build, test, lint, long find/grep, log tail, curl dump) | `commands/execute` |
| Exploring unfamiliar code — "where is X used?", "how does Y work?" | `Explore` |
| MCP call that returns large payload (GA, GSC, Slack search, playwright, ahrefs) | `mcp-fetch` |
| Dedicated code-review task on any dimension | matching `review/*` agent or `team-review` |
| Browser automation, QA flows, dogfooding | `dogfood` / `test-stories` / `agent-browser` |
| Bug investigation with ≥2 competing hypotheses | `team-debug` |
| Research spanning docs + code + git history | `team-research` |
| Feature planning needing deep codebase understanding | `feature-dev:code-architect` |

## When Main Agent Should Just Do It

Delegating these usually costs more than it saves:

- Reading a file you're about to **edit** — Edit tool needs exact strings, precision over context budget
- Reading 1–3 files you've already touched this session
- Cheap git ops: `status`, `log -5`, `diff --stat`, `rev-parse`, `branch --show-current`
- Trivial one-liners: `pwd`, `ls`, single-file `cat`, known-path reads
- Interactive back-and-forth with the user
- Synthesis — thinking about subagent output is the main agent's job
- Anything inside another subagent's execution (don't recurse this policy)

## Soft Red Flags

These are prompts to pause and ask "would a subagent serve better?" — not hard stops:

- "Let me grep across the repo for…" → often `Explore`
- "Let me run the build / tests / lint…" → often `commands/execute`
- "Let me check that Slack channel / GA dashboard / GSC…" → often `mcp-fetch`
- Reading to *find or understand* something (regardless of length) → often `Explore`
- `rg`, `find`, `jq`, `awk`, `curl` pipelines with large output → often `commands/execute`
- Comparing multiple approaches or hypotheses → often `team-debug` / `team-research`
- Dedicated code-review pass → often `review/*` agent

None of these are absolute. If the task is small, the context budget is fine, or delegation adds more friction than it saves — just do it.

## When to Skip This Policy Entirely

- Already running as a subagent (don't recurse)
- Inside skills that have their own orchestration (e.g., `nightshift`, `quality-loop`, `test-stories`) — follow that skill's pattern
- User explicitly asks to do it inline
- Emergency / time-critical fixes where subagent spin-up overhead hurts
- Simple, single-file changes that don't need exploration

## Prompt Discipline (When You Do Delegate)

Subagents run cold. Brief them like a new colleague:

- **What**: one-line goal
- **Why**: what the result will be used for
- **Success criteria**: what "done" looks like
- **Length cap**: e.g., "report under 200 words"
- **Lookup tasks** — hand over exact commands. **Investigations** — hand over the question, not prescribed steps.

Bad: `"check the build"` → generic noise back.
Good: `"Run npm test, report only failing tests + first line of each error. Under 150 words."`

## Parallelism

Independent delegations → single message with multiple Agent calls. Don't serialize work that has no dependency.

## Anti-Patterns (What Actually Goes Wrong)

- **Over-delegating trivia.** Spawning an agent for `cat one-file.json` wastes more time than it saves.
- **Serial chain where parallel would do.** A then B then C, when A/B/C are independent.
- **Vague prompts.** "investigate X" with no context → vague result → re-spawn. One good prompt > three bad ones.
- **Moving noise instead of removing it.** Subagent dumps 5K tokens of raw output back into main. Always ask for a summary with a length cap.
- **Delegating edits.** Subagent can't Edit a file precisely without the content being in the main agent's context. Keep edit-path reads in main.

## How to Judge in the Moment

Ask: *"Will the subagent's return value be smaller and more useful than the raw work would be in main?"*

- Yes → delegate.
- No (you need the raw content, e.g., for an edit) → don't.
- Unsure → try delegating; if it costs more than it saves, you've learned for next time.
