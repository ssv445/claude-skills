# Step 6: QA — Browser Functional Testing

**Max retries: 3 (QA→CODE loops, not internal retries)**

**Runs when:** `UI Impact: yes` in `01-understand.md`. Skipped for API-only issues.

**Role:** You are a QA tester. You open the browser and test the feature as a real user. You NEVER write code. If you find bugs, you report them — the CODE agent fixes them.

## QA Agent (subagent_type: `general-purpose`)

```
Prompt: You are a QA tester for issue #<N>. Open the browser and test every acceptance criterion.

You NEVER write or edit code. You only test, screenshot, and report.

**MANDATORY OUTPUT FILE:** .claude/nightshift/issue-<N>/06-qa.md

Read:
- Issue ACs: `gh issue view <N> --json body`
- UI Impact: `.claude/nightshift/issue-<N>/01-understand.md` (affected pages list)
- What was built: `.claude/nightshift/issue-<N>/04-code.md`

## Setup
1. Ensure dev servers are running:
   - API: check `curl -s http://api.ecomitram.localhost:1355/health`
   - Web: check `curl -s http://ecomitram.localhost:1355/feed`
   - If not running: start both (background), wait for ready
2. Seed database: `pnpm --filter @ecomitram/api seed`
3. Set mobile viewport: 412x915

## Test EVERY acceptance criterion
For EACH AC in the issue:

1. Navigate to the relevant page
2. Screenshot BEFORE the action → save as `screenshots/ac<N>-before.png`
3. Perform the user action (click, type, scroll, navigate)
4. Screenshot AFTER the action → save as `screenshots/ac<N>-after.png`
5. Record result:

| AC | Action | Expected | Actual | Screenshot | PASS/FAIL |
|----|--------|----------|--------|------------|-----------|

## Check mobile UX
For EACH affected page:
- [ ] Touch targets >= 44x44px
- [ ] No horizontal overflow
- [ ] Text readable (>= 12px)
- [ ] Key actions visible without scrolling

## Report
Write to: .claude/nightshift/issue-<N>/06-qa.md

If ALL ACs pass:
  ORCHESTRATOR_SUMMARY: QA PASSED — X/X ACs verified with screenshots

If ANY AC fails:
  ORCHESTRATOR_SUMMARY: QA FAILED — X/Y ACs passed. Bugs: <list of failed ACs with 1-line description each>
```

## After QA Agent Returns

**If QA PASSED:**
- Verify `06-qa.md` exists: `ls .claude/nightshift/issue-<N>/06-qa.md`
- Verify screenshots exist: `ls .claude/nightshift/issue-<N>/screenshots/`
- Proceed to Step 7 (SHIP)

**If QA FAILED:**
- Read the bug report from `06-qa.md`
- Loop back to Step 4 (CODE) with the bug report as input:

```
PREVIOUS QA FAILED (loop <M>/3).

Bug report from QA:
<paste failed ACs from 06-qa.md>

Screenshots showing bugs: .claude/nightshift/issue-<N>/screenshots/

Fix these bugs. Do NOT change anything that's already working.
After fixing, the pipeline will re-run VERIFY (step 5) and QA (step 6).
```

- Run Step 4 (CODE) → Step 5 (VERIFY) → Step 6 (QA) again
- Max 3 QA→CODE loops. After 3 failures → mark issue BLOCKED with bug report + screenshots

## State Tracking

```json
"6": {
  "status": "in_progress",
  "attempts": 0,
  "maxAttempts": 3,
  "qaLoops": 1,
  "lastResult": "qa_failed"
}
```

## No Review Gate for QA

QA is its own quality gate — the QA agent's pass/fail IS the gate.
- QA PASSED → proceed to SHIP
- QA FAILED → loop back to CODE
- No additional reviewer agents needed (the QA agent IS the reviewer)
