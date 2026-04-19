---
name: subagent-first
description: "Best-effort guidance: prefer delegating exploration, long-running commands, MCP calls, reviews, and research to specialized subagents to keep main-agent context clean. Heuristic, not a hard rule — use judgment. Triggers: subagent-first, delegate, keep context clean, offload, orchestrator mode, orchestrate"
---

# Subagent-First (Best-Effort)

**Heuristic, not law.** Delegate reads whose output is an answer. Keep reads whose output is the file itself (needed for precise edits).

## When Delegation Pays Off

| Situation | Likely subagent |
|------|----------|
| Bash spewing >20 lines (build, test, lint, grep, curl) | `commands/execute` |
| Exploring unfamiliar code — "where is X?", "how does Y work?" | `Explore` |
| MCP call returning large payload (GA, GSC, Slack, playwright) | `mcp-fetch` |
| Code review on any dimension | `review/*` or `team-review` |
| Browser automation, QA, dogfooding | `dogfood` / `test-stories` / `agent-browser` |
| Bug investigation with ≥2 hypotheses | `team-debug` |
| Research spanning docs + code + git | `team-research` |
| Feature planning needing deep codebase understanding | `feature-dev:code-architect` |

Soft triggers: "Let me grep across repo…", "Let me run build/tests…", "Let me check Slack/GA/GSC…", `rg`/`find`/`jq`/`curl` pipelines with large output, comparing multiple approaches.

## When Main Agent Should Just Do It

- Reading file you're about to **edit** — Edit needs exact strings
- Reading 1–3 files already touched this session
- Cheap git ops: `status`, `log -5`, `diff --stat`, `rev-parse`, `branch --show-current`
- Trivial one-liners: `pwd`, `ls`, single-file read
- Interactive back-and-forth with user
- Synthesis of subagent output
- Inside another subagent (don't recurse)

## Skip This Policy Entirely

- Already running as subagent
- Inside skills with own orchestration (`nightshift`, `quality-loop`, `test-stories`)
- User explicitly asks inline
- Emergency/time-critical fixes
- Simple single-file changes

## Prompt Discipline (When Delegating)

Brief subagents like new colleague:
- **What**: one-line goal
- **Why**: what result is used for
- **Success criteria**: what "done" looks like
- **Length cap**: e.g., "under 200 words"
- Lookup tasks → exact commands. Investigations → hand over question, not steps.

Bad: `"check the build"` → generic noise.
Good: `"Run npm test, report only failing tests + first error line. Under 150 words."`

Independent delegations → parallel Agent calls in single message.

## Anti-Patterns

- **Over-delegating trivia.** `cat one-file.json` → just do it.
- **Serial when parallel works.** Independent tasks → single message.
- **Vague prompts.** "investigate X" no context → vague result → re-spawn.
- **Dumping raw output.** Always request summary with length cap.
- **Delegating edits.** Subagent can't Edit precisely without content in main context.
