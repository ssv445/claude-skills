---
name: offload-grunt-work
description: Use when about to do context-heavy grunt work that is not Claude-specific — web research, reading vendor/API/upstream docs, triaging a large log, parsing a PDF/CSV/statement, bulk-classifying a list, recon in an unfamiliar repo, or an independent second-opinion review. Triggers whenever a task's input is far larger than its useful output.
---

# Offload grunt work to codex / agy

Where `codex` and `agy` are installed alongside Claude Code, both are fully agentic (file access, sandbox modes, structured output) and their context is **not** this session's context. Work sent there costs zero tokens here, and zero Claude quota.

Check availability once with `command -v codex agy`; skip this skill if neither is present.

## Core test

**Compression ratio.** If the input is much larger than the useful output, offload it.
Reading 20 web pages to write one paragraph → offload. Editing one file → don't.

## Lanes — pick one

Every lane except the last keeps the work out of this context. The choice is **capability vs. quota**.

| Task needs… | Lane | Model |
|---|---|---|
| Repo conventions, DB writes, MCP servers, project skills, judgment about the user's data | **Claude subagent** | Haiku if purely mechanical · Sonnet if it needs care · Opus/Fable only to plan, review, or think |
| Nothing but a big pile of text and a clear question | **codex / agy** ← this skill | — |
| My own reasoning thread, or a taste call | **me** | — |

**Pick the cheapest thing that can be right.** Counting, grepping, running tests, reformatting, checking a file exists → Haiku. Do not send a low-IQ task to Opus because it was the default.

A Claude subagent still spends Claude quota; `codex`/`agy` spend none. So when a task is context-free *and* the queue is heavy, prefer codex/agy even if a Haiku subagent could do it.

## Route

| Work | Tool |
|---|---|
| Web research, "what's known about X", fact-checking | `agy` |
| Vendor / API / upstream docs before an integration | `agy` |
| Bulk classification, extraction to a fixed shape | `agy --json-schema` |
| Log triage, error-class rollup | either |
| PDF / CSV / statement → JSON | either |
| Recon in an unfamiliar repo ("map how auth works here") | `codex` |
| Independent review / design critique | `codex` (no shared context is the point) |

## Commands

All verified working 2026-08-07. `$S` = a scratch dir outside the repo.

```bash
# research — bump the timeout, default is 5m and research blows past it
agy --sandbox --dangerously-skip-permissions \
    --model "Gemini 3.1 Pro (High)" --print-timeout 20m -p "…" > "$S/out.md"

# structured extraction — object lands in .structured_output
agy --sandbox --dangerously-skip-permissions \
    --output-format json --json-schema schema.json -p "…" > "$S/out.json"

# repo recon / review — read-only, rooted at the target, clean output via -o
codex exec -s read-only -C /path/to/repo -o "$S/out.md" "…"

# design critique
codex exec -m gpt-5.6-sol -c model_reasoning_effort="xhigh" -o "$S/out.md" "…"
```

`--dangerously-skip-permissions` is safe *here* because `--sandbox` already restricts the terminal — it only stops headless agy from auto-denying its own tools and returning nothing.

**`agy -p` must come last** — it is a string flag and swallows whatever follows it as the prompt. `agy -p --sandbox "question"` silently answers about `--sandbox`. Full agy mechanics: `agy` skill.

**`codex -o FILE`** writes just the final message. Plain stdout redirect also captures the provider/session/token preamble.

## Rules

1. **Always sandboxed** — `codex -s read-only`, `agy --sandbox`. They never write to a repo, a DB, or a person.
2. **Redirect to a scratchpad file, then read what you need.** Piping straight to stdout dumps their whole answer into this context and defeats the purpose.
3. **Ask for a bounded answer** — "under 300 words", "JSON only", "just the table". An unbounded prompt returns an essay.
4. **Long jobs go `run_in_background`** so nothing blocks.
5. **Their output is a claim, not a fact.** Before acting on a number, date, version, or API signature they produced, verify it by an independent path — the actual file, the actual DB, the actual `--help`. Cheap to check, expensive to be wrong.
6. **Never offload something you cannot cheaply verify.** A wrong answer you can't spot-check costs more than the context it saved.

## Never offload

- Writes of any kind — files, DB, git, outbound messages
- MCP-bound work (their client isn't mine)
- Anything requiring the repo's conventions to be correct
- Decisions that belong to the user

## Common mistakes

| Mistake | Fix |
|---|---|
| Offloaded, then pasted the answer through unchecked | Rule 5 — verify by an independent path |
| Answer landed in context anyway | Redirect to a file (rule 2) |
| `agy -p` returned nothing after 5 minutes | Default `--print-timeout` is 5m. Raise it. |
| agy answered a different question, confidently | A flag followed `-p`. Move `-p "<prompt>"` to the end. |
| agy exited 0 with empty output | Headless auto-denied a tool. Add `--sandbox --dangerously-skip-permissions`. |
| Sent a counting/grepping task to Opus | Haiku subagent. Match the tier to the task. |
| Sent it to `codex`/`agy` and it needed project conventions | Wrong lane — that's a Claude subagent |
| Did the research inline "because it's quick" | Quick research is still 30k tokens of pages. Offload it. |
