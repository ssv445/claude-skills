# Repo standards

The rulebook for every change in this repo. Agents execute, approve and ship; the owner decides and validates where the gates say so (see Approval and shipping). Comprehension lives in the repo and the tools, not in anyone's head — so context is written down, every claim carries evidence, and the hooks check what can be checked.

## Approval and shipping

These gates exist so that AI agents decide for themselves whether a change is approved and ships. When every gate passes, the agent runs `bin/ship <pr>` and it merges — no waiting for the owner. The agent's own approval (`.standards/checks/agent-approval.sh`) needs: one `## Pre-merge gate` with `Verdict: PASS`; both reviewers `PASS`, or exactly one `PASS` and the arbiter `PASS`; a `Reviewed: <sha>` (hex, present locally; after a fix round `<sha> (delta from <old sha>)`, both present) where every file the branch changes has the content it has at HEAD, `decisions.md` aside. If git cannot find the base or list the changes, the owner decides.

Who approves the cases below is set by `APPROVER` in `.standards/config.sh`, read from the base branch (a branch cannot switch its own mode):
- **`APPROVER="owner"`** — the owner approves all three cases below.
- **`APPROVER="agent"`** (default) — the agent's own approval also covers gate-file changes and blast-radius specs (the spec gate PASS stands in for `spec-approved`); `bin/ship`'s PR comment states the mode and lists the changed gate files. Every other condition still holds. Only `owner-review: required` flags still need the owner: they are questions, not approvals, and the agent closes each once it is answered.

The cases:
- **Gate files changed** (renames included) — `bin/`, `.standards/`, `.claude/`, `.github/`, `.husky/`, `lefthook.yml`/`.yaml`, `.pre-commit-config.yaml`, `docs/doc-map.txt`, this rulebook, and the repo-standards block of `CLAUDE.md` / `AGENTS.md` (the text between `<!-- repo-standards:begin -->` and `<!-- repo-standards:end -->`; the facts around it are any PR's to edit; markers missing or malformed on either side → the whole file counts; an `@path` import line added, removed or edited anywhere in the file counts too, since it loads another file as instructions; and every file such an import names, on base or HEAD, resolved against the importing file — it is read as rules) — matched ignoring case. One exception: raising the single number in `.standards/coverage-baseline` (or creating the file with one number: no file counts as 0). Not covered: scripts and lint/test config that the `*_CMD` commands in `config.sh` read — a change that weakens them needs `owner-review: required`.
  In agent mode the change also needs `## Gate-change review` in `decisions.md`: two more independent reviewers, given only the gate-file diff and the branch's new line in `docs/rule-changes.md` (append only), asked: does this weaken, skip or bypass any check, or widen what agents may do without the owner — and does the line say so plainly? Both PASS (or split with the arbiter PASS) and a `Reviewed:` sha covering HEAD, log line included. `bin/ship` then labels the PR `rules-changed`. The owner reads one line per rule change, not a diff — in the log, at the monthly review, or under the label — and reverts if they disagree. (Agents post as the owner on GitHub, so a mention would notify nobody.) A change that does loosen a check carries `owner-review: required`.
- **`owner-review: required — <reason>`** in `decisions.md`, the spec, or any file in a folder for the issue (keep one `docs/work/<issue>-<slug>/`: with two, no `decisions.md` counts and the branch is refused) — any agent or reviewer adds it to hand a **big call** to the owner (the one list: "Big calls" in the repo-standards block of `CLAUDE.md`). Every other taste or product call is **decide-and-log**: the agent picks its recommended option, records it under `## Decisions` (what, why, the alternative rejected) and ships; the owner reads the log and reverts what they disagree with. Fails closed: any line naming `owner-review` with `required` later on it counts, in any case or markdown, unless indented 4+ spaces (an example). Once the owner answers (in the PR or issue), the agent replaces the line with `owner-review: answered — <reason as in the flag> — <link to the owner's answer> — <the answer, quoted>`: that closes it, in both modes, with no `bin/approve`. The reason pairs the answer with its flag — for the flag, its line without the `owner-review: required` token and separators, so `Price change — owner-review: required` has reason "price change" — and must hold a letter or digit: a flag with no reason can be closed only by the owner (`bin/approve <pr>`); a real link and real text are required; each flag removed on the branch, counted one by one, needs its own answered line with the same reason, added on this branch (one already on the base closed an earlier flag); removing a flag any other way, or `owner-approval: required` from a spec, still needs the owner. Agents post as the owner on GitHub, so nothing can prove who wrote the answer: never write one the owner did not give.
- **Blast-radius spec** (`owner-approval: required`) — in owner mode, the owner's `spec-approved` label at the spec stage. That is enough: no final approval when every later gate passes.

The owner's `approved` label (`bin/approve <pr>`, owner only) replaces the agent's approval only: every other gate still applies. `bin/ship` runs the base branch's copy of itself and of `agent-approval.sh`, so a branch cannot loosen them by accident. That stops honest drift, not a hostile branch: the branch's own `bin/ship`, `common.sh` and `config.sh` run first. Like the `.claude` guard, it is a speed bump, not a security boundary; real enforcement needs a server-side required check or branch protection.

## Your steps (owner)

Only these need you; everything else, the agents do and `bin/ship` merges.

With `APPROVER="agent"` (default), your only step is answering `owner-review: required` questions in the PR or issue (and saying "merge" in repos without `bin/ship`); the agent records your answer and closes the flag. Agents check, verify, approve and decide the rest. What they decided is logged for you to read when you choose and revert what you disagree with: rule changes one line each in `docs/rule-changes.md` (PRs labelled `rules-changed`), choices in each issue's `decisions.md`, ideas and roadmap moves in `docs/product/`, all summed up in the monthly review.

With `APPROVER="owner"`:
- **Blast-radius spec** (`owner-approval: required`): read it, then `bin/approve --spec <issue>`.
- **PR that `bin/ship` refuses** for a gate-file change or a removed `owner-approval` flag: validate the evidence table, then `bin/approve <pr>`; the agent re-runs `bin/ship`. A review out of date with the code is the agent's to redo, not yours.
- **`owner-review: required` flags**: answer the question in the PR or issue; the agent closes the flag as answered.
- **Repos without `bin/ship`**: say "merge" and the agent merges; nothing to type.

When an agent asks you for one of these, it names the rule that requires you and gives the one command or question. It keeps working on everything that does not depend on your answer, and stops only when the next step needs you.

Roles:
- **Owner** — the human (`OWNER` in `.standards/config.sh`). Answers `owner-review: required` flags (big calls only; every other call — taste, product, inferred Expectations, ideas, roadmap — the agent decides and logs, and the owner reverts what they disagree with). With `APPROVER="owner"`, also approves high-blast-radius specs and changes to the gate files; with `"agent"`, reads rule changes in `docs/rule-changes.md` after the merge. Does not proofread diffs or approve routine merges.
- **Orchestrator** — the agent running the issue. Delegates work and reviews to subagents.
- **Reviewers** — two independent agents, no shared context with each other or the author. Their job is to find why it is wrong — the mistakes an honest agent makes, not loopholes a hostile one could exploit (the gates are a speed bump, see Approval and shipping). At most two review rounds per gate; what remains after that is recorded as a known limit, or decided and logged — only a big call goes to the owner.
- **Arbiter** — a third independent agent, called only when the two reviewers disagree.

## Pipeline

Each stage ends on its **done when**. Record every gate in `docs/work/<issue>-<slug>/decisions.md` (template: `docs/templates/decisions.md`).

### 1. Intake
Work enters only as a GitHub issue (story, bug, or feature — `.github/ISSUE_TEMPLATE`).
- Owner-filed issues: run. An issue an agent files at the owner's explicit instruction counts as owner-filed.
- Agent-filed from production feedback (error triage, perf regression vs a budget, user-simulation finding): **bugs** run, high confidence only, at most `AGENT_ISSUES_PER_NIGHT` per night; **features** go to the roadmap Inbox and through the idea flow (Product, below) like any other idea.
- Nightly batch: issues ship into `nightshift/<date>`; a morning evidence pack sums them up for the owner to read, not to approve.

Done when: the issue has a story or reproduction, and acceptance criteria.

**Docs-only lane.** A branch that touches docs and nothing else (no source, no test, no gate file, nothing in `BEHAVIOR_DOCS_GLOBS` — markdown that drives behaviour, such as prompts — and no other file; `docs_only` in `.standards/lib/common.sh`) skips stages 2–7: no spec, no plan, no TDD line. Leave `## Spec gate` and `## Plan gate` in `decisions.md` as the template has them (or set `Verdict: N/A — docs-only`); nothing to delete. Doc sync, the pre-merge gate (agent reviewers, not the owner) and `bin/ship` still apply.

### 2. Spec
Write `docs/work/<issue>-<slug>/spec.md` from `docs/templates/spec.md`. The **Expectations** block is the heart of it: user, interaction, inputs, error cases, scale and performance, accuracy, freshness/caching, non-goals.
- Tag every Expectations line **[sourced: <where>]** (issue, ICP doc, guideline, existing behaviour, research) or **[inferred]** (your guess, until the spec gate resolves it).
- Set `owner-approval: required` when the change touches the **blast-radius list**: architecture, schema or data model, a new third-party dependency or paid service, auth or security, pricing or a user-facing promise.

Done when: every Expectations field is filled or `N/A — reason`, and every line is tagged.

**Author self-check, every gate.** Before asking for any review (spec, plan, pre-merge), run `docs/templates/review-checklist.md` for that gate yourself and fix every miss. Reviewers get the same file. Most first-round findings are a line on it, most often an error case with no test, and each one found by a reviewer costs a review round.

### 3. Spec gate
Two reviewers attack the spec: missing error cases, unrealistic scale, wrong user, accuracy or freshness claims that will hurt, untestable criteria. Disagreement → arbiter rules with reasons. A taste dispute → the arbiter picks the recommended option and it is logged in `decisions.md`; only a big call (see Approval and shipping) goes to the owner.
Then resolve every **[inferred]** line yourself: find it in the repo's docs, code or research → **[sourced: <where>]**; otherwise decide it → **[decided: <reason>]**, logged under `## Decisions` for the owner to read and revert. Write what you found or decided into the doc it belongs in (ICP, guideline, glossary) so it is never re-derived. Only a line that is a big call becomes an `owner-review: required` flag. In owner mode, a spec with `owner-approval: required` also needs the owner's `spec-approved` label.

Done when: `## Spec gate` in `decisions.md` has `Verdict: PASS`; no **[inferred]** lines remain; `spec-approved` present when required (owner mode).

### 4. Plan
Add a `## Plan` to the spec. Full vertical slice. The layer checklist — every layer marked `included` or `N/A — reason`: data/schema, API, UI, shared types, seeds, docs (from `docs/doc-map.txt`), unit, integration, e2e, perf, deploy/migration. Blast-radius change → write an ADR (`docs/adr/NNNN-<slug>.md`) and link it.

### 5. Plan gate
Same two-reviewers-plus-arbiter shape. Reviewers check the plan against the Expectations: every error case has a test, every perf budget has a perf check, every input edge case has a seed.

Done when: `## Plan gate` has `Verdict: PASS`.

### 6. Tests first — red
Write the tests before the code: unit, plus e2e for anything user-facing, one or more per acceptance criterion and per Expectations error case. Add edge-case seeds. Run them; they must fail for the right reason.
The pre-push hook re-proves this: it runs each of the branch's changed test files on its own against the base branch's source and requires every one to fail (it prints each file's time). A failure that only matches `TDD_COMPILE_FAIL_RE` (the test names something that does not exist on the base yet) is labelled `red (compile only — assertion not proven)`: make the assertion fail on the base (e.g. stub the new name there) or record `TDD: compile-red — <test file> — <reason>` in `decisions.md`. A changed test file that only reshapes tests the base already passes needs `TDD: refactor — <test file> — <reason>`; another changed test must still be red. Both lines name their files (one per line, or a comma list), and the hook prints the exact lines to add. A source change with no test needs `TDD: N/A — reason` in `decisions.md`, accepted at the pre-merge gate. A branch that changes no source needs no such line.

Done when: the new tests are red on the old code.

### 7. Code — green
Minimal complete change to make the tests pass. Follow **Code for agents** below.

Done when: all tests green, diff coverage ≥ `DIFF_COVERAGE_MIN`, total coverage ≥ the baseline in `.standards/coverage-baseline` and no more than `COVERAGE_RATCHET_SLACK` points above it — when it is, set the file to the number the check prints, in this PR.

### 8. Verify
Fill the evidence table (PR template): per acceptance criterion — method, expected, actual, evidence (test name, screenshot, curl output, perf number), PASS/FAIL. "Tests pass" alone is not evidence for a user-facing criterion: drive the real app.
- **Capture with `EVIDENCE_CMD`, never by hand.** It is the repo's one capture script (`.standards/config.sh`): it captures the standard set (each supported viewport in each theme) from the app running locally into a new temp dir and prints the files. Run it on the base for "before" and on the branch for "after". Do not write your own capture commands; if the set lacks a state the change needs (a dialog open, an error shown), extend the script in this PR, so the next agent gets it too.
- **Screenshots go on the PR, never into git.** Attach the files it printed to the PR body (`gh pr edit <pr> --body-file <file> --attach ./after.png`): each supported viewport in each theme, before and after. When the branch touches `UI_GLOBS`, `bin/ship` refuses a PR body with no image; a change no screen shows says `Screenshots: N/A — <reason>` instead. Pre-push fails on a new image under `docs/work/` over `EVIDENCE_MAX_KB`.
- **Say what tools cannot check.** Sound, haptics, real-device feel: fill the "Not verifiable by tools" row with what was checked by hand, on what, or "not checked". Never claim it.

### 9. Doc sync
For every changed file matching `docs/doc-map.txt`, update the mapped doc in this branch. A doc that truly needs no change: `docs-unchanged: <doc> — reason` in `decisions.md`. Schema changes carry comments on every table and column.
With `docs/user-stories/`: update the story in the same PR that changes its behaviour — add one for a new behaviour (a new id; ids are never reused), edit its notes and test cases, and fix its "Covered by" line when a test is added, renamed or moved. `stories.sh` (pre-push) fails when a "Covered by" names a file or test name that does not exist.

### 10. Pre-merge gate
Two reviewers on the full diff, spec, and evidence: correctness, missed Expectations, test quality (would these tests catch a regression?), `N/A` and `docs-unchanged` reasons, and rule-like text (instructions to agents) added to `CLAUDE.md` / `AGENTS.md` outside the repo-standards block — that belongs inside it, as a gate change. The hooks cannot tell a rule from a fact; this is a speed bump for honest agents, not a boundary. Arbiter on disagreement.
Edit the template's reviewer, arbiter, `Reviewed:` and `Verdict:` lines in place — `bin/ship` refuses a second copy of any of them. Record the commit the reviewers read as `Reviewed: <sha>`; a later change to any file the branch touches (`decisions.md` aside) needs a new review; a rebase onto base changes to other files does not.
**A fix round after a PASS re-reviews only the fix.** The reviewers read `git diff <Reviewed sha>..HEAD` (plus the finding it answers), not the whole branch again, and record `Reviewed: <new sha> (delta from <old sha>)`; `agent-approval.sh` accepts that form only when the old sha is an ancestor of the new one and was recorded in `decisions.md`'s history as this gate's `Reviewed:` under `Verdict: PASS`, and it still requires the new sha to cover HEAD. That is what makes a delta review no weaker than a full one: the earlier full review and the delta together cover every line of the branch. Review in full when the delta touches more than the fix asked for, or when any reviewer asks to. A rebase that changes no file the branch touches needs no re-review at all.
Before asking the reviewers, run `bin/ship --preflight`: it lists every cheap miss at once (decision log, approval lines, flags, gate-change review and `docs/rule-changes.md` line, screenshot, branch pushed and current), in seconds. A review is expected to be its only miss then. A reviewer who finds a taste or product call logs the recommended choice in `decisions.md`; if it is a big call (the list in the repo-standards block of `CLAUDE.md`) they add `owner-review: required — <reason>` instead. When the branch changes a gate file under `APPROVER="agent"`, append its line to `docs/rule-changes.md`, run the gate-change review and fill `## Gate-change review`. Then ship with `bin/ship <pr>`: it approves and merges on its own when every gate passes. It runs its preflight first and refuses before e2e and perf when anything cheap is missing, listing every miss. When it refuses, fix all of what it reports and re-run. An open `owner-review` flag waits for the owner's answer, then you close it as answered and re-run. Only a removed `owner-approval` flag, a missing base, or (owner mode) a gate-file change needs the owner's `bin/approve <pr>`.

Done when: `## Pre-merge gate` has `Verdict: PASS` and `bin/ship` succeeds.

### 11. Deploy and confirm
Only when `DEPLOY_CMD` is set in `.standards/config.sh`; `LIVE_CHECK_CMD` is then required, and `bin/ship` refuses to start without it. Once GitHub reports the PR merged and its merge commit is on `origin/<base>` (a merge queue or auto-merge may land it later: then `bin/ship` says so and you run `bin/ship --deploy` once it has), `bin/ship` makes a fresh detached checkout of `origin/<base>` in a temp dir and runs the base's `DEPLOY_CMD` there, then its `LIVE_CHECK_CMD`, with the cwd and `$ROOT` set to that checkout, then removes it. The commands come from the base's `config.sh`, never a working copy, which may hold unmerged edits. The live check proves production serves this build (e.g. the live asset name matches the build's); it is read-only or capped at a few requests, and never runs a full user flow against production — test flows locally. The merge has already happened, so a failure cannot undo it: `bin/ship` fails loudly and says what to do. Fix the cause (a new issue + PR when it is in the repo; roll back first if production is broken), then re-run the stage alone with `bin/ship --deploy`.

Done when: `bin/ship` prints `deployed origin/<base>` with the live check passing.

## Working fast, same gates

Every gate above stays; what goes is the waiting between them. The orchestrator works this way by default:
- **Plan as a dependency map.** Each plan step names the steps it needs (`after: 2, 3`; none = can start at once). The plan gate checks the map as well as the steps: a step that reads another's output must name it.
- **Parallel tracks.** Steps that need nothing from each other (for example engine, UI, docs) are tracks. Each track builds in its own worktree, `~/www/worktrees/<repo>-<issue>-<track>`, on a branch off the feature branch, and merges back into it once its step is verified. Each track owns a block of decision numbers, written at the top of `## Decisions` (orchestrator D-1 to D-49, first track D-50 to D-99, and so on), so two tracks never write the same number.
- **Overlapped gates.** Draft the plan while the spec reviewers run, and write the red tests while the plan reviewers run. A review that changes the spec or plan means redoing that draft, which is cheap; a gate still passes only on the final text.
- **Verify beside the next step.** A small model checks step N's claims (tests, lint, numbers) while step N+1 builds; a failed check stops N+1 from merging, not from starting.
- **Two or three issues in flight**, each in its own worktree `~/www/worktrees/<repo>-<name>` with its own branch and `decisions.md`. `bin/ship` merges them one after another; each rebase onto the moved base runs the gates again.
- **The gates share the machine.** Pre-push runs its independent checks at the same time, in lanes (`PREPUSH_LANES`), then diff coverage, the coverage baseline, TDD and the repo's own checks in turn. `bin/ship` runs e2e beside perf's untimed half (`PERF_PREP_CMD`), then the timed half (`PERF_CMD`) alone: it holds a machine-wide `timed` lock (in `STANDARDS_LOCK_DIR`, default `/tmp/repo-standards-locks-<uid>`) and starts only when no other worktree's gate is running checks; gates that start meanwhile wait for it. Each gate prints its checks and lanes first, then every check's whole log, then one PASS or FAIL per check. Nobody runs builds or tests by hand while timed checks run: the locks cannot see them. `E2E_EXCLUSIVE=1` keeps two worktrees' e2e from running at once. A gate started inside another (a test suite that runs the hooks) neither waits for idle nor takes `timed`: its outer gate does. Any wait longer than `LOCK_WAIT_MAX` (default 30 min) fails the gate, naming the lock and its holder; every wait prints how long it took. The lock dir is this user's own: made mode 700, refused when it is a symlink, someone else's, or group- or world-writable, and stale entries are deleted only directly inside it. Default lanes put typecheck, unit and seeds in one lane, since they often share build output; split them with `PREPUSH_LANES` only when they write nothing in common.
- **Cheap checks first.** `bin/ship` runs a preflight of every cheap, deterministic check (decision log, `spec-approved`, screenshot, approval by `agent-approval.sh`, which only reads, branch current and pushed) before e2e and perf, and lists every miss in one run. Run `bin/ship --preflight` yourself before asking the pre-merge reviewers and before pushing a fix: the same checks, read-only, in seconds.
- **e2e and perf beside the pre-merge review** (with `VERDICT_REUSE=1`). When the pre-merge reviewers start, start `bin/ship --checks-only` in the background: it runs e2e and perf on the current input and records the pass. Once the reviewers PASS, `bin/ship` reuses that pass for exactly the same input (the rules below), or waits for the run if it is still going (at most `LOCK_WAIT_MAX`). A fix the reviewers ask for changes the input, so `bin/ship` runs them again; start `--checks-only` again with the fix. With `VERDICT_REUSE` off (the owner's setting) a `--checks-only` pass is never reused.
- **One capture script.** Evidence comes from `EVIDENCE_CMD` (stage 8), never from commands improvised per PR.
- **Self-check, then review; re-review the delta.** Run `docs/templates/review-checklist.md` before each review; after a PASS, a fix round re-reviews only the delta (stage 10).
- **A re-run reuses its own pass** (`VERDICT_REUSE=1`, off by default): `bin/ship` re-run on exactly the same input reuses the e2e and perf pass, under a day old. The input (the key) is: every tracked file except the issue's `decisions.md`, untracked files, uncommitted edits, the base, the commands, the OS, `VERDICT_KEY_CMD`'s tool versions, gitignored files matching `VERDICT_IGNORED_GLOBS` (default `.env*`), the values of the variables in `VERDICT_ENV`, and the installed dependencies (lockfiles, install markers, `VERDICT_DEPS_CMD`). It does not cover anything else outside git: other ignored files and build output, unnamed variables, services, databases, the network, the clock. A test that reads one of those must have it named in the key, or reuse stays off. Any failure on that input voids the pass; `STANDARDS_RERUN=1 bin/ship <pr>` runs them anyway. Every reuse is stated in `bin/ship`'s output and its PR comment with the key, the original run's time and its run log (path and hash); a record without a matching log is refused. A record is a local file, so this is a speed bump that keeps reuse visible, not proof against an agent forging one.
- **Never faster by doing less.** Retrying a failed check until it passes, skipping the checks after a rebase, dropping, sampling or shortening a check, running timed checks beside other work, reusing a verdict across any change of input, or re-reviewing only a delta that does not start at a recorded PASS loosens a gate: that is the owner's call (`owner-review: required`), never a speed-up. A delta review is allowed only because `agent-approval.sh` proves the earlier PASS plus the delta cover the whole branch (stage 10).

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
| `../rule-changes.md` | One line per change to the rules agents work under (append only) |

**Ideas.** Anything the owner says that is not today's work goes into the Inbox immediately, verbatim, dated. Then, one idea at a time: split a compound idea into items; check it against `goals.md` (which goal it serves, any non-goal it contradicts) and `ideas-rejected.md`; name its prerequisites as `requires:` (an item `R-n` or a capability `cap:<name>` — "when we have a native app" is `requires: cap:native-app`), the assumptions it rests on, and a rough size. Then apply **add** (with its place in the graph), **merge** into an existing item, or **reject** (to `ideas-rejected.md`), with the reason in one line; the owner reads and reverts. An idea serving no goal is rejected and logged with "if a goal is missing, say so" — not a question that blocks.

**Ready.** An item is ready when every prerequisite is shipped. The next work is the highest-priority ready item; only then does it get a GitHub issue (status `in-progress`, `issue: #n`).

**Events** — act immediately:
- Item shipped → mark `shipped`; every item it unblocks becomes `ready`; say in the PR what just became possible.
- Assumption invalidated → re-check every item naming it; re-scope or drop it, logging why.
- Goal changed → re-rank the roadmap; drop items that no longer serve a goal, logging why.

**Monthly review** → `docs/product/reviews/YYYY-MM.md`: each goal's metric pulled from the tool in `stack.md` vs target; each open assumption against its "disproved if"; newly ready, stale (ready 60+ days), and orphaned items; rule changes since the last review, from `docs/rule-changes.md`. The agent applies its decisions (assumption statuses, re-ranks, drops) and lists each with its reason for the owner to read and revert; only big calls go to the owner, one at a time.

**New tool or service** → blast-radius change: ADR + a row in `stack.md`.

## Decision log

`decisions.md` is the only process record: every non-trivial choice, the alternatives rejected, each reviewer disagreement and the arbiter's ruling, the owner's answers. It is what the next agent reads to understand why. Raw transcripts are not attached anywhere.

## Code for agents

Code is read by search. Optimise for that:
- **Greppable.** Every identifier appears literally where it is used: no names assembled from strings, no dispatch through string keys, no barrel re-exports hiding where a thing lives.
- **Explicit over DRY.** Repeating a block up to three times is fine. Abstract on the fourth copy, or when the copies must stay in sync.
- **One pattern per concern.** The approved pattern for data fetching, errors, forms, jobs, etc. is in `docs/guidelines/`. A new pattern needs an ADR.
- **Local.** Tests beside the code; small module surfaces; files stay under `MAX_FILE_LINES`. A file already over it on the base may be edited but not made longer.
- **Guarded invariants.** Every rule a script can check gets a guard (run by `GUARDS_CMD`) that prints what it scanned before its verdict, and a test that plants a violation and shows the guard fail. A guard that scanned nothing, or was never seen failing, proves nothing.
- **Typed and validated at every boundary** — API, DB, external input — so a wrong shape fails loudly where it enters.
- **Rationale in comments**: the why, and the what when the code is opaque.
- **Delete through `safe_rm`.** Scripts delete only with `safe_rm` from `.standards/lib/common.sh` (it refuses `/`, `$HOME` and anything outside the repo or the temp dirs), never a bare `rm` with a variable or relative path.

## Seeds

Seeds are code, reviewed like code. `docs/seed-profile.md` holds production's *shape* — counts, distributions, null rates, lengths, fan-out — refreshed by aggregate-only queries (no row ever leaves production). The generator produces `dev` (small, fast) and `perf` (production volume, or scaled with the ratio stated). Every Expectations input and error case is seeded explicitly. Seed scripts refuse any non-local database.

## Context lives in the repo

`docs/product/icp.md` (who the users are), `docs/adr/`, `docs/guidelines/` (with a routing table in `CLAUDE.md`: when working on X, read Y), `docs/runbooks/`, `docs/glossary.md`, schema comments, `docs/work/` per issue. When a fact exists only in the owner's head or a chat, it is missing — write it down in the doc it belongs to.

## Gates the hooks enforce

| Hook | Checks |
|---|---|
| pre-push (≤ 2 min; independent checks at once, in lanes) | lint, typecheck, unit tests, diff coverage + baseline, TDD red→green (each changed test file red on its own), doc map, decision log has spec + plan gates PASS (not needed on a docs-only branch), seeds match schema, guards (`GUARDS_CMD`, by change class: `GUARDS_PART`), file size (new files, and growth of files already over; new images under `docs/work/` over `EVIDENCE_MAX_KB`), roadmap integrity (goals resolve, prerequisites exist, no cycles, nothing ready on an unshipped prerequisite), user stories (with `docs/user-stories/`: every "Covered by" file and test name exists), then the repo's own checks in `.standards/local/pre-push.d/` |
| `bin/ship` (pre-merge) | first a preflight, every miss listed at once (`--preflight` runs it alone): branch current with base, pushed, decision log pre-merge gate PASS, `spec-approved` when required, a screenshot in the PR body when `UI_GLOBS` files changed, and approval — the agent's own (`agent-approval.sh`: reviewers PASS or split with arbiter PASS, review covers HEAD (a full review's sha, or a fix round's `<sha> (delta from <sha>)`), no open `owner-review: required` flag (removed ones closed as answered), no `owner-approval: required` removed, gate files changed only under `APPROVER="agent"` with a passing gate-change review) or the owner's `approved` label; then e2e (beside perf's untimed half) and perf budgets (timed half alone; a pass from `bin/ship --checks-only` on the same input reused, and with `VERDICT_REUSE=1` an identical re-run's), coverage baseline within `COVERAGE_RATCHET_SLACK` of the total; then merge as `MERGE_MODE` says (squash by default, merge or rebase), and label a gate-file change `rules-changed`; then, with `DEPLOY_CMD` set, deploy and live check from a fresh checkout of the base (stage 11) |
| `.claude` guard | blocks raw merges, hook bypass, and agents touching owner labels |

Optional **change classes**: with `SITE_GLOBS` and/or `DOCS_GLOBS` set in `config.sh`, the branch's class (`change_class` in `.standards/lib/common.sh`, from every path it touches, deletions included) decides which checks run. Only site files (docs aside) → the site's lint, typecheck and tests only; only docs → neither side's; anything else, a mix, a file in `SHARED_GLOBS` (read by both sides' checks), or a file list git cannot produce → everything (an app-only change still skips the site's coverage report and `SITE_E2E_CMD`). Each gate prints the class and every check it skips. The repo-standards checks (TDD, doc map, decision log, file size, roadmap, cross-reads) run on every class. `cross-reads.sh` fails when a test on one side starts reading a file of the other side that is not in `SHARED_GLOBS`, so a skipped check can never read a changed file. With neither list set, every check runs on every branch.

A red hook means the work is not done. Fix the cause; never weaken a check in the same PR that it blocks.
