# Devloop run {runId}

**Branch:** {branch}
**Baseline → Final:** {baselineSha} → {finalSha} ({totalCommits} commits)
**Iterations:** {iterationsRun} / {maxIterations}
**Exit:** {exit_reason}
**Items:** {totalItems} total → {shippedCount} shipped, {tasteSkipCount} taste-skip, {retryExhaustedCount} retry-exhausted

## Traffic light progression

| Story | Baseline | {iter1} | {iter2} | ... | Final |
|---|---|---|---|---|---|
| {story-id} | 🔴 | 🟡 | 🟢 | | 🟢 |

**Delta:** 🔴 {n→m} ({±k})  🟡 {n→m} ({±k})  🟢 {n→m} ({±k})

**Regressions:** {none | list}

---

## Shipped ({shippedCount})

| # | Item | Iter | Attempts | Commit | Before / After |
|---|---|---|---|---|---|
| 1 | `FEED-02-fix-spacing` — Card spacing inconsistent on mobile | 1 | 1 | `def4567` | [before](iteration-1/screenshots/FEED-02-fix-spacing-before.png) / [after](iteration-1/screenshots/FEED-02-fix-spacing-after.png) |

---

## Taste-skipped ({tasteSkipCount}) — needs your input

### `{item-id}` — {title}
- **Iteration:** {N}
- **Source story:** {story-id}
- **Question:** {the specific decision that needs human input}
- **Why no precedent:** {one line — what the agent looked for and didn't find}

---

## Retry-exhausted ({retryExhaustedCount}) — investigate manually

### `{item-id}` — {title}
- **Iteration:** {N}
- **Source story:** {story-id}
- **Failing criterion:** {criterion}
- **Dissent history:**
  - Attempt 1 — {seat} dissented: {reason}
  - Attempt 2 — {seat} dissented: {reason}
  - Attempt 3 — {seat} dissented: {reason}
- **Pattern:** {one-line summary of why this kept failing — same seat each time? different seats? root cause never found?}
- **Recommendation:** {what the user should look at}

---

## Regressions ({regressionCount})

{none — or, for each:}

### {story-id}
- **Was:** 🟢 (baseline)
- **Now:** 🟡 (final)
- **What got worse:** {criterion that started failing during this run}
- **Likely culprit:** {item-id of a shipped commit that may have caused this — based on iteration order and affected pages}

---

## Test results

**Test commands detected:** unit=`{unitCommand}`, integration=`{integrationCommand}` (source: `{detectionSource}`)

### Unit tests (per item)
| Item | Status | Scope | Duration |
|---|---|---|---|
| `FEED-02-fix-spacing` | ✅ pass | scoped | 4.2s |

### Integration tests (per iteration)
| Iter | Status | Duration | Failing tests | Likely culprits |
|---|---|---|---|---|
| 1 | ✅ pass | 2m 14s | — | — |
| 2 | ❌ fail | 1m 58s | `feed.test.ts > pagination` | `def4567`, `abc1234` |

{If exit_reason==REGRESSION, add a prominent block:}

### ⚠️ REGRESSION — outer loop halted at iteration {N}
The integration suite started failing after iteration {N}'s commits landed. The outer loop stopped before re-running test-stories.

**Failing tests:**
- `{test name 1}`
- `{test name 2}`

**Likely culprit commits (touched files exercised by the failing tests):**
- `{sha}` — `{item-id} {title}`
- `{sha}` — `{item-id} {title}`

**Recommendation:** Investigate these commits. Revert one or all and resume devloop, or fix forward.

---

## Artifacts

- State: `.tmp/devloop/{runId}/state.json`
- Per-iteration plans: `.tmp/devloop/{runId}/iteration-*/plan.md`
- Per-item reviews: `.tmp/devloop/{runId}/iteration-*/reviews/`
- Screenshots: `.tmp/devloop/{runId}/iteration-*/screenshots/`
- Test-stories snapshots: `.tmp/devloop/{runId}/iteration-*/test-stories.json`
