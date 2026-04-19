# CARDINAL RULES

Override everything else. Violating any = step FAILS.

## Rule 1: Never Assume — Verify With Proof

Investigating bugs/features:
- DO NOT assume root cause from issue title
- DO NOT assume first error tells whole story
- DO trace errors to source (DB → API → Service → UI)
- DO reproduce bug before fixing (run code, hit endpoint, see error)
- DO investigate multiple angles: code, DB schema/data, API responses, logs, config/env
- DO ask: code problem or data/config problem?
- Single path → confirm with at least ONE more angle
- Multiple paths converge → proceed with confidence

Fixing:
- After fix, **prove it works** — run test, hit endpoint, check UI
- Not done until evidence shows resolution
- Workarounds masking root causes → REJECTED

## Rule 2: Hard Evidence Only

Step complete ONLY with hard evidence:

| Evidence Type | Counts | Does NOT Count |
|--------------|--------|----------------|
| Tests pass | Actual runner output with pass counts | "I wrote tests, they should pass" |
| Bug fixed | Screenshot/curl showing correct behavior | "The fix looks correct" |
| Build works | Build output with exit code 0 | "The build should work" |
| UI works | Screenshot of working feature | "I updated the component" |
| API works | Actual HTTP response body/status | "The endpoint should return 200" |
| Lint passes | Lint output with 0 errors | "I followed conventions" |

**Step 5 worker MUST capture:** full test output (copy-paste), build output (pass/fail + exit code), screenshots for UI, API responses via curl.

## Rule 3: Every Iteration Comments on GitHub Issue

Every step and retry MUST post issue comment. Creates persistent trail surviving session restarts.

Max 15 lines, dense. See `sections/orchestrator.md` for format.

**When:** after every step (pass/fail), every retry, every expert panel decision, BLOCKED, COMPLETED.
