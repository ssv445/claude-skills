## Repo standards (installed — enforced by hooks)

This repo follows `docs/guidelines/repo-standards.md`. **Read it before starting any issue**; it defines the pipeline every change goes through: issue → spec (with Expectations) → spec gate → plan → plan gate → tests red → code → verify → doc sync → pre-merge gate → `bin/ship`.

Hard rules (the hooks back these up; treat a red hook as a stop, not an obstacle):
- Every change starts from a GitHub issue; branch `<type>/<issue>-<slug>`.
- Per-issue files live in `docs/work/<issue>-<slug>/`: `spec.md`, `decisions.md`.
- Merge only through `bin/ship`. Hooks run on every push; bypassing them (`--no-verify`, changing `core.hooksPath`, disabling the hook manager) is never an option — fix the cause.
- The gates are how you decide for yourself whether to approve and ship. When every gate passes, run `bin/ship` — it approves and merges without the owner. Owner needed only when `bin/ship` says so: a gate file changed (`bin/`, `.standards/`, `.claude/`, `.github/`, `CLAUDE.md`, `AGENTS.md`, `docs/doc-map.txt`, the rulebook), an owner-review flag in `decisions.md`, or a blast-radius spec without `spec-approved`.
- `approved` / `spec-approved` labels are the owner's alone, added via `bin/approve` at a terminal. Ask; wait. Never edit gate files to get past `bin/ship`.
- An idea that is not today's work goes into the Inbox of `docs/product/roadmap.md` at once, then is checked against `docs/product/goals.md` before it becomes an item.
- Taste and product calls go to the owner: add this exact line, at column 0, to `decisions.md`: `owner-review: required — <reason>`. Never remove one; only the owner resolves it. Mechanical calls: decide, record in `decisions.md`.
