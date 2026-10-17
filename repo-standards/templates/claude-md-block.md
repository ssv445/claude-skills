<!-- repo-standards:begin -->
## Repo standards (installed — enforced by hooks)

This repo follows `docs/guidelines/repo-standards.md`. **Read it before starting any issue**; it defines the pipeline every change goes through: issue → spec (with Expectations) → spec gate → plan → plan gate → tests red → code → verify → doc sync → pre-merge gate → `bin/ship`. A docs-only branch (no gate file, nothing in `BEHAVIOR_DOCS_GLOBS`) skips spec, plan and TDD: issue → edit → pre-merge gate → `bin/ship`.

Only the text between the `repo-standards` markers is a gate file; the rest of this file is facts any PR may edit. Rules belong inside the markers: an `@path` import line anywhere in this file counts as a gate change, and reviewers flag rule-like text added outside the block.

Hard rules (the hooks back these up; treat a red hook as a stop, not an obstacle):
- Every change starts from a GitHub issue; branch `<type>/<issue>-<slug>`.
- Per-issue files live in `docs/work/<issue>-<slug>/`: `spec.md`, `decisions.md`.
- Merge only through `bin/ship`. Hooks run on every push; bypassing them (`--no-verify`, changing `core.hooksPath`, disabling the hook manager) is never an option — fix the cause.
- The gates are how you decide for yourself whether to approve and ship. When every gate passes, run `bin/ship` — it approves and merges without the owner. Owner needed only when `bin/ship` says so: the cases listed under "Approval and shipping" in the rulebook. `APPROVER` in `.standards/config.sh` (read from the base branch) sets who approves gate-file changes and blast-radius specs: `"agent"` (default) or `"owner"` — in agent mode you approve those too, and only `owner-review` flags go to the owner. Never change `APPROVER` on your own branch; it is the owner's setting.
- In agent mode a gate-file change also needs a line appended to `docs/rule-changes.md` and `## Gate-change review` in `decisions.md`.
- `approved` / `spec-approved` labels are the owner's alone, added via `bin/approve` at a terminal. Never edit gate files, or rephrase commands, to get past `bin/ship` or the guard.
- **Decide and log; the owner reads and reverts.** Every taste, product, idea, roadmap or inferred-Expectations call you can make: pick your recommended option, record it (and the alternative you rejected) in `decisions.md` — or `docs/product/` for ideas and roadmap — and keep going. Mechanical calls: decide, record. Never wait for the owner on these.
- **Big calls — the one list, every rule points here:** a price, a public claim or pitch, a new screen or visual design, anything that costs money, or a change that loosens a check. Only these go to the owner: add this exact line, at column 0, to `decisions.md`: `owner-review: required — <reason>`, and ask in the PR or issue.
- Once the owner answers, replace that line with `owner-review: answered — <reason as in the flag> — <link to the owner's answer> — <the answer, quoted>` (one per flag, in `decisions.md` or `spec.md`) and write the answer into the doc it belongs in. That closes it; no `bin/approve`. Never delete a flag any other way, and never write an answer the owner did not give.
- Asking the owner: name the exact rule that requires them, and give the one command or question. Then keep working on everything that does not depend on the answer — prep, plans, other issues. Stop only when the next step needs their input.
- An idea that is not today's work goes into the Inbox of `docs/product/roadmap.md` at once; then you weigh it against `docs/product/goals.md`, apply add, merge or reject, and log why.
- An issue you file at the owner's explicit instruction counts as owner-filed.

### Your steps (owner)
With `APPROVER="agent"` (default): answer `owner-review: required` questions in the PR or issue (and say "merge" in repos without `bin/ship`). Nothing else waits on you. Read `docs/product/` and `docs/rule-changes.md` when you choose; revert what you disagree with.

With `APPROVER="owner"`, also:
- `bin/approve --spec <issue>` for a spec with `owner-approval: required`.
- `bin/approve <pr>` for a PR `bin/ship` refuses for a gate-file change or a removed `owner-approval` flag.
<!-- repo-standards:end -->
