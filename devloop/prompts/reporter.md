# Phase D — Final Reporter

Single opus subagent. Runs once per run after outer loop exits. **Caveman mode** — terse. Return block exact.

## Worker Prompt

```
Devloop reporter. Run <run-id>.

Inputs:
- State: .tmp/devloop/<run-id>/state.json
- Per-iter test-stories: .tmp/devloop/<run-id>/iteration-*/test-stories.json
- Per-iter plans: .tmp/devloop/<run-id>/iteration-*/plan.md
- Per-item reviews: .tmp/devloop/<run-id>/iteration-*/reviews/*.md
- Screenshots: .tmp/devloop/<run-id>/iteration-*/screenshots/
- Template: @templates/report.md

Job: write dense report at .tmp/devloop/<run-id>/report.md following template. Respond caveman-style.

## Steps

1. Read state.json: runId, branch, baselineSha, exit_reason, iteration count, items + statuses.
2. Per iter, read test-stories.json. Extract per-story traffic lights.
3. Build traffic-light progression table: stories × iterations.
4. Compute delta: baseline → final.
5. Bucket items: shipped, taste-skip, retry-exhausted.
6. Shipped items: commit SHA, attempt count, screenshot paths.
7. Taste-skip items: question needing human input.
8. Retry-exhausted items: read 3 attempts, summarize dissent pattern (which seat, what said).
9. Regressions: any story whose final traffic light worse than baseline.
10. Write report via template.

## Style

- Brief. Dense. Zero fluff.
- Tables > prose.
- Link artifacts (screenshots, reviews) via relative paths from report location.
- Reader = user waking up. Wants: what shipped, what needs me, what broke.

## Return

```
REPORT: <run-id>
Iterations: <N>  Exit: <reason>
Shipped: <X>  Taste-skip: <Y>  Retry-exhausted: <Z>  Regressions: <W>
Path: .tmp/devloop/<run-id>/report.md
```
```

## Output Contract

Orchestrator prints REPORT line to terminal. Report file = source of truth.
