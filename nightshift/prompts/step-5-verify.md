# Step 5: VERIFY — Tests + Build

**Max retries: 5**

Automated code verification. No browser testing here — that's Step 6 (QA).

## Agent (subagent_type: `general-purpose`)

```
Prompt: Run automated verification on the current branch for issue #<N>.

**MANDATORY OUTPUT FILE:** .claude/nightshift/issue-<N>/05-verify.md

## Checks (run ALL, capture FULL output):
1. Typecheck: pnpm --filter @ecomitram/web exec tsc --noEmit
2. API tests: pnpm --filter @ecomitram/api test
3. Web tests: pnpm --filter @ecomitram/web test -- --run
4. Build: pnpm --filter @ecomitram/web build

## Report
Write FULL output (copy-paste, NOT summaries) to: .claude/nightshift/issue-<N>/05-verify.md

Include for each check:
- Full command output
- Pass/fail
- Test counts

If ANY check fails:
- Investigate root cause (don't retry blindly)
- Fix the issue
- Re-run the failing check
- Commit fix: `fix(<scope>): resolve <type> issue for #<N>`

CRITICAL: Step is NOT complete until ALL 4 checks pass with full evidence.

ORCHESTRATOR_SUMMARY: <pass/fail with test counts>
```

**After agent returns, verify artifact exists:**
```bash
ls .claude/nightshift/issue-<N>/05-verify.md
```
If missing → step failed regardless of summary.

## Review gate — 2 agents in parallel (`model: "opus"`)

| Reviewer | subagent_type | Focus |
|----------|--------------|-------|
| Testing | `testing` | ALL tests passing with proof? No regressions? Counts match? |
| Error handling | `error-handling` | Error paths handled? No unhandled rejections? Graceful failures? |

**Reviewers check:**
- Is `05-verify.md` present with FULL output (not truncated)?
- Do test counts show no regressions from previous steps?
- REJECT if output is summarized or artifact is missing

**2/3 approve → proceed, but ALL critical issues from ANY reviewer must be addressed (see Review Gate Protocol in run.md).**
