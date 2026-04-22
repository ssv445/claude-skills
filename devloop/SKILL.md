---
name: devloop
version: 1.0.0
description: |
  Tight polish loop for finishing work after a feature ships. Takes test-stories
  IDs, runs test-stories, fixes prioritized issues with a unanimous 3-seat
  expert panel per fix (adversarial + root-cause + convention) and a mandatory
  browser screenshot check, re-runs test-stories, repeats until clean or stuck.
  Fire-and-forget. Mechanical decisions owned by the agent. Novel taste calls
  skip the item — pipeline never blocks.
  Use: /devloop FEED-05 FEED-12, "polish FEED-05 with devloop", devloop --resume
allowed-tools:
  - Agent
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Skill
---

# Devloop — Tight Polish Loop on Test-Stories Output

Polish a shipped feature by looping `test-stories` runs and fix-passes until all listed stories are 🟢 (or we hit a stuck state). Each fix passes a 3-seat **unanimous** expert panel and a mandatory browser screenshot check before being committed. Mechanical decisions owned by the agent. **Novel taste decisions skip the item — never block the loop.**

**Core philosophy:** Each commit must compound. No left-right drift. The pipeline never stops for human input — it skips and reports.

**Communication style:** Brief. Comments, prompts, reports — short, dense, zero fluff.

**Model strategy:** ALL spawned agents use opus.

## Trigger

User says any of:
- `/devloop FEED-05 FEED-12 ONBOARD-02`
- `polish FEED-05 with devloop`
- `devloop FEED-05`
- `devloop --resume`
- `devloop --dry-run FEED-05`

Parse story IDs from the message. Accept formats: `FEED-05 FEED-12`, `FEED-05,FEED-12`, single ID `FEED-05`. Story IDs match the pattern `[A-Z]+-\d+`.

If no story IDs given (and not `--resume`): halt and tell the user "Devloop requires story IDs. Example: `devloop FEED-05 FEED-12`"

**Flags:**
- `--max-iterations N` — override outer loop cap (default: 7)
- `--resume` — resume the latest incomplete run
- `--dry-run` — run test-stories + Phase B (build punch-list), write plan, stop. No fixes.
- `--no-tests` — skip Gate 4 unit tests AND the per-iteration integration test step
- `--no-integration` — keep per-item unit tests but skip the per-iteration integration test step

## Prerequisites

1. `git rev-parse --is-inside-work-tree` — must be in a git repo
2. `git status --porcelain` — warn if dirty working tree, halt if `--resume` and dirty
3. Verify `test-stories` skill exists (will be invoked via Skill tool)
4. Identify current branch — devloop commits straight onto it, **no branch creation, no PR**
5. **Auto-detect test commands** (unless `--no-tests`). See @prompts/test-runner.md for detection rules. Cache `unitCommand` and `integrationCommand` in state.json. If neither resolves, log "no test command detected" and run without test gates.

## Setup (fresh run only)

1. Generate run ID: `date +%Y-%m-%d-%H%M`
2. Create `.tmp/devloop/<run-id>/`
3. Verify `.tmp/` is in `.gitignore` — add it if not
4. Snapshot baseline commit SHA → state.json
5. Initialize state.json from @templates/state-schema.json
6. Set iteration = 0

## The Outer Loop

Run up to `MAX_ITERATIONS` (default 7) passes:

```
while iteration < MAX_ITERATIONS:
  iteration += 1
  mkdir .tmp/devloop/<run-id>/iteration-<N>/

  # Phase A — Run test-stories
  Invoke /test-stories via the Skill tool with the provided story IDs.
  Capture output to .tmp/devloop/<run-id>/iteration-<N>/test-stories.json
  Read traffic lights per story.

  # Exit checks
  if all stories are 🟢:
    exit_reason = "CLEAN"; break
  if iteration > 1 and current_unresolved == previous_unresolved:
    exit_reason = "STUCK"; break
  if iteration == MAX_ITERATIONS:
    exit_reason = "CAPPED"; break

  # Phase B — Build punch-list
  Dispatch the punch-list-builder agent (see @prompts/punch-list-builder.md).
  Output: iteration-<N>/plan.md with ordered items + skip list (taste-skips logged here).

  if --dry-run flag is set: exit_reason = "DRY_RUN"; break

  # Phase C — Execute fixes
  For each item in plan.md (sequential):
    execute_item(item)  # see "Per-Item Execution"
    update state.json after every transition

  # Phase C.5 — Integration regression guard (per-iteration)
  if integrationCommand is set AND --no-integration is not set AND --no-tests is not set:
    Dispatch test-runner in INTEGRATION mode (see @prompts/test-runner.md).
    if returns FAIL or TIMEOUT:
      record failure in state.json (iteration.integrationResult)
      exit_reason = "REGRESSION"
      break  # halt the outer loop, jump straight to Phase D

# Phase D — Final report
Dispatch the reporter agent (see @prompts/reporter.md).
Output: .tmp/devloop/<run-id>/report.md
Print summary to terminal.
```

## Per-Item Execution

Each item passes 3 gates. Any failure → retry up to 3 times (fresh fixer each time, prior dissent passed in). 3 retries exhausted → SKIP with reason `retry-exhausted`. Novel taste call detected → SKIP immediately with reason `taste-skip`, no retries.

```
def execute_item(item):
  attempt = 0

  # Capture BEFORE screenshot
  Dispatch browser-checker in "before" mode (see @prompts/browser-checker.md).
  Save to iteration-<N>/screenshots/<item-id>-before.png

  while attempt < 3:
    attempt += 1

    # Gate 1 — FIX
    Dispatch FRESH fixer agent (see @prompts/fixer.md).
    Pass: item, plan, prior commits in this run, prior dissent (if any).
    if fixer returns TASTE_SKIP:
      mark item taste-skip with the question; return
    if fixer returns FIXED: continue to gate 2

    # Gate 2 — EXPERT PANEL (3 seats, parallel, single message, UNANIMOUS)
    Dispatch in parallel (one tool block, 3 Agent calls):
      - adversarial reviewer (@prompts/reviewer-adversarial.md)
      - root-cause reviewer (@prompts/reviewer-root-cause.md)
      - convention reviewer (@prompts/reviewer-convention.md)
    Save verdicts to iteration-<N>/reviews/<item-id>-attempt-<attempt>.md

    if any seat returns DISSENT:
      git reset --hard HEAD          # roll back the in-progress fix only
      continue                       # retry with dissent notes

    # Gate 3 — BROWSER CHECK
    Dispatch browser-checker in "after" mode.
    Save to iteration-<N>/screenshots/<item-id>-after.png
    if browser-checker returns FAIL:
      git reset --hard HEAD
      continue

    # Gate 4 — UNIT TESTS (regression guard)
    if unitCommand is set AND --no-tests is not set:
      Dispatch test-runner in UNIT mode (see @prompts/test-runner.md).
      Save result to iteration-<N>/tests/<item-id>-attempt-<attempt>.md
      if returns FAIL or TIMEOUT:
        git reset --hard HEAD
        record dissent note from this gate
        continue                  # retry with the unit failure as additional context

    # All gates passed → commit
    git add -A
    git commit -m "devloop: <item-id> <title>"
    mark item shipped, record commit SHA
    return

  # Loop exhausted
  mark item retry-exhausted, log dissent history
```

**Critical rules:**

- `git reset --hard HEAD` rolls back only the in-progress item, never previously committed items in this run
- Each retry spawns a **fresh** fixer — no contaminated context from the failed attempt
- The 3 reviewers run **in parallel**: a single message containing one tool block with three Agent calls
- **Unanimous required**: all 3 must say PROCEED. One dissent = retry
- Novel taste call from any agent → item gets `taste-skip`, no retries, pipeline continues. The skip list IS the human handoff.
- The orchestrator is **thin**: never read code, run tests, or write artifacts directly. Dispatch to subagents, read only their summary lines.

## Stuck Detection

After Phase A in iteration N>1:
- Build the unresolved-issues set: `{(story-id, failing-criterion)}` for every still-failing item
- Compare against the unresolved-issues set from iteration N-1
- If the sets are equal → STUCK, exit the outer loop

## State File

`.tmp/devloop/<run-id>/state.json` — see @templates/state-schema.json

Update after every transition: iteration start, phase transition, item start, attempt, verdict, commit, skip.

## Resume Behavior

`devloop --resume`:
1. Find latest `.tmp/devloop/*/` with `exit_reason: null`
2. Halt if dirty working tree
3. Load state.json
4. If an item was `in-progress`: `git reset --hard <baselineOfThatItem>` and re-mark `pending`
5. Resume the outer loop at the iteration where it left off (re-running test-stories for that iteration if it was mid-Phase-B/C)

## Reference Documents

| Document | What it covers |
|----------|---------------|
| @prompts/punch-list-builder.md | Phase B agent: extract, filter, adversarial-review, order |
| @prompts/fixer.md | Gate 1 agent: makes the change, can declare TASTE_SKIP |
| @prompts/reviewer-adversarial.md | Gate 2 seat: tries to break the fix |
| @prompts/reviewer-root-cause.md | Gate 2 seat: cause vs symptom check |
| @prompts/reviewer-convention.md | Gate 2 seat: codebase architecture/style/naming alignment |
| @prompts/browser-checker.md | Gate 3 agent: agent-browser, before/after screenshots, verifies fix is visible |
| @prompts/test-runner.md | Gate 4 (unit, per-item) and Phase C.5 (integration, per-iteration) regression guard |
| @prompts/reporter.md | Phase D agent: writes the final report |
| @templates/state-schema.json | State file schema |
| @templates/report.md | Final report template |

## Cardinal Rules

1. **PROVE IT.** Every claim of "fixed" requires a passing browser screenshot. No assumptions.
2. **UNANIMOUS or RETRY.** A 2/3 majority is not enough. Compounding requires consensus.
3. **NEVER BLOCK.** Pipeline runs to completion. Taste skips happen, the report shows them, you handle them in the morning.
4. **OWN MECHANICAL.** Naming, formatting, obvious utility choices, file placement that follows existing patterns — agent decides, no escalation.
5. **NEVER SWITCH BRANCHES.** Devloop commits straight onto the current branch. Never creates a branch. Never pushes. Never opens a PR.
6. **EVIDENCE OR IT DIDN'T HAPPEN.** Every shipped item must have: a commit SHA + before screenshot + after screenshot + 3 PROCEED verdicts on file.
7. **THIN ORCHESTRATOR.** The skill itself never edits code, runs tests, or reads project files. It only dispatches subagents and reads their summary lines.
8. **CAVEMAN MODE.** Every spawned subagent receives a prompt that explicitly instructs caveman-compressed output (terse, fragments, no filler). Prompt files are already caveman-style. Return-format blocks are exact (the orchestrator parses them) — do not compress those. Agents respond in caveman form; summary lines stay parseable.

## Examples

```
/devloop FEED-05 FEED-12 ONBOARD-02
```
Polishes three stories until all 🟢 or stuck (max 7 iterations).

```
/devloop --max-iterations 3 FEED-05
```
Single story, capped at 3 outer-loop passes.

```
/devloop --dry-run FEED-05
```
Runs test-stories once, builds the punch-list, writes the plan, stops. Lets you sanity-check the work before spending tokens.

```
/devloop --resume
```
Picks up the latest incomplete run from where it stopped.
