# Expert Panel (Dilemma Resolution)

When you (the orchestrator) encounter ANY of these situations, do NOT guess. Convene a 3-agent expert panel.

## When to convene

- **Ambiguous requirements** — issue is unclear about expected behavior
- **Multiple valid approaches** — 2+ reasonable ways to implement something
- **Conflicting reviewer feedback** — two reviewers disagree on direction
- **Unexpected codebase state** — code doesn't match what the issue assumes
- **Scope uncertainty** — unclear if something is in or out of scope
- **Test strategy dilemma** — unit vs integration vs e2e, what to mock
- **Architecture fork** — where to put code, which pattern to use
- **Dependency question** — add a library vs build from scratch
- **Root cause ambiguity** — multiple possible causes for a bug, evidence doesn't converge
- **ANY moment of confusion** — if you'd normally ask the human, ask the panel instead

## How to convene

Spawn 3 expert agents in parallel (all in one message, `model: "opus"` — experts need best reasoning). Each expert gets the SAME context — keep it focused, include only what's needed for the decision:

```
You are an expert consultant for an autonomous development pipeline.
The orchestrator is confused and needs your decision.

CONTEXT:
<paste the dilemma, relevant code snippets, issue details, reviewer feedback>

QUESTION:
<the specific question needing a decision>

OPTIONS (if known):
A) <option A>
B) <option B>
C) <option C — or "suggest your own">

Give your recommendation as:
DECISION: <A, B, or C>
REASONING: <2-3 sentences why>
CONFIDENCE: <high|medium|low>
RISK: <what could go wrong with your choice>

At the very end of your response, output this line for the orchestrator:
DECISION: <A|B|C> | CONFIDENCE: <high|medium|low> | REASON: <10 words>
```

## Expert panel composition

Pick 3 based on the dilemma type:

| Dilemma Type | Expert 1 | Expert 2 | Expert 3 |
|-------------|----------|----------|----------|
| Architecture/design | `architecture` | `performance` | `security` |
| Testing strategy | `testing` | `architecture` | `code-standards` |
| Code approach | `code-standards` | `architecture` | `performance` |
| Security concern | `security` | `architecture` | `error-handling` |
| Scope/requirements | `architecture` | `testing` | `code-standards` |
| Bug root cause | `architecture` | `error-handling` | `testing` |
| Default (anything) | `architecture` | `security` | `code-standards` |

## Decision rule

- **2/3 agree** → follow the majority decision. Log the decision and reasoning.
- **3-way split** → follow the expert with highest stated confidence. If tied, go with `architecture` expert.
- **All low confidence** → pick the most conservative/reversible option.

## Logging

Write every expert panel decision to `.claude/nightshift/issue-<N>/decisions.md`:

```markdown
## Decision #1 — <timestamp>
**Dilemma:** <what was unclear>
**Expert 1 (architecture):** DECISION: A — <reasoning>
**Expert 2 (security):** DECISION: A — <reasoning>
**Expert 3 (code-standards):** DECISION: B — <reasoning>
**Result:** A (2/3 majority)
**Applied at:** Step <N>, attempt <M>
```

**Also post the decision as a comment on the GitHub issue** (Rule 3).
