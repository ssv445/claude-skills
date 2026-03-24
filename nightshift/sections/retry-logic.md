# Retry Logic

## Retry Limits Per Step

Different steps need different amounts of iteration. Harder steps get more retries.

| Step | Name | Max Retries | Rationale |
|------|------|-------------|-----------|
| 1 | UNDERSTAND | 2 | Low complexity — if you can't understand after 2 retries, it's a bad issue |
| 2 | PLAN | 3 | Medium — plans can be refined |
| 3 | TEST | 5 | High — writing good tests is iterative |
| 4 | CODE | 7 | Highest — implementation has the most failure modes |
| 5 | VERIFY | 5 | High — fixing lint/type/test/build failures is iterative |
| 6 | SHIP | 1 | Just push and PR — if this fails it's a git/gh issue, ask expert panel |

## Ralph Loop Logic (Retry on Rejection)

When a review gate rejects a step:

```
step_max = maxAttempts for this step (from the retry limits table)
attempt = current_attempt + 1

if attempt > step_max:
    mark issue as BLOCKED
    # Post detailed blocking comment on the issue
    gh issue comment <N> --body "## Nightshift — BLOCKED

    **Blocked at:** Step <STEP> (<STEP_NAME>)
    **Attempts:** <step_max>/<step_max> exhausted
    **Last feedback:**
    - <reviewer1>: <feedback>
    - <reviewer2>: <feedback>
    - <reviewer3>: <feedback>

    **Expert panel consulted:** <yes/no>
    **Suggested resolution:** <what you think a human should do>

    Full artifacts: .claude/nightshift/issue-<N>/"

    git checkout $NIGHTSHIFT_BRANCH  # return to parent branch
    move to next issue
else:
    # Post retry comment on the issue
    gh issue comment <N> --body "## Nightshift — Step <STEP> Retry (attempt <attempt>/<step_max>)
    Reviewer feedback being addressed:
    - <reviewer1>: <feedback>
    - <reviewer2>: <feedback>
    - <reviewer3>: <feedback>"

    re-run the worker agent with enhanced prompt:

    "PREVIOUS ATTEMPT REJECTED (attempt <attempt>/<step_max>).

    Reviewer feedback:
    - <reviewer1>: <feedback>
    - <reviewer2>: <feedback>
    - <reviewer3>: <feedback>

    Read the issue comments for full history: gh issue view <N> --comments

    CRITICAL: Do not assume your previous approach was close.
    Re-examine the evidence. If reviewers said your root cause analysis
    was wrong, go back and investigate again — don't just tweak the fix.

    Fix the issues raised above and try again.
    Read your previous output at .claude/nightshift/issue-<N>/<step-file>.md
    and improve it based on the feedback.

    <original step prompt>"
```

## Anti-Loop Protection

Before starting any retry:
1. Read previous attempt's output and the rejection feedback
2. Read ALL issue comments to see the full history of attempts
3. If feedback is about the SAME issue as previous rejection → worker is looping
4. On loop detection: **convene expert panel** with the dilemma:
   "The worker keeps failing on the same issue. Here's the feedback: <feedback>.
   Here's what was tried: <previous attempts>.
   Here's the issue comment history: <comments>.
   What's the right approach?"
5. Apply the panel's decision to the next retry prompt
6. Post the expert panel decision as an issue comment
7. If max retries exhausted after expert panel help → BLOCKED
