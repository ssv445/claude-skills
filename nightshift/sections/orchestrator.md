# Orchestrator Pattern

## Model Strategy

**ALL agents use `model: "opus"`.** No exceptions, no tiering.

| Role | Model | Why |
|------|-------|-----|
| Orchestrator (you, main loop) | Opus 4.6 | Best reasoning for orchestration decisions |
| Worker agents (steps 1-6) | `model: "opus"` | Deep reasoning for investigation, implementation, tests |
| Reviewer agents (review gates) | `model: "opus"` | Best quality reviews catch more issues |
| Expert panel agents | `model: "opus"` | Critical decisions need best reasoning |
| Utility agents (comments, rate checks) | `model: "opus"` | Consistent quality across all agents |

## Thin Orchestrator Pattern (CRITICAL)

You (the orchestrator) are a **dispatcher**, not a doer. Your job: read 1-line summaries, update state, make proceed/retry/block decisions, dispatch next agent.

**NEVER do directly:**
- Read/write code files
- Run tests, lint, typecheck, build
- Explore the codebase
- Write artifact files (01-understand.md, etc.)
- Post detailed GitHub issue comments (delegate to subagent)
- Analyze agent outputs in detail

**ALWAYS delegate to subagents (all `model: "opus"`):**
- ALL 6 pipeline steps → worker subagent
- ALL review gates → reviewer subagents
- ALL expert panels → expert subagents
- GitHub issue commenting → utility subagent (formats and posts)
- Resume validation → validation subagent (reads state + checks git)
- Morning report generation → report subagent (reads artifacts, writes report, creates PR)

**State updates** — orchestrator does these directly (tiny, 1 bash call each).

## Agent Output Formats

Every subagent prompt MUST end with a required output format so the orchestrator only reads 1 line.

**Workers** end with:
```
At the very end of your response, output:
ORCHESTRATOR_SUMMARY: <1 sentence, max 20 words, describing outcome>
```

**Reviewers** end with:
```
At the very end of your response, output:
VERDICT: APPROVE | REJECT: <10 words max>
```

**Experts** end with:
```
At the very end of your response, output:
DECISION: <A|B|C> | CONFIDENCE: <high|medium|low> | REASON: <10 words>
```

## Orchestrator Context Rules

The orchestrator reads ONLY the summary/verdict/decision line from each agent result. Full output lives in artifact files (the agent wrote them).

| Item | Context cost | Keep in orchestrator? |
|------|-------------|----------------------|
| Issue number + title | ~10 tokens | Yes |
| Step summary (1 line) | ~20 tokens | Yes |
| Review verdict (1 line) | ~15 tokens | Yes |
| Full artifact content | 500-5000 tokens | NO — file path only |
| Full test output | 1000+ tokens | NO — in artifact file |
| Full review reasoning | 200-500 tokens | NO — verdict line only |
| State.json | ~200 tokens | Read fresh each time, don't cache |

**Target:** Orchestrator context for a 5-issue run should stay under 2000 tokens of accumulated state.

## General Agent Context Rules

- **Context efficiency:** Give each agent ONLY what it needs. Don't dump the entire issue history into every agent.
  - Workers get: the relevant step artifacts + issue number (they read the issue themselves)
  - Reviewers get: the step output file path + brief scope description
  - Experts get: the dilemma + relevant evidence only
- **Brevity:** All prompts, comments, and reports — short and dense. No filler words, no restating the obvious.
- **Issue comments:** Max 15 lines. Link to artifacts for details.

## Offloading Comments to Haiku Subagent

The orchestrator NEVER posts comments directly. Instead, dispatch a **subagent** (`model: "opus"`):

```
Post a GitHub issue comment for issue #<N>.
Step: <step_num>/<step_name>
Status: <passed|rejected|blocked>
Summary: <1 line from worker's ORCHESTRATOR_SUMMARY>
Reviewer verdicts: <arch=✓|security=✗(reason)|standards=✓> (or N/A for non-review steps)
Attempt: <M>/<MAX>
Branch: <branch_name>

Use the comment format (max 15 lines, dense, no fluff):
gh issue comment <N> --body "$(cat <<'COMMENT'
**Nightshift Step <STEP_NUM>/<STEP_NAME> — attempt <M>/<MAX> — <status>**
Branch: `<branch>`

**Done:** <summary>
**Evidence:** <key output or artifact ref>
**Reviewers:** <verdicts> → <result>
**Next:** <what happens next>
COMMENT
)"

ORCHESTRATOR_SUMMARY: Comment posted on issue #<N>
```
