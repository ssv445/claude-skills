# Step 3: TEST — Write Failing Tests (TDD Red Phase)

**Max retries: 5**

Create the issue branch FROM the nightshift branch:
```bash
git checkout $NIGHTSHIFT_BRANCH && git pull
git checkout -b feat/<N>-<short-slug>
```

## Worker agent (subagent_type: `general-purpose`)

```
Prompt: Read .claude/nightshift/issue-<N>/02-plan.md (approved plan).
Read existing issue comments for prior context: `gh issue view <N> --comments`

Write ONLY the tests. Do NOT write implementation code yet.
Follow existing test patterns in the codebase.

Types of tests to write:
1. Unit tests (*.spec.ts) — for services, utils, pure functions
2. E2E API tests (*.e2e-spec.ts) — for API endpoints
3. Playwright browser tests — for user-facing flows (if the plan says browser testing needed)

For Playwright tests:
- Use the project's existing Playwright config (apps/web/playwright.config.ts)
- Test against the local dev URLs:
  - Web: http://ecomitram.localhost:1355
  - API: http://api.ecomitram.localhost:1355
- Follow existing Playwright test patterns in the codebase
- Use page objects if the project uses them

Tests should FAIL because the feature doesn't exist yet (TDD red phase).

For BUG issues: write a test that REPRODUCES the bug first.
The test should fail now (proving the bug exists) and pass after the fix.

After writing tests:
1. Run unit/e2e tests — capture FULL output (not summarized)
2. Confirm they fail for the RIGHT reason (missing implementation, not syntax errors)
3. For Playwright tests: run with `pnpm --filter @ecomitram/web test:e2e` or similar
   - If the dev server isn't running, start it first
   - If Playwright tests can't run, note this — they'll run at verification
4. Commit: `test(<scope>): add failing tests for issue #<N>`
5. Write summary to: .claude/nightshift/issue-<N>/03-tests.md listing:
   - Test files created/modified
   - Test cases and what they verify
   - Which tests are unit, e2e-api, or playwright-browser
   - FULL test runner output (copy-paste, not summarized)
   - Confirmation that tests fail for the right reason with evidence

At the very end of your response, output:
ORCHESTRATOR_SUMMARY: <1 sentence, max 20 words, describing outcome>
```

**After the worker finishes, offload issue commenting to a subagent (Rule 3).**

## Review gate — 3 agents in parallel (`model: "opus"`)

| Reviewer | subagent_type | Focus |
|----------|--------------|-------|
| Test quality | `testing` | Comprehensive? Edge cases? Good assertions? Right test types? Bug reproduction test? |
| Standards | `code-standards` | Follow project conventions? Naming? File structure? |
| Architecture | `architecture` | Testing behavior not implementation? Good isolation? |

Each outputs a `VERDICT` line (see Agent Output Formats).

**2/3 approve → proceed, but ALL critical issues from ANY reviewer must be addressed (see Review Gate Protocol in run.md).** Rejected → ralph retry. **Offload review comment to subagent.**
