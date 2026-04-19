# Orchestrator Pattern

## Model Strategy

**ALL agents use `model: "opus"`.** No exceptions.

## Thin Orchestrator (CRITICAL)

You are a **dispatcher**, not a doer. Read 1-line summaries, update state, make proceed/retry/block decisions, dispatch next agent.

**NEVER do directly:**
- Read/write code, run tests/lint/typecheck/build
- Explore codebase, write artifact files
- Post GitHub comments, analyze agent outputs in detail

**ALWAYS delegate (all `model: "opus"`):**
- Pipeline steps → worker subagent
- Review gates → reviewer subagents
- Expert panels → expert subagents
- GitHub commenting → utility subagent
- Resume validation → validation subagent
- Morning report → report subagent

**State updates** — orchestrator does directly (tiny, 1 bash call each).

## Agent Output Formats

Every subagent prompt MUST end with required output format.

**Workers:**
```
ORCHESTRATOR_SUMMARY: <1 sentence, max 20 words>
```

**Reviewers:**
```
VERDICT: APPROVE | REJECT: <10 words max>
```

**Experts:**
```
DECISION: <A|B|C> | CONFIDENCE: <high|medium|low> | REASON: <10 words>
```

## Context Rules

Orchestrator reads ONLY summary/verdict/decision line. Full output in artifact files.

| Item | Keep in orchestrator? |
|------|-----------------------|
| Issue number + title | Yes |
| Step summary (1 line) | Yes |
| Review verdict (1 line) | Yes |
| Full artifact content | NO — file path only |
| Full test/review output | NO — in artifact file |
| State.json | Read fresh each time |

**Target:** <2000 tokens accumulated state for 5-issue run.

## Agent Context Rules

- Give each agent ONLY what it needs
  - Workers: relevant step artifacts + issue number (they read issue themselves)
  - Reviewers: step output file path + brief scope
  - Experts: dilemma + relevant evidence only
- All prompts/comments/reports — short and dense
- Issue comments: max 15 lines, link to artifacts

## Comment Offloading

Orchestrator NEVER posts comments directly. Dispatch **subagent** (`model: "opus"`):

```
Post GitHub issue comment for issue #<N>.
Step: <step_num>/<step_name>
Status: <passed|rejected|blocked>
Summary: <1 line from worker's ORCHESTRATOR_SUMMARY>
Reviewer verdicts: <arch=✓|security=✗(reason)|standards=✓>
Attempt: <M>/<MAX>
Branch: <branch_name>

Format (max 15 lines, dense):
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
