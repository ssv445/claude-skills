---
name: rca
description: "Use when user invokes /rca or needs root cause analysis on a bug, outage, metric drop, churn spike, funnel leak, or any unexplained problem. Runs 5 fresh-subagent rounds with mandatory adversarial review, accumulates findings in a persistent file, ends with 2-3 ranked theories. Triggers: rca, root cause, why did X happen, what broke, diagnose, postmortem, 5 whys."
---

# RCA (Root Cause Analysis)

Dig 5 rounds. Fresh subagent each round. Adversarial review mandatory. End with 2-3 ranked theories.

**Domain-agnostic** — works for code bugs, traffic drops, churn, funnel leaks, metric regressions, outages.

## Input

```
/rca <description of the problem>
```

If no description provided, ask one question: "What problem are we analyzing?" — no guessing.

## File

Create `.tmp/rca/rca-<YYYYMMDD-HHMMSS>.md` with header:

```markdown
# RCA: <short title>

**Started:** <ISO timestamp>
**Problem:** <user description>
**Evidence provided:** <paste any links/logs/data user shared>
**Status:** investigating
```

Then append one `## Round N` section per round. Do NOT let main agent rewrite file — only append.

## Round Themes (fixed)

| Round | Theme | Focus |
|---|---|---|
| 1 | **Surface** | What exactly happened? What's the evidence? When did it start? |
| 2 | **Mechanism** | How does this symptom happen? Trace the causal chain. |
| 3 | **Challenge** | Adversarial — attack every assumption from rounds 1-2. What if the evidence is misleading? |
| 4 | **Alternatives** | What else could cause this? List all plausible alternate explanations. |
| 5 | **Synthesize** | Consolidate findings → 2-3 ranked root cause theories. |

## Execution Loop (main agent)

For each round 1→5:

1. Dispatch **one** `team-debug` subagent (fresh context) with this prompt template:

```
You are the RCA round <N> runner. Theme: <theme from table>.

Read the full file: .tmp/rca/rca-<ts>.md (all prior rounds included).

Dispatch 3 parallel reviewer sub-agents:
  - Investigator (focus on this round's theme)
  - Adversarial (attack assumptions, find contradicting evidence) — MANDATORY
  - <task-appropriate third agent> (e.g., data-check / code-tracer / metric-analyst)

Consolidate their findings.

Append to the rca file exactly this section (no other edits):

## Round <N>: <theme>
**Agents:** <list>

### Findings
- <bullet>

### Contradictions with prior rounds
- <bullet or "none">

### Open questions
- <bullet>

Keep each bullet <2 lines. No prose paragraphs.
```

2. Main agent does NOT read subagent output — just confirms it appended.

3. After round 5 (synthesis theme), subagent appends this structure instead:

```
## Round 5: Theory Synthesis
**Agents:** <list>

### Theory 1 (highest evidence)
- **Hypothesis:** <one sentence>
- **Evidence for:** <bullets>
- **Evidence against:** <bullets>
- **Verification test:** <concrete check the user can run>

### Theory 2
...

### Theory 3 (if warranted)
...

### Status: complete
```

## Final Output (main agent)

After round 5:
1. Read only the `## Round 5` section from the file
2. Report to user:
   - File path
   - 2-3 theories (hypothesis + verification test only; full evidence in file)

Do NOT summarize rounds 1-4 back to user — they're in the file for audit.

## Rules

- **5 rounds exactly.** No early exit, no extra rounds. User can re-invoke for follow-up.
- **Fresh subagent per round.** No context reuse — each subagent reads only the rca file.
- **Adversarial always.** Every round dispatches an adversarial reviewer.
- **Append-only file.** No rewrites, no reordering.
- **Main context stays clean.** Main agent never does investigation itself.

## When NOT to Use

- Obvious single-cause bug (stack trace points at line X) — just fix it
- No evidence available yet — gather data first, then RCA
- Time-critical incident — use quick debugging, RCA is for post-hoc depth

## Red Flags — STOP

- Main agent starting investigation in its own context → dispatch subagent instead
- Skipping adversarial review "because findings are clear" → always run
- Rewriting earlier rounds → append only
- Running <5 or >5 rounds → exactly 5
