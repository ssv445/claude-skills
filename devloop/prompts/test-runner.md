# Test Runner — Regression Guard

Fresh opus. Two modes: `unit` (per-item, Gate 4) and `integration` (per-iteration, after Phase C). **Caveman mode** — output terse. Code + return blocks exact.

## Auto-detection (at setup, cache in state.json)

Orchestrator detects test commands once per run. Priority:

1. **CLAUDE.md** (project root) — explicit `test:unit` / `test:integration`
2. **package.json scripts** — `test:unit`, `test:integration`, `test`, `unit`, `integration`
3. **Common** — `pnpm test`, `npm test`, `yarn test`, `pytest`, `go test ./...`, `cargo test`

Both unit + integration same script → run once per iteration in integration mode, skip per-item unit. Neither resolves → skip Gate 4 + integration step. Log "no test command detected" once. Don't block run.

## Worker Prompt — UNIT mode (Gate 4, per-item)

```
Devloop unit test runner. Item <item-id>, attempt <N>, run <run-id>.

Inputs:
- Item: id, title, files touched
- Command: <auto-detected, e.g. `pnpm test:unit`>
- Tree: fix uncommitted, in `git diff HEAD`

Job: run unit tests, PASS/FAIL. Scope to affected files if runner supports filtering, else full suite. Respond caveman-style.

## Steps

1. Determine scope:
   - Runner supports filter (vitest, jest, pytest path)? → find test files for changed files (`git diff HEAD --name-only`) via repo convention (`*.test.ts` adjacent, `tests/test_*.py`).
   - No filter or no scoped tests found → run full suite.
2. Run command. Capture exit code + last ~100 lines.
3. Timeout: 5min → kill, report TIMEOUT.

## Return

Exit 0:
```
PASS
Command: <cmd>
Scope: <scoped|full>
Tests: <N>
Duration: <Ns>
```

Exit != 0:
```
FAIL
Command: <cmd>
Failing: <test names, max 10>
Excerpt: <last 30 lines>
Likely: <regression in changed files | unrelated flake | env issue>
```

Timeout:
```
TIMEOUT
Command: <cmd>
Killed: 5m
```
TIMEOUT = FAIL for gate.
```

## Worker Prompt — INTEGRATION mode (per-iteration, end of Phase C)

```
Devloop integration test runner. Iteration <N>, run <run-id>.

Inputs:
- Command: <auto-detected, e.g. `pnpm test:integration`>
- Items shipped this iter: <item-ids + commit SHAs>
- Tree: clean (all committed)

Job: run full integration suite once. FAIL → identify likely culprit commit. Respond caveman-style.

## Steps

1. Run command (no filter, full suite).
2. Timeout: 20min → kill, TIMEOUT.
3. FAIL → read failing test files, find production files they exercise, cross-ref with this iter's commit diffs → culprit list.

## Return

Exit 0:
```
PASS
Command: <cmd>
Tests: <N>
Duration: <Ns>
```

Exit != 0:
```
FAIL
Command: <cmd>
Failing: <test names, max 10>
Excerpt: <last 50 lines>
Likely culprits: <commit SHAs touching files exercised by failing tests>
```

Timeout:
```
TIMEOUT
Command: <cmd>
Killed: 20m
```
TIMEOUT = FAIL.
```

## Output Contract

- UNIT: orchestrator reads `PASS`/`FAIL`/`TIMEOUT`. FAIL/TIMEOUT → Gate 4 dissent → roll back → retry (counts toward 3-retry budget).
- INTEGRATION: orchestrator reads `PASS`/`FAIL`/`TIMEOUT`. FAIL/TIMEOUT → `exit_reason: "REGRESSION"`, halt outer loop, jump to Phase D. Culprit commits surfaced in report.
