## Repo standards (installed — enforced by hooks)

This repo follows `docs/guidelines/repo-standards.md`. **Read it before starting any issue**; it defines the pipeline every change goes through: issue → spec (with Expectations) → spec gate → plan → plan gate → tests red → code → verify → doc sync → pre-merge gate → `bin/ship`.

Hard rules (the hooks back these up; treat a red hook as a stop, not an obstacle):
- Every change starts from a GitHub issue; branch `<type>/<issue>-<slug>`.
- Per-issue files live in `docs/work/<issue>-<slug>/`: `spec.md`, `decisions.md`.
- Merge only through `bin/ship`. Hooks run on every push; bypassing them (`--no-verify`, changing `core.hooksPath`, disabling the hook manager) is never an option — fix the cause.
- The gates are how you decide for yourself whether to approve and ship. When every gate passes, run `bin/ship` — it approves and merges without the owner. Owner needed only when `bin/ship` says so: the cases listed under "Approval and shipping" in the rulebook. `APPROVER` in `.standards/config.sh` (read from the base branch) sets who approves gate-file changes and blast-radius specs: `"owner"` (default) or `"agent"` — in agent mode you approve those too, and only `owner-review` flags go to the owner. Never change `APPROVER` on your own branch; it is the owner's setting.
- In agent mode a gate-file change also needs a line appended to `docs/rule-changes.md` and `## Gate-change review` in `decisions.md`.
- `approved` / `spec-approved` labels are the owner's alone, added via `bin/approve` at a terminal. Never edit gate files, or rephrase commands, to get past `bin/ship` or the guard.
- Asking the owner: name the exact rule that requires them (e.g. "this PR changes gate files"), and give the one command to run. Then keep working on everything that does not depend on the answer — prep, plans, other issues. Stop only when the next step needs their input.
- An idea that is not today's work goes into the Inbox of `docs/product/roadmap.md` at once, then is checked against `docs/product/goals.md` before it becomes an item.
- Taste and product calls go to the owner: add this exact line, at column 0, to `decisions.md`: `owner-review: required — <reason>`. Never remove one; only the owner resolves it. Mechanical calls: decide, record in `decisions.md`.

### Your steps (owner)
With `APPROVER="agent"`: answer `owner-review: required` flags (and say "merge" in repos without `bin/ship`). Nothing else.

With `APPROVER="owner"` (default), only these need you; agents never do them:
- `bin/approve --spec <issue>` for a spec with `owner-approval: required`.
- `bin/approve <pr>` for a PR `bin/ship` refuses (gate-file change, `owner-review` flag).
- Answer `owner-review: required` flags.
- Say "merge" for PRs in repos without `bin/ship`; the agent merges.
