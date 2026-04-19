---
description: "Use when processing GitHub issues autonomously overnight. Accepts issue numbers or picks up 'nightshift' labeled issues. Use --supervised for interactive checkpoints. Run it and go to sleep."
---

# Nightshift: Autonomous Issue Pipeline

Process GitHub issues through 7 pipeline steps. Each step reviewed by 3 agents — 2/3 majority to proceed, but ALL critical issues from any reviewer addressed. Confusion/dilemma → 3-agent expert panel, follow majority. All work merges into single `nightshift/<date>-<slug>` branch. You are orchestrator.

**PROVE IT. No assumptions, no guesses, only evidence.**
**BRIEF. Every comment, prompt, report — short, dense, zero fluff.**
**ALL agents use `model: "opus"`. See @sections/orchestrator.md.**

## Input

$ARGUMENTS

Parse issue numbers: `#50 #51 #52`, `50 51 52`, `50,51,52`.
If none: `gh issue list --label "nightshift" --state open --json number,title --limit 10`

**Flags:**
- `--supervised` — Pause after Step 2 (PLAN) for human feedback. See @sections/gates.md.

## Prerequisites

1. `git rev-parse --is-inside-work-tree` — must be in git repo
2. `gh auth status` — GitHub CLI authenticated
3. `git status --porcelain` — warn if dirty
4. Default branch: `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`

---

## Reference Documents — READ THESE

| Document | Covers |
|----------|--------|
| @sections/cardinal-rules.md | 3 cardinal rules — verify with proof, hard evidence, comment every iteration |
| @sections/orchestrator.md | Thin orchestrator, agent output formats, context rules, comment offloading |
| @sections/gates.md | Brainstorming gate, interactive checkpoint (--supervised), resume detection |
| @sections/branch-strategy.md | Branch setup, per-issue flow, end-of-nightshift PR |
| @sections/expert-panel.md | When/how to convene, decision rules, logging |
| @sections/retry-logic.md | Retry limits, ralph loop, anti-loop protection |
| @sections/rate-limits.md | Rate limit management, graceful stop |
| @sections/safety-rails.md | Risk/protection matrix |
| @templates/state-schema.json | State file schema for `.claude/nightshift/state.json` |
| @templates/morning-report.md | Morning report template |

---

## Issue Classification & Adaptive Pipeline

After Step 1 (UNDERSTAND), classify issue and skip unnecessary steps.

### Classification (Step 1 worker MUST include in `01-understand.md`)

```
## Issue Classification
Type: <simple-bug | feature | complex-investigation | config-change>
Recommended pipeline: <list of steps to run>
Reason: <1 sentence>

## UI Impact
Has UI changes: <yes | no>
Affected pages: <list of URLs or "none">
Mobile-critical: <yes | no>
Reason: <what visual changes to verify>
```

**UI Impact → Step 6 (QA):** `yes` = QA mandatory, `no` = QA skipped. Reviewers at Step 1 validate — disagreement defaults to `yes`.

### Adaptive Pipelines

| Type | Steps | When |
|------|-------|------|
| `feature` (UI) | 1→2→3→4→5→6→7 | New UI functionality |
| `feature` (API) | 1→2→3→4→5→7 | API-only |
| `complex-investigation` | 1→2→3→4→5→6→7 | Ambiguous bugs, multi-system |
| `simple-bug` (UI) | 1→4→5→6→7 | Clear fix with UI |
| `simple-bug` (API) | 1→4→5→7 | Clear fix, API-only |
| `config-change` | 1→2→5→7 | Env vars, CI config |

**Rules:**
- Steps 1, 5, 7 always run
- Step 6 runs when `UI Impact: yes`
- QA→CODE loop: QA bugs → step 4→5→6. Max 3 loops → BLOCKED
- Reviewer disagreement on classification → full pipeline
- When in doubt → full pipeline

### Skipped step state
```json
"2": { "status": "skipped", "attempts": 0, "maxAttempts": 3, "lastResult": "skipped" }
```

---

## Pipeline Steps (per issue)

| Step | Name | Prompt | Max Retries |
|------|------|--------|-------------|
| 1 | UNDERSTAND | @prompts/step-1-understand.md | 2 |
| 2 | PLAN | @prompts/step-2-plan.md | 3 |
| 3 | TEST | @prompts/step-3-test.md | 5 |
| 4 | CODE | @prompts/step-4-code.md | 7 |
| 5 | VERIFY | @prompts/step-5-verify.md | 5 |
| 6 | QA | @prompts/step-6-qa.md | 3 |
| 7 | SHIP | @prompts/step-7-ship.md | 1 |

**Per step:** Read prompt file → dispatch worker → run review gate → update state. Rejection → ralph retry (@sections/retry-logic.md). Confusion → expert panel (@sections/expert-panel.md).

### Review Gate Protocol (CRITICAL — overrides 2/3 majority)

**2/3 majority decides PROCEED/RETRY, but ALL critical issues from ANY reviewer must be addressed.**

1. Separate findings: **critical** (bugs, missing coverage, design flaws, crash risks) vs **minor** (naming, style)
2. ANY critical issue from ANY reviewer → MUST resolve before proceeding:
   - Quick fix → fix immediately in current step
   - Design change → add as **HARD REQUIREMENT** in next step's prompt
   - Next step's reviewers MUST verify hard requirement addressed
3. Critical issue needs approach decision → convene expert panel. Majority wins.
4. Never "carry forward as guidance" — fix now or hard requirement with verification
5. After CODE step, reviewers confirm: "All critical issues from earlier steps: addressed/not addressed" with evidence

---

## Morning Report

Offload to **subagent** (`model: "opus"`) that reads state + artifacts and writes report:

```
Generate nightshift morning report.
Read: .claude/nightshift/state.json and all issue artifact dirs (.claude/nightshift/issue-*/).
Write to: .claude/nightshift/morning-report.md using template at templates/morning-report.md.
Then create final PR. CRITICAL: PR body MUST include `Closes #N` for EVERY completed issue. Build closes line from state.json (all issues with status=completed).
Command: gh pr create --base <default_branch> --head $NIGHTSHIFT_BRANCH --title "nightshift: <date> — <N> issues shipped" --body "$(cat .claude/nightshift/morning-report.md)"
Return: ORCHESTRATOR_SUMMARY: Morning report written, PR created: <url>
```

---

## Orchestration Rules

1. **Sequential issues** — finish one (or block) before starting next
2. **Parallel reviewers** — spawn all 3 in one message
3. **Parallel expert panels** — spawn all 3 in one message
4. **State file** — update `.claude/nightshift/state.json` after EVERY step transition
5. **Issue comments** — post after EVERY step, retry, decision, completion
6. **Nightshift branch** — all issue branches merge back to `$NIGHTSHIFT_BRANCH`
7. **Post-merge health check** — verify nightshift branch builds + passes tests with FULL output
8. **No force push** — ever
9. **Main is sacred** — never push/merge to main
10. **Commit often** — minimum once per step
11. **Cool down** — brief pause between issues
12. **Confused → expert panel** — never guess
13. **Evidence or it didn't happen** — every success backed by output/screenshots/test results
14. **Never assume bugs** — reproduce first, multi-angle investigation, fix root cause
15. **Issue comments = source of truth** — next run reads comments to know what happened
16. **Rate limit awareness** — check between issues and after heavy steps (@sections/rate-limits.md)
17. **Thin orchestrator** — never read code/run tests/write artifacts directly. Dispatch subagents, read only summary lines.
