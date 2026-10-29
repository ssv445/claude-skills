---
name: repo-standards
description: "Install the agentic repo standards (spec + Expectations, adversarial review with arbiter, TDD red→green, doc-map, architecture owner map, prod-shaped seeds, decision log, goals + dependency-aware roadmap, pre-push / pre-merge hooks) into a repo. Use when creating a new repo, when asked to set up or apply repo standards, or when a repo lacks them and the user agrees to add them."
---

# Repo Standards — installer

Installs a rulebook plus local enforcement into ONE repo. Opt-in per repo: never install without the user asking. Once installed, the repo's hooks enforce it; this skill is no longer needed to run it.

The installed rules exist so that AI agents decide for themselves whether to approve and ship: when every gate passes, `bin/ship` approves and merges with no owner in the loop; with `APPROVER="owner"` (default in `.standards/config.sh`) the owner is needed only for gate-file changes, `owner-review: required` flags, an owner flag removed on the branch, and `spec-approved` on blast-radius specs; with `APPROVER="agent"` agents approve all of those too — a gate-file change after an extra gate-change review and one plain-English line in `docs/rule-changes.md` — and the owner only answers `owner-review: required` flags and reads that log.

What gets installed (sources in this skill folder):

| Source | Installed at | Purpose |
|---|---|---|
| `templates/repo-standards.md` | `docs/guidelines/repo-standards.md` | The rulebook agents follow per issue |
| `templates/claude-md-block.md` | appended to `CLAUDE.md` (`AGENTS.md` symlinked to it) | Always-loaded pointer + hard rules |
| `templates/spec.md`, `templates/decisions.md`, `templates/adr.md` | `docs/templates/` | Per-issue spec, decision log, ADR |
| `templates/architecture.md` | `docs/guidelines/architecture.md` | Target structure: modules, one owner per fact, outbound calls, drift log |
| `templates/product/{goals,assumptions,stack,roadmap,ideas-rejected}.md` | `docs/product/` | Goals, assumptions, tool stack, dependency-aware roadmap |
| `templates/product/review.md` | `docs/templates/review.md` | Monthly product review |
| `templates/doc-map.txt` | `docs/doc-map.txt` | Code path → doc that must change with it |
| `templates/rule-changes.md` | `docs/rule-changes.md` | Owner's log of rule changes, one line each, append only |
| `templates/seed-profile.md` | `docs/seed-profile.md` | Aggregate-only prod shape for seed generation |
| `templates/github/` | `.github/` | Issue form + PR template (evidence table on top) |
| `scripts/` | `.standards/` | Hooks, gate checks, `config.sh`; `.standards/.gitignore` keeps local run state (`.standards/state/`: result cache, chain results) out of git |
| `scripts/bin/ship`, `scripts/bin/approve` | `bin/ship`, `bin/approve` | Only merge path — agent-approved when every gate and `agent-approval.sh` pass; owner-only `approved` override and `--maintenance` mode |
| `scripts/bin/chain`, `scripts/bin/preflight` | `bin/chain`, `bin/preflight` | Pre-push checks then `bin/ship` back to back, result in `.standards/state/chain-<pr>.txt`; release pre-flight, PASS/FAIL per `PREFLIGHT_CHECKS` item |
| `templates/claude-settings.json` | merged into `.claude/settings.json` | Guard hook blocking gate bypass |

## Steps

1. **Survey.** Read the repo's `CLAUDE.md`, package manifests, test runner configs, existing hooks (`.husky/`, `core.hooksPath`), existing `docs/`. Done when you can name: language/stack, lint, typecheck, unit-test, coverage, e2e, perf commands (or that one is missing), the hook manager in use, and the GitHub owner login.
2. **Branch.** Work on `chore/<issue>-repo-standards` (open the issue first; this install is itself an issue). Never on main.
3. **Copy** every row of the table above. Existing files with the same path: merge, never overwrite — show the user the conflict if a merge is not obvious. On an upgrade, merge new template sections (such as `## Architecture impact` in `spec.md`) into the repo's copies; specs written before a gate reached the base branch are skipped by it.
4. **Fill `.standards/config.sh`.** Every command variable set to a real command or left empty with a `# N/A — reason` comment. Empty `UNIT_CMD` or `DIFF_COVERAGE_CMD` is not allowed when the repo has source code: add the tooling instead (e.g. vitest/jest coverage + `diff-cover` for lcov/cobertura). Ask the owner for `APPROVER` (`owner` or `agent`); leave the default `owner` if they don't say. A repo with separate parts (app, site, packages): define `TEST_CLASSES` with each class's paths — everything its tests depend on — and commands, plus `IGNORE_PATHS` for trivial edits such as a version string; then schedule a full run of the base branch nightly and before each release (e.g. a dispatcher job) — required, since classes and the cache skip tests. Set `CMD_TIMEOUT` above the slowest command's normal time, `HEAVY_LOCK` if the repo serializes heavy jobs with a lock file, and `PREFLIGHT_CHECKS` from the repo's release steps.
5. **Wire hooks.**
   - No hook manager: `git config core.hooksPath .standards/hooks`, and add that line to the repo's setup script / README setup section (it is per-clone).
   - Husky or similar: add a `pre-push` entry that runs `.standards/hooks/pre-push`; leave the manager in charge.
6. **Product context.** Interview the owner, one question at a time, for goals (metric, target, date), non-goals, known assumptions, and the tool stack; fill `docs/product/`. On an existing repo, draft from what the code and docs already show and ask only for the gaps. Anything the owner shares that is future work goes to the roadmap Inbox, then through the idea flow in the rulebook.
7. **Fill the doc map, seed profile and architecture doc** from what the survey found. Architecture doc: draft units, modules, owners, outbound calls and connections from the code as it is today; any fact with two writers goes in its `## Drift checks` as the first gap, not hidden in the tables. Doc map: one line per code area that has a describing doc. Seed profile: fields marked `TODO(owner)` where only prod knowledge can answer — list them for the user.
8. **Prove every gate can fail.** On a scratch branch, break each gate once (uncovered line, source change with no test, mapped code without its doc, missing decision-log section, failing lint, roadmap item with no goal, spec declaring an owner change without the architecture doc) and show the hook output for each failing, then passing after the fix. With test classes: a class skipped when its paths are untouched and run when they change; a cache hit after a rebase onto an unrelated base change, and a miss once a class file changes. A command that hangs past a short `CMD_TIMEOUT` fails its gate. `bin/preflight` exits non-zero on one failing item. A gate you could not make fail is not installed — say so.
9. **Report** to the user: what was installed, config values, gates proven (with output), anything left `TODO(owner)` or N/A, the `APPROVER` mode, and the owner's own steps from "Your steps (owner)" in the rulebook. Owner mode: `bin/approve --spec <issue>` for `owner-approval: required` specs; `bin/approve <pr>` for PRs `bin/ship` refuses (gate-file change, `owner-review` flag); answering `owner-review` flags; saying "merge" in repos without `bin/ship`. Agent mode: only answering `owner-review` flags, reading `docs/rule-changes.md` for rule changes (and "merge" where there is no `bin/ship`). Either mode: `bin/approve --maintenance <pr>` for a standards-only PR that should skip the test gates. Open the PR; the owner merges it — on first install there is no `bin/ship` on the base yet, and an upgrade is judged by the base's older rules.

## Rules for this skill

- Lean: pre-push must stay ≤ 2 min on this repo. Measure it in step 8; if over, move the slowest check to `bin/ship` and say so.
- The rulebook template is the single source of truth. Repo-specific additions go in the repo's own guidelines, not by editing the installed rulebook — so a later re-install can diff cleanly.
- Self-test of the scripts lives in `tests/run.sh` in this skill folder; run it after changing any script.
