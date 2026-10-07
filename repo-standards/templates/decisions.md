# Decisions — #<issue> <title>

The process record for this issue. The pre-push hook requires `## Spec gate` and `## Plan gate` with `Verdict: PASS`; `bin/ship` requires `## Pre-merge gate` with `Verdict: PASS`, and `## Gate-change review` too when a gate file changed. When `bin/ship` approves on its own, and when it needs the owner: "Approval and shipping" in `docs/guidelines/repo-standards.md`.

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

## Gate-change review
Only when the branch changes a gate file (list: "Approval and shipping" in the rulebook). Two more independent reviewers, given the diff of the gate files and nothing else, answer one question: does this weaken, skip or bypass any check, or widen what agents may do without the owner? Yes → FAIL; when loosening is the point, raise the owner-review flag shown at the top of this file. The Summary goes to the owner after the merge: plain words, no file-level detail.
- Reviewer A: <PASS | FAIL> — <key points>
- Reviewer B: <PASS | FAIL> — <key points>
- Arbiter: <PASS | FAIL> — <ruling and why; only on disagreement>
Reviewed: <hex sha of the commit the reviewers read>
Summary: <one or two sentences for the owner: what the rules now do differently, and why>
Verdict: PENDING
