---
name: subagent-first
description: "Use at the start of any multi-step task, and before running any Bash/Grep/Read that could be delegated. Keeps main-agent context clean by routing real work (exploration, commands, MCP calls, review, browser, research) to specialized subagents. Triggers: subagent-first, delegate, keep context clean, offload, orchestrator mode"
---

# Subagent-First Policy

Main agent = thin orchestrator. Real work = subagents. **Default: delegate.**

Every token spent in main is a token you don't have for the final answer. Subagents give you the result without the raw noise.

## Decision Tree

### ALWAYS delegate (never run in main)

| Task | Subagent |
|------|----------|
| Any Bash >20 lines output (build/test/lint, find, grep pipeline, log tail, curl dump) | `execute` |
| Multi-file exploration ("where is X used", "how does Y work", unfamiliar codebase) | `Explore` (quick/medium/very thorough) |
| MCP calls w/ large payloads (GA, GSC, Slack search, playwright, ahrefs) | `mcp-fetch` |
| Code review on any dimension (security, perf, arch, dead-code, error-handling, etc.) | matching `review/*` agent or `team-review` |
| Browser automation, QA flows, dogfooding | `dogfood` skill / `test-stories` / `agent-browser` |
| Bug investigation w/ ≥2 competing hypotheses | `team-debug` |
| Research spanning docs + code + git history | `team-research` |
| Feature planning requiring deep codebase understanding | `feature-dev:code-architect` |

### Main agent only does

- Read 1–3 *known* files (not fishing)
- Edit/Write to those files
- Cheap git: `status`, `log -5`, `diff --stat`, `rev-parse`, `branch --show-current`
- Compose final user-facing answer
- Spawn subagents + synthesize their output into decisions
- Ask clarifying questions

### Red Flags — if you catch yourself, stop and delegate

| Thought | Delegate to |
|---------|-------------|
| "Let me grep for…" | `Explore` |
| "Let me run the build / tests / lint…" | `execute` |
| "Let me check that Slack channel / GA dashboard…" | `mcp-fetch` |
| Reading 5+ files to understand a system | `Explore` |
| Running `rg`, `find`, `jq`, `awk`, `curl` pipelines | `execute` |
| Comparing multiple approaches/hypotheses | `team-debug` or `team-research` |
| Reviewing >100 lines of code | matching `review/*` agent |
| Writing a test plan for a feature | `testing` agent |

## Prompt Discipline for Subagents

Since subagents run cold, give them enough to judge:

- **What**: one-line goal
- **Why**: context — what the result will be used for
- **Success criteria**: what "done" looks like
- **Length cap**: e.g., "report under 200 words"
- **Hand over exact commands for lookups**; hand over the *question* for investigations

Bad prompt: `"check the build"` → generic noise back.
Good prompt: `"Run npm test, report only failing tests + first line of each error. Under 150 words."`

## Parallelism

Independent delegations = single message with multiple Agent calls. Never serialize independent work.

## When to Break the Rule

- **Trivial one-liners** (`git status`, `pwd`, `ls`, reading one known config) — just run.
- **Interactive back-and-forth with user** — don't delegate the conversation itself.
- **Synthesis step** — main agent does the thinking once subagents return.

## Anti-Patterns

- **Serial subagent chain**: spawning A, waiting, spawning B based on A's output, when A+B were independent. Parallelize.
- **Over-delegation of trivia**: spawning an agent for `cat one-file.json`. Main agent handles this.
- **Under-specified prompt**: "investigate X" with no context. Agent returns vague result → you re-spawn. One good prompt > three bad ones.
- **Ignoring the output cap**: subagent returns 5K tokens of raw tool output → you just moved the noise. Tell it to summarize, give a word limit.

## Checklist Before Any Action

1. Is this >20 lines of output? → delegate.
2. Does this need >3 Read or >2 Grep? → delegate.
3. Am I about to read code I don't know? → delegate.
4. Am I running a build/test/lint? → delegate.
5. Am I calling an MCP that returns lots of data? → delegate.

If any yes → spawn subagent. If all no → proceed in main.
