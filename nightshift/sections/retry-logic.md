# Retry Logic

## Retry Limits

| Step | Name | Max Retries |
|------|------|-------------|
| 1 | UNDERSTAND | 2 |
| 2 | PLAN | 3 |
| 3 | TEST | 5 |
| 4 | CODE | 7 |
| 5 | VERIFY | 5 |
| 6 | SHIP | 1 |

## Ralph Loop (Retry on Rejection)

When review gate rejects:

```
step_max = maxAttempts for this step
attempt = current_attempt + 1

if attempt > step_max:
    mark issue BLOCKED
    gh issue comment <N> --body "## Nightshift — BLOCKED

    **Blocked at:** Step <STEP> (<STEP_NAME>)
    **Attempts:** <step_max>/<step_max> exhausted
    **Last feedback:**
    - <reviewer1>: <feedback>
    - <reviewer2>: <feedback>
    - <reviewer3>: <feedback>

    **Expert panel consulted:** <yes/no>
    **Suggested resolution:** <what human should do>

    Full artifacts: .claude/nightshift/issue-<N>/"

    git checkout $NIGHTSHIFT_BRANCH  # return to parent
    move to next issue
else:
    gh issue comment <N> --body "## Nightshift — Step <STEP> Retry (attempt <attempt>/<step_max>)
    Reviewer feedback being addressed:
    - <reviewer1>: <feedback>
    - <reviewer2>: <feedback>
    - <reviewer3>: <feedback>"

    re-run worker with enhanced prompt:

    "PREVIOUS ATTEMPT REJECTED (attempt <attempt>/<step_max>).

    Reviewer feedback:
    - <reviewer1>: <feedback>
    - <reviewer2>: <feedback>
    - <reviewer3>: <feedback>

    Read issue comments for full history: gh issue view <N> --comments

    CRITICAL: Do not assume previous approach was close.
    Re-examine evidence. If reviewers said root cause was wrong,
    investigate again — don't tweak the fix.

    Fix issues above. Read previous output at
    .claude/nightshift/issue-<N>/<step-file>.md and improve.

    <original step prompt>"
```

## Anti-Loop Protection

Before any retry:
1. Read previous attempt output + rejection feedback
2. Read ALL issue comments for full history
3. Same feedback as previous rejection → worker is looping
4. Loop detected → **expert panel**: "Worker keeps failing same issue. Feedback: <feedback>. Tried: <attempts>. Comments: <history>. Right approach?"
5. Apply panel decision to next retry
6. Post panel decision as issue comment
7. Max retries exhausted after panel help → BLOCKED
