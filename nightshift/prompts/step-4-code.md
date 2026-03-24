# Step 4: CODE — Implement the Feature (TDD Green Phase)

**Max retries: 7**

## Worker agent (subagent_type: `general-purpose`)

```
Prompt: Read .claude/nightshift/issue-<N>/02-plan.md (plan) and
.claude/nightshift/issue-<N>/03-tests.md (tests).
Read existing issue comments for context of previous work: `gh issue view <N> --comments`

Implement the MINIMUM code to make all tests pass.
Follow the execution order from the plan.
Follow existing code conventions.

CRITICAL: If this is a BUG FIX:
- Fix the ROOT CAUSE identified in 01-understand.md
- Do NOT write a workaround that masks the real problem
- After fixing, verify the fix addresses the root cause (not just making the test green)
- If the test passes but you suspect the fix is a bandaid → investigate deeper

After implementation:
1. Run ALL unit tests: pnpm test — capture FULL output
2. Run lint: pnpm lint — capture FULL output
3. Run typecheck: pnpm typecheck — capture FULL output
4. If anything fails, fix it. You have room to iterate.
5. Commit: `feat(<scope>): <description> (#<N>)` (or `fix(<scope>):` for bugs)
6. Write summary to: .claude/nightshift/issue-<N>/04-code.md listing:
   - Files modified/created
   - Key implementation decisions
   - For bugs: explain how the fix addresses the root cause, not just the symptom
   - FULL test output (copy-paste)
   - FULL lint output
   - FULL typecheck output

At the very end of your response, output:
ORCHESTRATOR_SUMMARY: <1 sentence, max 20 words, describing outcome>
```

**After the worker finishes, offload issue commenting to a subagent (Rule 3).**

## Review gate — 3 agents in parallel (`model: "opus"`)

| Reviewer | subagent_type | Focus |
|----------|--------------|-------|
| Code quality | `code-standards` | Naming, conventions, no `any`, proper imports, file structure? |
| Security | `security` | Input validation? Auth checks? No injection? No secrets? |
| Architecture | `architecture` | SOLID? Clean layers? No god functions? Proper abstractions? |

**Reviewers MUST also check:**
- Does the code fix the ROOT CAUSE (for bugs) or just hide symptoms?
- Is there evidence the fix works (test output), not just "looks correct"?
- REJECT if code includes workarounds like try/catch swallowing errors, optional chaining to hide nulls, or default values masking missing data

Each outputs a `VERDICT` line (see Agent Output Formats).

**2/3 approve → proceed, but ALL critical issues from ANY reviewer must be addressed (see Review Gate Protocol in run.md).** Rejected → ralph retry. **Offload review comment to subagent.**
