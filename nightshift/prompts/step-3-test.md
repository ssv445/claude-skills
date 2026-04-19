# Step 3: TEST — Write Failing Tests (TDD Red Phase)

**Max retries: 5**

Create issue branch FROM nightshift branch:
```bash
git checkout $NIGHTSHIFT_BRANCH && git pull
git checkout -b feat/<N>-<short-slug>
```

## Worker agent (subagent_type: `general-purpose`)

```
Prompt: Read .claude/nightshift/issue-<N>/02-plan.md (approved plan).
Read issue comments: `gh issue view <N> --comments`

Write ONLY tests. NO implementation code.
Follow existing test patterns.

Test types:
1. Unit tests (*.spec.ts) — services, utils, pure functions
2. E2E API tests (*.e2e-spec.ts) — API endpoints
3. Playwright browser tests — user-facing flows (if plan requires)

Playwright tests:
- Use project's existing config (apps/web/playwright.config.ts)
- Test against local dev URLs:
  - Web: http://ecomitram.localhost:1355
  - API: http://api.ecomitram.localhost:1355
- Follow existing Playwright patterns

Tests should FAIL — feature doesn't exist yet (TDD red).

BUG issues: write test reproducing the bug. Fails now, passes after fix.

After writing:
1. Run unit/e2e tests — capture FULL output
2. Confirm fail for RIGHT reason (missing impl, not syntax errors)
3. Playwright: run with `pnpm --filter @ecomitram/web test:e2e`
   - If dev server not running, start first
   - Can't run → note for verification step
4. Commit: `test(<scope>): add failing tests for issue #<N>`
5. Write to: .claude/nightshift/issue-<N>/03-tests.md:
   - Test files created/modified
   - Test cases and what they verify
   - Which are unit, e2e-api, or playwright
   - FULL test runner output (copy-paste)
   - Confirmation tests fail for right reason with evidence

At the very end of your response, output:
ORCHESTRATOR_SUMMARY: <1 sentence, max 20 words, describing outcome>
```

**After worker finishes, offload issue commenting to subagent (Rule 3).**

## Review gate — 3 agents in parallel (`model: "opus"`)

| Reviewer | subagent_type | Focus |
|----------|--------------|-------|
| Test quality | `testing` | Comprehensive? Edge cases? Good assertions? Bug reproduction? |
| Standards | `code-standards` | Project conventions? Naming? File structure? |
| Architecture | `architecture` | Testing behavior not implementation? Good isolation? |

Each outputs `VERDICT` line.

**2/3 approve → proceed, but ALL critical issues from ANY reviewer addressed (see Review Gate Protocol in run.md).** Rejected → ralph retry. **Offload review comment to subagent.**
