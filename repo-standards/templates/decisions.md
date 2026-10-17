# Decisions — #<issue> <title>

The process record for this issue. The pre-push hook requires `## Spec gate` and `## Plan gate` with `Verdict: PASS` — except on a docs-only branch (touches docs and nothing else; not a gate file, not `BEHAVIOR_DOCS_GLOBS`), where they may stay as this template has them and no `TDD: N/A` line is needed. `bin/ship` requires `## Pre-merge gate` with `Verdict: PASS` on every branch, and `## Gate-change review` too when a gate file changed under `APPROVER="agent"`. When `bin/ship` approves on its own, and when it needs the owner: "Approval and shipping" in `docs/guidelines/repo-standards.md`.

Taste and product calls: pick the recommended option and log it under `## Decisions`. Only a big call (the list in the repo-standards block of `CLAUDE.md`) goes to the owner: add a line at column 0 anywhere in this file (indented here so it is not itself a flag); `bin/ship` refuses while it is open:

    owner-review: required — <reason>

Once the owner answers in the PR or issue, replace that line with this one: the flag's reason as written, the real link, their words. It closes that one flag — no `bin/approve`. Each flag needs its own answered line:

    owner-review: answered — <reason as in the flag> — <link to the owner's answer> — <the answer, quoted>

## Spec gate
- Reviewer A: <PASS | FAIL> — <key points>
- Reviewer B: <PASS | FAIL> — <key points>
- Arbiter (only on disagreement): <ruling and why>
- [inferred] lines resolved: <line → [sourced: where] or [decided: reason] → doc it was written to>
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

    TDD: N/A — <reason>        (only for a source change with no test)
    docs-unchanged: <doc path> — <reason>

## Pre-merge gate
- Reviewer A: <PASS | FAIL> — <key points>
- Reviewer B: <PASS | FAIL> — <key points>
- Arbiter: <PASS | FAIL> — <ruling and why; only on disagreement>
Reviewed: <hex sha of the commit the reviewers read; never HEAD or a branch name>
Verdict: PENDING

## Gate-change review
Only when the branch changes a gate file under `APPROVER="agent"` (list: "Approval and shipping" in the rulebook). First append the owner's line to `docs/rule-changes.md`: `- YYYY-MM-DD #<issue> — <what the rules now do differently, and why>`, plain words, no file-level detail. Then two more independent reviewers, given the diff of the gate files and that line and nothing else, answer: does this weaken, skip or bypass any check, or widen what agents may do without the owner? Does the line say so plainly and accurately? Either wrong → FAIL; when loosening is the point, raise the owner-review flag shown at the top of this file.
- Reviewer A: <PASS | FAIL> — <key points>
- Reviewer B: <PASS | FAIL> — <key points>
- Arbiter: <PASS | FAIL> — <ruling and why; only on disagreement>
Reviewed: <hex sha of the commit the reviewers read; never HEAD or a branch name>
Verdict: PENDING
