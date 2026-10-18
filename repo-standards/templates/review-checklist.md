# Review checklist

The exact list the reviewers of each gate work through. The author runs it first and fixes every miss before asking for review: most first-round findings are a line from this list (most often an error case with no test). Reviewers get this same file, and still look past it for what it does not name: it is the floor of a review, not the whole of it.

Read it before each review; nothing is recorded from it. A miss the author finds is fixed, not listed.

## Spec gate (`spec.md`, before the plan)
- [ ] **User** is a real persona (linked), with skill, device, language and frequency; not "users".
- [ ] **Every error case**: each input, dependency and step can fail; each failure says what the user sees and how they recover. Look for: empty, too large, malformed, duplicate, offline / timeout, no permission, concurrent edit, partial failure, retry after failure.
- [ ] **Scale**: volume now and in 12 months, a p95 budget, and the known traps checked (N+1, unbounded lists, fan-out, large payloads). A number, not "fast".
- [ ] **Accuracy**: where approximate is fine and where it must be exact (money, counts, dates, time zones, rounding).
- [ ] **Freshness / caching**: what may be stale, for how long, what invalidates it.
- [ ] **Testable criteria**: each acceptance criterion names an observable result a test or a screenshot can show. "Works well", "is intuitive", "handles errors" are not criteria.
- [ ] Every Expectations line is tagged `[sourced: …]`, `[inferred]` or `[decided: …]`; at the gate, no `[inferred]` is left.
- [ ] Non-goals say what this does not handle.
- [ ] Blast radius: `owner-approval: required` set when it touches architecture, schema, a new dependency or paid service, auth or security, pricing or a user-facing promise.
- [ ] Big calls (a price, a public claim, a new screen or visual design, anything that costs money, a loosened check) carry `owner-review: required`; every other call is decided and logged.

## Plan gate (`## Plan` in `spec.md`)
- [ ] **Every Expectations error case has a test** — name it (file and test name) per error case.
- [ ] **Every perf budget has a perf check** in `PERF_CMD` that fails above the budget.
- [ ] **Every input edge case has a seed** (empty, max size, unicode, nulls, the bad-input examples).
- [ ] **Every layer** of the checklist is `included` or `N/A — <reason>`: data/schema, API, UI, shared types, seeds, docs (from `docs/doc-map.txt`), unit, integration, e2e, perf, deploy/migration, ADR.
- [ ] Each acceptance criterion maps to at least one test; user-facing ones to e2e too.
- [ ] Steps form a dependency map (`after: …`); a step that reads another's output names it.
- [ ] Blast-radius change: an ADR is written and linked.
- [ ] Every doc the doc map ties to a changed path is in the plan.

## Pre-merge gate (the full diff, the spec, the PR's evidence)
- [ ] **Correctness**: the code does what the spec says, on every error case; no missed Expectations line.
- [ ] **Test quality**: each test would fail if the behaviour it names broke (not only "runs"); error cases tested, not just the happy path; no test that asserts the implementation instead of the result.
- [ ] **N/A reasons**: every `N/A`, `TDD: N/A`, `TDD: compile-red`, `TDD: refactor` and `docs-unchanged` line has a reason that holds.
- [ ] **Doc map**: every changed path in `docs/doc-map.txt` has its doc updated (or a `docs-unchanged` line that holds); user stories updated with their behaviour.
- [ ] **Evidence**: each acceptance criterion has a row with real evidence; UI changes have screenshots from `EVIDENCE_CMD` at every viewport and theme; what no tool can check is said, not claimed.
- [ ] No rule-like text (instructions to agents) added to `CLAUDE.md` / `AGENTS.md` outside the repo-standards block.
- [ ] Taste calls are logged in `decisions.md`; big calls carry `owner-review: required`.
- [ ] A gate file changed (agent mode): the line in `docs/rule-changes.md` says plainly what the rules now do differently, and the gate-change review is done.

### Fix round after a PASS
Re-review only `git diff <Reviewed sha>..HEAD` and record `Reviewed: <new sha> (delta from <old sha>)`, where the old sha is the one the PASS recorded. `agent-approval.sh` accepts that only when the old sha is an ancestor of the new one and was recorded as this gate's `Reviewed:` under `Verdict: PASS`, so the earlier full review plus the delta cover the whole branch. Review in full instead when the delta touches more than the fix asked for, or when any reviewer asks to.
