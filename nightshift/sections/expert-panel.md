# Expert Panel (Dilemma Resolution)

When you encounter ANY confusion, do NOT guess. Convene 3-agent expert panel.

## When to convene

- Ambiguous requirements
- Multiple valid approaches
- Conflicting reviewer feedback
- Unexpected codebase state
- Scope uncertainty
- Test strategy dilemma
- Architecture fork
- Dependency question (library vs build)
- Root cause ambiguity — evidence doesn't converge
- ANY confusion — if you'd ask the human, ask the panel

## How to convene

Spawn 3 experts in parallel (one message, `model: "opus"`). Each gets SAME focused context:

```
You are an expert consultant for an autonomous development pipeline.
The orchestrator is confused and needs your decision.

CONTEXT:
<dilemma, relevant code, issue details, reviewer feedback>

QUESTION:
<specific question needing decision>

OPTIONS (if known):
A) <option A>
B) <option B>
C) <option C — or "suggest your own">

Give your recommendation as:
DECISION: <A, B, or C>
REASONING: <2-3 sentences>
CONFIDENCE: <high|medium|low>
RISK: <what could go wrong>

At the very end of your response, output:
DECISION: <A|B|C> | CONFIDENCE: <high|medium|low> | REASON: <10 words>
```

## Panel composition

| Dilemma Type | Expert 1 | Expert 2 | Expert 3 |
|-------------|----------|----------|----------|
| Architecture/design | `architecture` | `performance` | `security` |
| Testing strategy | `testing` | `architecture` | `code-standards` |
| Code approach | `code-standards` | `architecture` | `performance` |
| Security concern | `security` | `architecture` | `error-handling` |
| Scope/requirements | `architecture` | `testing` | `code-standards` |
| Bug root cause | `architecture` | `error-handling` | `testing` |
| Default | `architecture` | `security` | `code-standards` |

## Decision rule

- **2/3 agree** → follow majority
- **3-way split** → highest confidence wins. Tied → `architecture` expert wins
- **All low confidence** → most conservative/reversible option

## Logging

Write to `.claude/nightshift/issue-<N>/decisions.md`:

```markdown
## Decision #1 — <timestamp>
**Dilemma:** <what was unclear>
**Expert 1 (architecture):** DECISION: A — <reasoning>
**Expert 2 (security):** DECISION: A — <reasoning>
**Expert 3 (code-standards):** DECISION: B — <reasoning>
**Result:** A (2/3 majority)
**Applied at:** Step <N>, attempt <M>
```

**Also post decision as issue comment (Rule 3).**
