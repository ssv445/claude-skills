# Step 7: SHIP — Push, PR, Merge to Nightshift

**Max retries: 1** (fails → expert panel)

```bash
# Push issue branch
git push -u origin feat/<N>-<short-slug>

# PR targets nightshift branch (NOT main)
gh pr create \
  --base $NIGHTSHIFT_BRANCH \
  --title "feat(<scope>): <description> (#<N>)" \
  --body "$(cat <<'EOF'
## Summary
<2-3 bullets from 04-code.md>

## What Changed
<files changed summary>

## Test Plan
<from 03-tests.md>

## Verification Results
<from 05-verify.md — lint/typecheck/test/build results>

## Evidence
- Test output: [see 05-verify.md]
- Screenshots: [list with descriptions]
- API verification: [curl outputs if applicable]

## Review Log
Steps: understand(✓) → plan(✓) → test(✓) → code(✓) → verify(✓)
Review gates passed: 5/5
Total reviewer agents: 15+
Expert panels: <N> (see decisions.md)
Retries: step1=<N>/2, step2=<N>/3, step3=<N>/5, step4=<N>/7, step5=<N>/5
Issue comments: <N>

<rejections and resolutions>

Closes #<N>
EOF
)"

# Completion comment
gh issue comment <N> --body "$(cat <<'COMMENT'
## Nightshift — COMPLETED

PR created: <PR_URL>
Target: $NIGHTSHIFT_BRANCH (not main)

### Evidence Summary
- Tests: <N> passed, 0 failed
- Lint: clean
- Typecheck: clean
- Build: success
- Browser tests: <N> passed (or N/A)
- Screenshots: <count>

### Audit trail
All progress in comments above.
Artifacts: .claude/nightshift/issue-<N>/
COMMENT
)"

# Merge to nightshift (squash)
gh pr merge <PR_NUMBER> --squash --delete-branch

# Pull updated nightshift
git checkout $NIGHTSHIFT_BRANCH && git pull

# Post-merge health check — HARD EVIDENCE
pnpm typecheck 2>&1 | tee /tmp/nightshift-typecheck.log
pnpm test 2>&1 | tee /tmp/nightshift-test.log
# Verification fails → expert panel
```

Update state: `mergedToNightshift: true`

Write final status to `.claude/nightshift/issue-<N>/07-ship.md`.
