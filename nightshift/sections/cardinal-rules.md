# CARDINAL RULES

These rules override everything else in this document. Violating any of them means the step FAILS.

## Rule 1: Never Assume — Verify With Proof

When investigating a bug or implementing a feature:
- **DO NOT** assume you know the root cause after reading the issue title
- **DO NOT** assume the first error message tells the whole story
- **DO** trace errors to their actual source (DB → API → Service → UI)
- **DO** reproduce the bug before fixing it (run the code, hit the endpoint, see the error)
- **DO** investigate from multiple angles before proposing a fix:
  - Read the relevant code
  - Check the database schema/data
  - Check API responses (curl/fetch)
  - Read logs
  - Check config/env
- **DO** ask: "Is this a code problem or a data/config problem?"
- If a single investigation path leads to a conclusion → investigate at least ONE more angle to confirm
- If multiple paths converge on the same diagnosis → proceed with confidence

When fixing:
- After applying a fix, **prove it works** — run the test, hit the endpoint, check the UI
- A fix is NOT done until you can show evidence it resolved the issue
- Code workarounds that mask root causes are REJECTED — find the real problem

## Rule 2: Hard Evidence Only — No Assumptions for Completion

A step is ONLY considered complete when backed by hard evidence:

| Evidence Type | What Counts | What Does NOT Count |
|--------------|-------------|---------------------|
| Tests pass | Actual test runner output showing pass counts | "I wrote tests, they should pass" |
| Bug is fixed | Screenshot/curl output showing correct behavior | "The fix looks correct" |
| Build works | Actual build output with exit code 0 | "The build should work" |
| UI works | Screenshot of the working feature | "I updated the component" |
| API works | Actual HTTP response body/status | "The endpoint should return 200" |
| Lint passes | Actual lint output with 0 errors | "I followed conventions" |

**For verification (Step 5), the worker MUST capture and include:**
- Full test output (copy-paste, not summarized)
- Build output (pass/fail with exit code)
- Screenshots of UI features (taken via browser tools, saved to files)
- API response bodies for endpoint changes (captured via curl)

## Rule 3: Every Iteration Comments on the GitHub Issue

Every step and every retry MUST post a comment on the GitHub issue. This creates a persistent knowledge trail that survives session restarts and helps humans understand what happened.

Keep comments under 15 lines, dense not verbose. See `sections/orchestrator.md` for the canonical comment format and offloading pattern.

**When to comment:**
- After EVERY step completion (pass or fail)
- After EVERY retry attempt
- After EVERY expert panel decision
- When an issue is BLOCKED
- When an issue is COMPLETED (final summary)
