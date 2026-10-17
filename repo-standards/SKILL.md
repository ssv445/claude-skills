---
name: repo-standards
description: "Install the agentic repo standards (spec + Expectations, adversarial review with arbiter, TDD red→green, doc-map, prod-shaped seeds, decision log, goals + dependency-aware roadmap, pre-push / pre-merge hooks) into a repo. Use when creating a new repo, when asked to set up or apply repo standards, or when a repo lacks them and the user agrees to add them."
---

# Repo Standards — installer

Installs a rulebook plus local enforcement into ONE repo. Opt-in per repo: never install without the user asking. Once installed, the repo's hooks enforce it; this skill is no longer needed to run it.

The installed rules exist so that AI agents decide for themselves whether to approve and ship: when every gate passes, `bin/ship` approves and merges with no owner in the loop; with `APPROVER="agent"` (default in `.standards/config.sh`) agents also approve gate-file changes and blast-radius specs — a gate-file change after an extra gate-change review and one plain-English line in `docs/rule-changes.md` — and the owner only answers `owner-review: required` questions on big calls (the agent closes each flag as answered) and reads what agents decided and logged; with `APPROVER="owner"` the owner also approves gate-file changes (`bin/approve <pr>`) and blast-radius specs (`spec-approved`).

What gets installed (sources in this skill folder):

| Source | Installed at | Purpose |
|---|---|---|
| `templates/repo-standards.md` | `docs/guidelines/repo-standards.md` | The rulebook agents follow per issue |
| `templates/claude-md-block.md` | appended to `CLAUDE.md` between its markers (`AGENTS.md` symlinked to it) | Always-loaded pointer + hard rules; only this block is a gate file |
| `templates/spec.md`, `templates/decisions.md`, `templates/adr.md` | `docs/templates/` | Per-issue spec, decision log, ADR |
| `templates/product/{goals,assumptions,stack,roadmap,ideas-rejected}.md` | `docs/product/` | Goals, assumptions, tool stack, dependency-aware roadmap |
| `templates/product/review.md` | `docs/templates/review.md` | Monthly product review |
| `templates/doc-map.txt` | `docs/doc-map.txt` | Code path → doc that must change with it |
| `templates/rule-changes.md` | `docs/rule-changes.md` | Owner's log of rule changes, one line each, append only |
| `templates/seed-profile.md` | `docs/seed-profile.md` | Aggregate-only prod shape for seed generation |
| `templates/github/` | `.github/` | Issue form + PR template (evidence table on top) |
| `scripts/` | `.standards/` | Hooks, gate checks, `config.sh` |
| `scripts/bin/ship`, `scripts/bin/approve` | `bin/ship`, `bin/approve` | Only merge path — agent-approved when every gate and `agent-approval.sh` pass; owner-only `approved` override |
| `templates/claude-settings.json` | merged into `.claude/settings.json` | Guard hook blocking gate bypass |

## Steps

1. **Survey.** Read the repo's `CLAUDE.md`, package manifests, test runner configs, existing hooks (`.husky/`, `core.hooksPath`), existing `docs/`. Done when you can name: language/stack, lint, typecheck, unit-test, coverage, e2e, perf commands (or that one is missing), the hook manager in use, the GitHub owner login, and that `jq` is installed (`command -v jq`; the guard hook and `bin/ship` need it — without it the guard blocks every command in the repo but exactly `brew install jq` / `sudo apt-get install -y jq`).
2. **Branch.** Work on `chore/<issue>-repo-standards` (open the issue first; this install is itself an issue). Never on main.
3. **Copy** every row of the table above. Existing files with the same path: merge, never overwrite — show the user the conflict if a merge is not obvious. Append `claude-md-block.md` whole, `<!-- repo-standards:begin -->` and `<!-- repo-standards:end -->` included; on an upgrade, replace only the text between them. An existing `CLAUDE.md` that holds facts (architecture, folders, commands) keeps them outside the markers: only the block is a gate file, so PRs that update the facts stay ordinary changes.
4. **Fill `.standards/config.sh`.** Every command variable set to a real command or left empty with a `# N/A — reason` comment. Empty `UNIT_CMD` or `DIFF_COVERAGE_CMD` is not allowed when the repo has source code: add the tooling instead (e.g. vitest/jest coverage + `diff-cover` for lcov/cobertura). If the repo has two halves with their own tooling (an app and a website, a service and a frontend) or a lot of docs-only branches, also set the optional **change class** (`SITE_*_CMD`, `SITE_TEST_FILES_CMD`, `SITE_E2E_CMD`, and the path lists `SHARED_GLOBS` / `APP_GLOBS` / `SITE_GLOBS` / `DOCS_GLOBS`): a docs-only or site-only branch then skips the checks it cannot affect, and each gate prints what it skipped. List in `SHARED_GLOBS` every file one half's tests read from the other, and set `CROSS_READS_APP_FILES` / `CROSS_READS_SITE_FILES` so `cross-reads.sh` catches a new such read. Leave all of it empty for a single-part repo: every check then runs on every branch. Set `BEHAVIOR_DOCS_GLOBS` to any markdown that drives behaviour (runtime prompts, agent commands outside `.claude/`), so a branch editing it never takes the docs-only lane. Set `DEPS_LINKS` to every dependency directory the tests need in the TDD scratch checkout (nested paths such as `site/node_modules` work). Leave `APPROVER="agent"` unless the owner has said `owner`; ask it as one of the step-6 gaps, not a separate stop.
5. **Wire hooks.** Install `jq` first if step 1 found it missing, and list it in the repo's setup prerequisites.
   - No hook manager: `git config core.hooksPath .standards/hooks`, and add that line to the repo's setup script / README setup section (it is per-clone).
   - Husky or similar: add a `pre-push` entry that runs `.standards/hooks/pre-push`; leave the manager in charge.
6. **Product context.** First draft `docs/product/` — goals (metric, target, date), non-goals, assumptions, tool stack — from what the repo already shows: code, README, docs, manifests, config, analytics and hosting setup. Then interview the owner, one question at a time, only for the gaps the repo cannot answer (usually targets and dates) and to correct the draft; this one-off context is the only interview. Anything the owner shares that is future work goes to the roadmap Inbox, then through the idea flow in the rulebook (decided and logged by the agent).
7. **Fill the doc map and seed profile** from what the survey found. Doc map: one line per code area that has a describing doc. Seed profile: fields marked `TODO(owner)` where only prod knowledge can answer — list them for the user.
8. **Prove every gate can fail.** On a scratch branch, break each gate once (uncovered line, source change with no test, mapped code without its doc, missing decision-log section, failing lint, roadmap item with no goal, a test filter that matches nothing — `TEST_FILES_CMD` / `SITE_TEST_FILES_CMD` given a path with no tests must exit non-zero) and show the hook output for each failing, then passing after the fix. A gate you could not make fail is not installed — say so.
9. **Report** to the user: what was installed, config values, gates proven (with output), anything left `TODO(owner)` or N/A, the `APPROVER` mode, and the owner's own steps from "Your steps (owner)" in the rulebook. Agent mode (default): only answering `owner-review` questions on big calls (and "merge" where there is no `bin/ship`); everything else is decided and logged for them to read and revert when they choose (`docs/rule-changes.md`, `decisions.md`, `docs/product/`, the monthly review). Owner mode adds: `bin/approve --spec <issue>` for `owner-approval: required` specs; `bin/approve <pr>` for PRs `bin/ship` refuses for a gate-file change or a removed `owner-approval` flag. Open the PR; the owner merges it — on first install there is no `bin/ship` on the base yet, and an upgrade is judged by the base's older rules.

## Rules for this skill

- Lean: pre-push must stay ≤ 2 min on this repo. Measure it in step 8; if over, move the slowest check to `bin/ship` and say so.
- The rulebook template is the single source of truth. Repo-specific additions go in the repo's own guidelines, not by editing the installed rulebook — so a later re-install can diff cleanly.
- Self-test of the scripts lives in `tests/run.sh` in this skill folder; run it after changing any script.
