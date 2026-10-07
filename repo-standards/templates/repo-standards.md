# Repo standards

The rulebook for every change in this repo. Agents execute; the owner decides and validates. Comprehension lives in the repo and the tools, not in anyone's head — so context is written down, every claim carries evidence, and the hooks check what can be checked.

## Approval and shipping

These gates exist so that AI agents decide for themselves whether a change is approved and ships. When every gate passes, the agent runs `bin/ship <pr>` and it merges — no waiting for the owner. The owner is needed only where the gates say so:
- **Gate files changed** — `bin/`, `.standards/`, `.claude/`, `.github/`, `CLAUDE.md`, `AGENTS.md`, this rulebook. An agent never approves a change to the rules that judge it.
- **`owner-review: required — <reason>`** in `decisions.md` — any agent or reviewer adds it to hand a taste or product call to the owner.
- **Blast-radius spec** (`owner-approval: required`) — the owner's `spec-approved` label at the spec stage. That is enough: no final approval when every later gate passes.

The owner's `approved` label (`bin/approve <pr>`, owner only) overrides what `bin/ship` refuses. `bin/ship` runs the base branch's copy of itself and of `agent-approval.sh`, so a branch cannot loosen them by accident. That stops honest drift, not a hostile branch: the branch's own `bin/ship`, `common.sh` and `config.sh` run first. Like the `.claude` guard, it is a speed bump, not a security boundary; real enforcement needs a server-side required check or branch protection.

Roles:
- **Owner** — the human (`OWNER` in `.standards/config.sh`). Approves high-blast-radius specs, rules on inferred Expectations, taste disputes and `owner-review: required` flags, approves changes to the gate files. Does not proofread diffs or approve routine merges.
- **Orchestrator** — the agent running the issue. Delegates work and reviews to subagents.
- **Reviewers** — two independent agents, no shared context with each other or the author. Adversarial: their job is to find why it is wrong.
- **Arbiter** — a third independent agent, called only when the two reviewers disagree.

## Pipeline

Each stage ends on its **done when**. Record every gate in `docs/work/<issue>-<slug>/decisions.md` (template: `docs/templates/decisions.md`).

### 1. Intake
Work enters only as a GitHub issue (story, bug, or feature — `.github/ISSUE_TEMPLATE`).
- Owner-filed issues: run.
- Agent-filed from production feedback (error triage, perf regression vs a budget, user-simulation finding): **bugs** run, high confidence only, at most `AGENT_ISSUES_PER_NIGHT` per night; **features** wait for the owner's `spec-approved` label.
- Nightly batch: issues ship into `nightshift/<date>` and the owner reviews one evidence pack in the morning.

Done when: the issue has a story or reproduction, and acceptance criteria.

### 2. Spec
Write `docs/work/<issue>-<slug>/spec.md` from `docs/templates/spec.md`. The **Expectations** block is the heart of it: user, interaction, inputs, error cases, scale and performance, accuracy, freshness/caching, non-goals.
- Tag every Expectations line **[sourced: <where>]** (issue, ICP doc, guideline, existing behaviour) or **[inferred]** (your guess).
- Set `owner-approval: required` when the change touches the **blast-radius list**: architecture, schema or data model, a new third-party dependency or paid service, auth or security, pricing or a user-facing promise.

Done when: every Expectations field is filled or `N/A — reason`, and every line is tagged.

### 3. Spec gate
Two reviewers attack the spec: missing error cases, unrealistic scale, wrong user, accuracy or freshness claims that will hurt, untestable criteria. Disagreement → arbiter rules with reasons. A taste dispute → the owner.
Then ask the owner about every **[inferred]** line (one question at a time) and, if `owner-approval: required`, for the `spec-approved` label. Write each answer back into the doc it belongs in (ICP, guideline, glossary) so the question is never asked again, and re-tag the line **[sourced]**.

Done when: `## Spec gate` in `decisions.md` has `Verdict: PASS`; no **[inferred]** lines remain; `spec-approved` present when required.

### 4. Plan
Add a `## Plan` to the spec. Full vertical slice. The layer checklist — every layer marked `included` or `N/A — reason`: data/schema, API, UI, shared types, seeds, docs (from `docs/doc-map.txt`), unit, integration, e2e, perf, deploy/migration. Blast-radius change → write an ADR (`docs/adr/NNNN-<slug>.md`) and link it.

### 5. Plan gate
Same two-reviewers-plus-arbiter shape. Reviewers check the plan against the Expectations: every error case has a test, every perf budget has a perf check, every input edge case has a seed.

Done when: `## Plan gate` has `Verdict: PASS`.

### 6. Tests first — red
Write the tests before the code: unit, plus e2e for anything user-facing, one or more per acceptance criterion and per Expectations error case. Add edge-case seeds. Run them; they must fail for the right reason.
The pre-push hook re-proves this: it runs the branch's changed test files against the base branch's source and requires a failure. A change with no test needs `TDD: N/A — reason` in `decisions.md`, accepted at the pre-merge gate.

Done when: the new tests are red on the old code.

### 7. Code — green
Minimal complete change to make the tests pass. Follow **Code for agents** below.

Done when: all tests green, diff coverage ≥ `DIFF_COVERAGE_MIN`, total coverage ≥ the baseline in `.standards/coverage-baseline`.

### 8. Verify
Fill the evidence table (PR template): per acceptance criterion — method, expected, actual, evidence (test name, screenshot, curl output, perf number), PASS/FAIL. "Tests pass" alone is not evidence for a user-facing criterion: drive the real app.

### 9. Doc sync
For every changed file matching `docs/doc-map.txt`, update the mapped doc in this branch. A doc that truly needs no change: `docs-unchanged: <doc> — reason` in `decisions.md`. Schema changes carry comments on every table and column.

### 10. Pre-merge gate
Two reviewers on the full diff, spec, and evidence: correctness, missed Expectations, test quality (would these tests catch a regression?), `N/A` and `docs-unchanged` reasons. Arbiter on disagreement.
A reviewer who finds a taste or product call adds `owner-review: required — <reason>` to `decisions.md`. Then ship with `bin/ship <pr>`: it approves and merges on its own when every gate passes; when it reports owner approval needed, ask the owner to validate the evidence table and run `bin/approve <pr>`, then run `bin/ship` again.

Done when: `## Pre-merge gate` has `Verdict: PASS` and `bin/ship` succeeds.

## Product: goals, roadmap, ideas

The roadmap is planned as a graph and executed in a line. All of it lives in `docs/product/`:

| File | Holds |
|---|---|
| `goals.md` | Goals (metric, target, date) and non-goals |
| `assumptions.md` | Beliefs not yet proven: what would disprove each, status |
| `stack.md` | Every third-party tool: why, which account, where config lives — never secrets |
| `roadmap.md` | Inbox + items with `goal`, `status`, `requires`, `provides`, `assumptions`, `issue` |
| `ideas-rejected.md` | Ideas turned down against the goals, with the reason |
| `reviews/YYYY-MM.md` | Monthly review (template `docs/templates/review.md`) |

**Ideas.** Anything the owner says that is not today's work goes into the Inbox immediately, verbatim, dated. Then, one idea at a time: split a compound idea into items; check it against `goals.md` (which goal it serves, any non-goal it contradicts) and `ideas-rejected.md`; name its prerequisites as `requires:` (an item `R-n` or a capability `cap:<name>` — "when we have a native app" is `requires: cap:native-app`), the assumptions it rests on, and a rough size. Propose **add** (with its place in the graph), **merge** into an existing item, or **reject** (with the reason); the owner confirms. An idea serving no goal is a question for the owner: reject, or is a goal missing?

**Ready.** An item is ready when every prerequisite is shipped. The next work is the highest-priority ready item; only then does it get a GitHub issue (status `in-progress`, `issue: #n`).

**Events** — act immediately:
- Item shipped → mark `shipped`; every item it unblocks becomes `ready`; tell the owner what just became possible.
- Assumption invalidated → re-check every item naming it; propose re-scope or drop.
- Goal changed → re-rank the roadmap; propose drops for items that no longer serve a goal.

**Monthly review** → `docs/product/reviews/YYYY-MM.md`: each goal's metric pulled from the tool in `stack.md` vs target; each open assumption against its "disproved if"; newly ready, stale (ready 60+ days), and orphaned items. Decisions go to the owner one at a time, then the roadmap is updated.

**New tool or service** → blast-radius change: ADR + a row in `stack.md`.

## Decision log

`decisions.md` is the only process record: every non-trivial choice, the alternatives rejected, each reviewer disagreement and the arbiter's ruling, the owner's answers. It is what the next agent reads to understand why. Raw transcripts are not attached anywhere.

## Code for agents

Code is read by search. Optimise for that:
- **Greppable.** Every identifier appears literally where it is used: no names assembled from strings, no dispatch through string keys, no barrel re-exports hiding where a thing lives.
- **Explicit over DRY.** Repeating a block up to three times is fine. Abstract on the fourth copy, or when the copies must stay in sync.
- **One pattern per concern.** The approved pattern for data fetching, errors, forms, jobs, etc. is in `docs/guidelines/`. A new pattern needs an ADR.
- **Local.** Tests beside the code; small module surfaces; files stay under `MAX_FILE_LINES`.
- **Typed and validated at every boundary** — API, DB, external input — so a wrong shape fails loudly where it enters.
- **Rationale in comments**: the why, and the what when the code is opaque.

## Seeds

Seeds are code, reviewed like code. `docs/seed-profile.md` holds production's *shape* — counts, distributions, null rates, lengths, fan-out — refreshed by aggregate-only queries (no row ever leaves production). The generator produces `dev` (small, fast) and `perf` (production volume, or scaled with the ratio stated). Every Expectations input and error case is seeded explicitly. Seed scripts refuse any non-local database.

## Context lives in the repo

`docs/product/icp.md` (who the users are), `docs/adr/`, `docs/guidelines/` (with a routing table in `CLAUDE.md`: when working on X, read Y), `docs/runbooks/`, `docs/glossary.md`, schema comments, `docs/work/` per issue. When a fact exists only in the owner's head or a chat, it is missing — write it down in the doc it belongs to.

## Gates the hooks enforce

| Hook | Checks |
|---|---|
| pre-push (≤ 2 min) | lint, typecheck, unit tests, diff coverage + baseline, TDD red→green, doc map, decision log has spec + plan gates PASS, seeds match schema, file size, roadmap integrity (goals resolve, prerequisites exist, no cycles, nothing ready on an unshipped prerequisite) |
| `bin/ship` (pre-merge) | branch current with base, pushed, e2e, perf budgets, decision log pre-merge gate PASS, `spec-approved` when required; then approval — the agent's own (`agent-approval.sh`: reviewers or arbiter PASS, no `owner-review: required`, no gate file changed) or the owner's `approved` label; then squash merge |
| `.claude` guard | blocks raw merges, hook bypass, and agents touching owner labels |

A red hook means the work is not done. Fix the cause; never weaken a check in the same PR that it blocks.
