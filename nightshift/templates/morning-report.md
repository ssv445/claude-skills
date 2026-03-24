# Nightshift Report — <date>

## Summary
- Nightshift branch: `nightshift/<date>`
- Issues processed: <N>
- Issues completed & merged: <N>
- Issues blocked: <N>
- Expert panel decisions made: <N>
- Total reviewer agents spawned: <N>
- Total issue comments posted: <N>

## Final PR
<url of nightshift/<date> → main PR>

## Closes
<!-- REQUIRED: GitHub auto-close keywords for all completed issues -->
Closes #50, closes #51, closes #52

## Issues

### #50 — <title> ✓
- Status: completed, merged to nightshift/<date>
- Branch: feat/50-<slug> (squash merged)
- Retries: step1=0/2, step2=1/3, step3=0/5, step4=2/7, step5=0/5
- Expert panels: 1 (architecture decision at step 4)
- Browser tests: 3 passed
- Screenshots: 5 captured
- Issue comments: 8 posted
- Notable: <interesting decisions or root cause findings>

### #51 — <title> ✗
- Status: BLOCKED at step 4 (code) after 7 attempts
- Reason: <summary>
- Root cause investigation: <what was found>
- Last feedback: <what reviewers said>
- Expert panel tried: yes, recommended X but still failed
- **Needs human attention**

## Expert Panel Decisions
1. Issue #50, Step 4: "Should we use middleware or guard?" → guard (2/3), logged in issue comment
2. ...

## Evidence Index
All evidence is in issue comments AND local artifacts:
- Issue #50: 8 comments with test outputs, 5 screenshots
- Issue #51: 12 comments with investigation logs, 2 expert panel records

## Review Statistics
- Total review gates: <N>
- Passed first try: <N> (<percent>%)
- Required retry: <N>
- Max retries on single step: <N> (issue #<N>, step <N>)

## Browser Testing Summary
- Playwright tests run: <N>
- Manual Chrome verifications: <N>
- Screenshots captured: <N> (in .claude/nightshift/issue-*/screenshots/)

## Post-Merge Health
- Nightshift branch builds: yes/no (with evidence)
- All tests pass on nightshift branch: yes/no (<N> passed, <N> failed)

## Blocked Issues (need human attention)
- #<N>: blocked at step <step>, reason: <summary>
  Root cause investigation: <what was found>
  Suggested action: <what you think the human should do>
  Issue comments: <count> — read the issue for full context
