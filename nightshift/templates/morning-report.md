# Nightshift Report — <date>

## Summary
- Branch: `nightshift/<date>`
- Processed: <N> | Completed: <N> | Blocked: <N>
- Expert panels: <N> | Reviewers spawned: <N> | Comments posted: <N>

## Final PR
<url of nightshift/<date> → main PR>

## Closes
<!-- REQUIRED: GitHub auto-close for all completed issues -->
Closes #50, closes #51, closes #52

## Issues

### #50 — <title> ✓
- Merged: feat/50-<slug> (squash)
- Retries: step1=0/2, step2=1/3, step3=0/5, step4=2/7, step5=0/5
- Expert panels: 1 (architecture at step 4)
- Browser tests: 3 passed | Screenshots: 5
- Comments: 8
- Notable: <decisions or root cause findings>

### #51 — <title> ✗
- BLOCKED at step 4 (code) after 7 attempts
- Reason: <summary>
- Root cause: <what was found>
- Last feedback: <reviewer said>
- Expert panel tried: yes, recommended X, still failed
- **Needs human attention**

## Expert Panel Decisions
1. Issue #50, Step 4: "middleware or guard?" → guard (2/3)
2. ...

## Evidence Index
- Issue #50: 8 comments, 5 screenshots
- Issue #51: 12 comments, 2 panel records

## Review Statistics
- Total gates: <N> | First-try pass: <N> (<percent>%) | Required retry: <N>
- Max retries single step: <N> (issue #<N>, step <N>)

## Browser Testing Summary
- Playwright: <N> | Chrome manual: <N> | Screenshots: <N>

## Post-Merge Health
- Build: yes/no (evidence)
- Tests: yes/no (<N> passed, <N> failed)

## Blocked Issues (need human attention)
- #<N>: blocked at step <step>, reason: <summary>
  Root cause: <what was found>
  Suggested action: <what human should do>
  Comments: <count> — read issue for full context
