---
description: "Use when processing GitHub issues autonomously overnight. Accepts issue numbers or picks up 'nightshift' labeled issues. Use --supervised for interactive checkpoints. Run it and go to sleep."
---

# Nightshift: Autonomous Issue Pipeline

Process GitHub issues autonomously. Each issue passes through 7 pipeline steps. Each step is reviewed by 3 agents — 2/3 majority to proceed, but ALL critical issues from any reviewer must be addressed. When confused or facing a dilemma, convene a 3-agent expert panel and follow majority. All work merges into a single `nightshift/<date>-<slug>` branch (slug from first issue title). You are the orchestrator.

**Core philosophy: PROVE IT. No assumptions, no guesses, only evidence.**

**Communication style: BRIEF. Every comment, prompt, and report — short, dense, zero fluff.**

**Model strategy: ALL agents use `model: "opus"`. See @sections/orchestrator.md.**

## Input

$ARGUMENTS

Parse issue numbers from the arguments. Accept formats: `#50 #51 #52`, `50 51 52`, `50,51,52`.
If no issues provided, run: `gh issue list --label "nightshift" --state open --json number,title --limit 10` and use those.

**Flags:**
- `--supervised` — Enable interactive checkpoints. Pauses after Step 2 (PLAN) for human feedback. See @sections/gates.md.

## Prerequisites

1. `git rev-parse --is-inside-work-tree` — must be in a git repo
2. `gh auth status` — GitHub CLI authenticated
3. `git status --porcelain` — warn if dirty working tree
4. Identify default branch: `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`

---

## Reference Documents — READ THESE

Before starting, read these reference documents. They contain the full details for each aspect of the pipeline:

| Document | What it covers |
|----------|---------------|
| @sections/cardinal-rules.md | **3 cardinal rules** — verify with proof, hard evidence only, comment on every iteration |
| @sections/orchestrator.md | Model strategy, thin orchestrator pattern, agent output formats, context rules, comment offloading |
| @sections/gates.md | Brainstorming gate, interactive checkpoint (--supervised), resume detection & recovery |
| @sections/branch-strategy.md | Nightshift branch setup, per-issue flow, end-of-nightshift PR |
| @sections/expert-panel.md | When to convene, how to convene, decision rules, logging |
| @sections/retry-logic.md | Retry limits per step, ralph loop, anti-loop protection |
| @sections/rate-limits.md | Rate limit management, graceful stop |
| @sections/safety-rails.md | Full risk/protection matrix |
| @templates/state-schema.json | State file schema for `.claude/nightshift/state.json` |
| @templates/morning-report.md | Morning report template |

---

## Issue Classification & Adaptive Pipeline

Not every issue needs all 7 steps. After Step 1 (UNDERSTAND), classify the issue and skip unnecessary steps.

### Classification (determined by Step 1 worker)

The Step 1 worker MUST include in `01-understand.md`:

```
## Issue Classification
Type: <simple-bug | feature | complex-investigation | config-change>
Recommended pipeline: <list of steps to run>
Reason: <1 sentence justification>

## UI Impact
Has UI changes: <yes | no>
Affected pages: <list of URLs to visually test, or "none">
Mobile-critical: <yes | no>
Reason: <1 sentence — what visual changes to verify>
```

**UI Impact determines whether the QA step (Step 6) runs.**
If `Has UI changes: yes`, Step 6 (QA) is MANDATORY — a separate agent opens the browser and tests every acceptance criterion.
If `Has UI changes: no` (API-only), Step 6 is skipped.
Reviewers at Step 1 validate this classification — if they disagree, default to `yes`.

### Adaptive Pipelines

| Type | Steps | When to use |
|------|-------|-------------|
| `feature` (UI) | 1 → 2 → 3 → 4 → 5 → 6 → 7 | New UI functionality |
| `feature` (API) | 1 → 2 → 3 → 4 → 5 → 7 | API-only (skip QA) |
| `complex-investigation` | 1 → 2 → 3 → 4 → 5 → 6 → 7 | Ambiguous bugs, multi-system |
| `simple-bug` (UI) | 1 → 4 → 5 → 6 → 7 | Clear fix with UI changes |
| `simple-bug` (API) | 1 → 4 → 5 → 7 | Clear fix, API-only |
| `config-change` | 1 → 2 → 5 → 7 | Env vars, CI config |

**Rules:**
- Step 1 (UNDERSTAND) always runs — classification requires investigation
- Step 5 (VERIFY) always runs — tests + build are non-negotiable
- Step 6 (QA) runs when `UI Impact: yes` — browser testing is the real proof
- Step 7 (SHIP) always runs — must PR and merge
- **QA → CODE loop:** If QA finds bugs, issue loops back to CODE (step 4) → VERIFY (step 5) → QA (step 6). Max 3 loops before BLOCKED.
- Reviewers at Step 1 review gate validate the classification. If they disagree → full pipeline.
- When in doubt → full pipeline. Skipping steps is an optimization, not a default.

### State tracking for skipped steps

Skipped steps get `status: "skipped"` in state.json:
```json
"2": { "status": "skipped", "attempts": 0, "maxAttempts": 3, "lastResult": "skipped" }
```

---

## Pipeline Steps (per issue)

Each step has a dedicated prompt file with the full worker prompt, review gate, and reviewer table.

| Step | Name | Prompt File | Max Retries | Notes |
|------|------|-------------|-------------|-------|
| 1 | UNDERSTAND | @prompts/step-1-understand.md | 2 | Always runs |
| 2 | PLAN | @prompts/step-2-plan.md | 3 | |
| 3 | TEST | @prompts/step-3-test.md | 5 | TDD red phase |
| 4 | CODE | @prompts/step-4-code.md | 7 | TDD green phase |
| 5 | VERIFY | @prompts/step-5-verify.md | 5 | Tests + build |
| 6 | QA | @prompts/step-6-qa.md | 3 | Browser testing — UI issues only. Bugs loop back to step 4. |
| 7 | SHIP | @prompts/step-7-ship.md | 1 | Always runs |

**For each step:** Read the prompt file, dispatch the worker agent, run the review gate, update state. On rejection → ralph retry (see @sections/retry-logic.md). On confusion → expert panel (see @sections/expert-panel.md).

### Review Gate Protocol (CRITICAL — overrides 2/3 majority)

**2/3 majority decides PROCEED vs RETRY, but ALL critical issues from ANY reviewer must be addressed — even from the minority rejecting reviewer.**

1. After collecting 3 reviewer verdicts, separate findings into: **critical** (bugs, missing coverage, design flaws, crash risks) vs **minor** (naming, style preferences)
2. If ANY reviewer flags a critical issue → that issue MUST be resolved before proceeding:
   - If resolvable with a quick fix → fix it immediately in the current step
   - If it needs design changes → add it as a **HARD REQUIREMENT** (not a suggestion) in the next step's prompt
   - The next step's reviewers MUST verify the hard requirement was addressed
3. If a critical issue needs a decision between approaches → convene a 3-agent expert panel (same pattern as dilemma resolution). Majority wins.
4. Never "carry forward as guidance" — either fix it now, or make it a hard requirement with verification.
5. After CODE step, reviewers must explicitly confirm: "All critical issues from earlier steps: addressed/not addressed" with evidence.

---

## Morning Report

After all issues processed, offload to a **subagent** (`model: "opus"`) that reads state + artifacts and writes the report:

```
Generate the nightshift morning report.
Read: .claude/nightshift/state.json and all issue artifact dirs (.claude/nightshift/issue-*/).
Write to: .claude/nightshift/morning-report.md using the template at templates/morning-report.md.
Then create the final PR. CRITICAL: The PR body MUST include `Closes #N` for EVERY completed issue so GitHub auto-closes them on merge. Example: `Closes #43, closes #44, closes #45`. Build the closes line from state.json (all issues with status=completed). Command: gh pr create --base <default_branch> --head $NIGHTSHIFT_BRANCH --title "nightshift: <date> — <N> issues shipped" --body "$(cat .claude/nightshift/morning-report.md)"
Return: ORCHESTRATOR_SUMMARY: Morning report written, PR created: <url>
```

---

## Orchestration Rules

1. **Sequential issues** — finish one completely (or mark blocked) before starting the next
2. **Parallel reviewers** — always spawn all 3 review agents in one message
3. **Parallel expert panels** — always spawn all 3 experts in one message
4. **State file** — update `.claude/nightshift/state.json` after EVERY step transition
5. **Issue comments** — post on the GitHub issue after EVERY step, retry, decision, and completion
6. **Nightshift branch** — all issue branches created from and merged back to `$NIGHTSHIFT_BRANCH`
7. **Post-merge health check** — after merging each issue, verify nightshift branch still builds and passes tests with FULL output
8. **No force push** — ever
9. **Main is sacred** — never push to main, never merge to main
10. **Commit often** — at minimum once per step (test, code, fix)
11. **Cool down** — brief pause between issues
12. **When confused → expert panel** — never guess, never assume, always convene
13. **Evidence or it didn't happen** — every claim of success must be backed by captured output, screenshots, or test results
14. **Never assume bugs** — reproduce first, investigate from multiple angles, fix root cause not symptoms
15. **Issue comments are the source of truth** — if the session dies, the next run reads comments to know what happened
16. **Rate limit awareness** — check usage between issues and after heavy steps (see @sections/rate-limits.md)
17. **Thin orchestrator** — never read code, run tests, or write artifacts directly. Dispatch to subagents, read only their summary lines.

---

## Example Invocation

```
/nightshift:run #50 #51 #52
```

```
/nightshift:run  (picks up issues labeled "nightshift")
```

```
/nightshift:run --supervised #50 #51  (pauses after PLAN for human feedback)
```
