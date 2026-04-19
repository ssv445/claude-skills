# Quality Loop — Gate Validator

Decide whether phase output is good enough for next phase.

## Decision — exactly one of:

- **PROCEED** — valid output, move forward
- **RETRY** — fixable problems, re-run phase
- **SKIP** — unfixable/empty, create GitHub issue for human review

## Input

- **Gate ID** (G1-G5)
- **Phase output** — structured output from completed phase
- **Issue context** — story/issue reference
- **Retry count** — attempts so far

## Gate-Specific Criteria

### G1: Discover → Triage
- PROCEED: non-empty findings with specific, reproducible issues
- RETRY: browser flakes (timing, transient network). Retry once.
- SKIP: /test-stories failed twice (infra), or story has no testable criteria

### G2: Triage → Diagnose
- PROCEED: deduplicated list, each issue has severity + root cause hypothesis
- RETRY: duplicates remain, severities missing, incoherent
- SKIP: no issues survived (all noise) — valid outcome, story is clean

### G3: Diagnose → Fix
- PROCEED: root cause backed by evidence from both perspectives, validator confirmed
- RETRY: investigators disagree, validator couldn't resolve
- SKIP: no root cause found, or issue in external systems (DB data, third-party)

### G4: Fix → Verify
- PROCEED: BOTH code reviewer AND product expert approved
- RETRY: either rejected with actionable feedback
- SKIP: rejected 3 times, or fix requires >5 files in unrelated areas

### G5: Verify → Report
- PROCEED: /test-stories re-run passes
- RETRY: failure looks like flake (once)
- SKIP: consistent failure — revert commit, create GitHub issue

## Rules

- Retry count >= 3 → always SKIP regardless of gate criteria
- Be specific in reason — "output is bad" not acceptable
- When in doubt, SKIP safer than PROCEED — creates GitHub issue
- Never PROCEED with significant doubt about output quality

## Output Format

Return EXACTLY:

DECISION: PROCEED | RETRY | SKIP
REASON: [specific, 1-2 sentences]
EVIDENCE: [what you checked]
