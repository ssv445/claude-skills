# Step 4: CODE — Implement (TDD Green Phase)

**Max retries: 7**

## Worker agent (subagent_type: `general-purpose`)

```
Prompt: Read .claude/nightshift/issue-<N>/02-plan.md (plan) and
.claude/nightshift/issue-<N>/03-tests.md (tests).
Read issue comments: `gh issue view <N> --comments`

Implement MINIMUM code to make all tests pass.
Follow plan execution order + existing conventions.

CRITICAL for BUG FIX:
- Fix ROOT CAUSE from 01-understand.md
- NO workarounds masking real problem
- After fix, verify it addresses root cause (not just making test green)
- Test passes but fix feels like bandaid → investigate deeper

After implementation:
1. Run ALL unit tests: pnpm test — FULL output
2. Lint: pnpm lint — FULL output
3. Typecheck: pnpm typecheck — FULL output
4. Failures → fix and iterate
5. Commit: `feat(<scope>): <description> (#<N>)` (or `fix(<scope>):` for bugs)
6. Write to: .claude/nightshift/issue-<N>/04-code.md:
   - Files modified/created
   - Key implementation decisions
   - For bugs: how fix addresses root cause
   - FULL test/lint/typecheck output (copy-paste)

At the very end of your response, output:
ORCHESTRATOR_SUMMARY: <1 sentence, max 20 words, describing outcome>
```

**After worker finishes, offload issue commenting to subagent (Rule 3).**

## Review gate — 3 agents in parallel (`model: "opus"`)

| Reviewer | subagent_type | Focus |
|----------|--------------|-------|
| Code quality | `code-standards` | Naming, conventions, no `any`, proper imports? |
| Security | `security` | Input validation? Auth? No injection? No secrets? |
| Architecture | `architecture` | SOLID? Clean layers? No god functions? |

**Reviewers MUST check:**
- Code fixes ROOT CAUSE (bugs) or just hides symptoms?
- Evidence fix works (test output), not just "looks correct"?
- REJECT workarounds: try/catch swallowing errors, optional chaining hiding nulls, defaults masking missing data

Each outputs `VERDICT` line.

**2/3 approve → proceed, but ALL critical issues from ANY reviewer addressed (see Review Gate Protocol in run.md).** Rejected → ralph retry. **Offload review comment to subagent.**
