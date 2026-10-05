## Repo standards (installed — enforced by hooks)

This repo follows `docs/guidelines/repo-standards.md`. **Read it before starting any issue**; it defines the pipeline every change goes through: issue → spec (with Expectations) → spec gate → plan → plan gate → tests red → code → verify → doc sync → pre-merge gate → owner approval → `bin/ship`.

Hard rules (the hooks back these up; treat a red hook as a stop, not an obstacle):
- Every change starts from a GitHub issue; branch `<type>/<issue>-<slug>`.
- Per-issue files live in `docs/work/<issue>-<slug>/`: `spec.md`, `decisions.md`.
- Merge only through `bin/ship`. Hooks run on every push; bypassing them (`--no-verify`, changing `core.hooksPath`, disabling the hook manager) is never an option — fix the cause.
- `approved` / `spec-approved` labels are the owner's alone, added via `bin/approve` at a terminal. Ask; wait.
- Taste and product calls go to the owner. Mechanical calls: decide, record in `decisions.md`.
