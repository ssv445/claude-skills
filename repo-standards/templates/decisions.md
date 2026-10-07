# Decisions — #<issue> <title>

The process record for this issue. The pre-push hook requires `## Spec gate` and `## Plan gate` with `Verdict: PASS`; `bin/ship` requires `## Pre-merge gate` with `Verdict: PASS`.

## Spec gate
- Reviewer A: <PASS | FAIL> — <key points>
- Reviewer B: <PASS | FAIL> — <key points>
- Arbiter (only on disagreement): <ruling and why>
- Owner answers to [inferred] lines: <line → answer → doc it was written back to>
Verdict: PENDING

## Plan gate
- Reviewer A:
- Reviewer B:
- Arbiter:
Verdict: PENDING

## Decisions
- <choice> — chosen because <why>; rejected <alternative> because <why>.

## Exceptions
One line each, starting at column 0, accepted at the pre-merge gate. Format (indented here so it is not itself an exception):

    TDD: N/A — <reason>
    docs-unchanged: <doc path> — <reason>

## Pre-merge gate
- Reviewer A:
- Reviewer B:
- Arbiter:
Verdict: PENDING
