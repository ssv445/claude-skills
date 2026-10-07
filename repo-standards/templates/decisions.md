# Decisions — #<issue> <title>

The process record for this issue. The pre-push hook requires `## Spec gate` and `## Plan gate` with `Verdict: PASS`; `bin/ship` requires `## Pre-merge gate` with `Verdict: PASS`, and approves on its own when both pre-merge reviewers say `PASS` (or exactly one does and the arbiter does), `Reviewed:` names (as a hex sha) the commit they read and every file the branch changes is the same at HEAD as there (this file aside), and no owner review is flagged.

To hand a taste or product call to the owner, add a line at column 0 anywhere in this file (indented here so it is not itself a flag); `bin/ship` then waits for the owner's `approved` label:

    owner-review: required — <reason>

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
- Reviewer A: <PASS | FAIL> — <key points>
- Reviewer B: <PASS | FAIL> — <key points>
- Arbiter: <PASS | FAIL> — <ruling and why; only on disagreement>
Reviewed: <hex sha of the commit the reviewers read; never HEAD or a branch name>
Verdict: PENDING
