# Step 6: SHIP — Push, PR, Merge to Nightshift

**Max retries: 1** (if this fails, convene expert panel)

```bash
# Push the issue branch
git push -u origin feat/<N>-<short-slug>

# Create PR targeting the nightshift branch (NOT main)
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
<from 05-verify.md — lint/typecheck/test/build/browser results>

## Evidence
- Test output: [see 05-verify.md]
- Screenshots: [list screenshot files with descriptions]
- API verification: [curl outputs if applicable]

## Review Log
Steps: understand(✓) → plan(✓) → test(✓) → code(✓) → verify(✓)
Review gates passed: 5/5
Total reviewer agents consulted: 15+
Expert panel decisions: <N> (see decisions.md)
Retries used: step1=<N>/2, step2=<N>/3, step3=<N>/5, step4=<N>/7, step5=<N>/5
Issue comments posted: <N>

<list any rejections and how they were resolved>

Closes #<N>
EOF
)"

# Post final completion comment on the issue
gh issue comment <N> --body "$(cat <<'COMMENT'
## Nightshift — COMPLETED

PR created: <PR_URL>
Target: $NIGHTSHIFT_BRANCH (not main)

### Final Evidence Summary
- Tests: <N> passed, 0 failed
- Lint: clean
- Typecheck: clean
- Build: success
- Browser tests: <N> passed (or N/A)
- Screenshots: <count> captured

### Full audit trail
All step-by-step progress is in the comments above.
Detailed artifacts: .claude/nightshift/issue-<N>/
COMMENT
)"

# Merge the PR into nightshift branch (squash merge)
gh pr merge <PR_NUMBER> --squash --delete-branch

# Pull the updated nightshift branch
git checkout $NIGHTSHIFT_BRANCH && git pull

# Verify nightshift branch is healthy after merge — HARD EVIDENCE
pnpm typecheck 2>&1 | tee /tmp/nightshift-typecheck.log
pnpm test 2>&1 | tee /tmp/nightshift-test.log
# If verification fails after merge → convene expert panel
```

Update state: `mergedToNightshift: true`

Write final status to `.claude/nightshift/issue-<N>/06-ship.md`.
