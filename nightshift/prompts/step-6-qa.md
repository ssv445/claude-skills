# Step 6: QA — Browser Functional Testing

**Max retries: 3 (QA→CODE loops, not internal retries)**

**Runs when:** `UI Impact: yes` in `01-understand.md`. Skipped for API-only.

**Role:** QA tester. Open browser, test as real user. NEVER write code. Find bugs → report → CODE agent fixes.

## QA Agent (subagent_type: `general-purpose`)

```
Prompt: QA tester for issue #<N>. Open browser, test every AC.
You NEVER write/edit code. Only test, screenshot, report.

**MANDATORY OUTPUT FILE:** .claude/nightshift/issue-<N>/06-qa.md

Read:
- Issue ACs: `gh issue view <N> --json body`
- UI Impact: `.claude/nightshift/issue-<N>/01-understand.md`
- What was built: `.claude/nightshift/issue-<N>/04-code.md`

## Setup
1. Ensure dev servers running:
   - API: `curl -s http://api.ecomitram.localhost:1355/health`
   - Web: `curl -s http://ecomitram.localhost:1355/feed`
   - Not running → start both (background), wait for ready
2. Seed: `pnpm --filter @ecomitram/api seed`
3. Mobile viewport: 412x915

## Test EVERY AC
For EACH AC:
1. Navigate to page
2. Screenshot BEFORE → `screenshots/ac<N>-before.png`
3. Perform user action
4. Screenshot AFTER → `screenshots/ac<N>-after.png`
5. Record:

| AC | Action | Expected | Actual | Screenshot | PASS/FAIL |
|----|--------|----------|--------|------------|-----------|

## Mobile UX checks per page
- [ ] Touch targets >= 44x44px
- [ ] No horizontal overflow
- [ ] Text >= 12px
- [ ] Key actions visible without scrolling

## Report → .claude/nightshift/issue-<N>/06-qa.md

ALL pass:
  ORCHESTRATOR_SUMMARY: QA PASSED — X/X ACs verified with screenshots

ANY fail:
  ORCHESTRATOR_SUMMARY: QA FAILED — X/Y ACs passed. Bugs: <failed ACs, 1-line each>
```

## After QA Returns

**QA PASSED:**
- Verify `06-qa.md` exists: `ls .claude/nightshift/issue-<N>/06-qa.md`
- Verify screenshots: `ls .claude/nightshift/issue-<N>/screenshots/`
- Proceed to Step 7

**QA FAILED:**
- Read bug report from `06-qa.md`
- Loop back to Step 4 (CODE):

```
PREVIOUS QA FAILED (loop <M>/3).

Bug report from QA:
<failed ACs from 06-qa.md>

Screenshots: .claude/nightshift/issue-<N>/screenshots/

Fix bugs. Do NOT change working code.
Pipeline re-runs VERIFY (5) and QA (6) after.
```

- Run Step 4→5→6 again. Max 3 loops → BLOCKED with bug report + screenshots

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

## No Review Gate

QA is its own gate — pass/fail IS the gate.
- PASSED → SHIP
- FAILED → loop to CODE
