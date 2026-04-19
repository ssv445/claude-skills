# Step 2: PLAN — Create Implementation Plan

**Max retries: 3**

## Worker agent (subagent_type: `general-purpose`)

```
Prompt: Read .claude/nightshift/issue-<N>/01-understand.md (approved).
Read issue comments: `gh issue view <N> --comments`

Create detailed implementation plan. Write to: .claude/nightshift/issue-<N>/02-plan.md

Structure:
## Implementation Plan for Issue #<N>

### Changes Required
For each file:
- **<filepath>**: <what changes, which functions/classes>

### New Files (if any)
- **<filepath>**: <purpose>

### Test Plan
- Specific test cases (behavior, not implementation)
- Unit, integration, browser/e2e where applicable
- Edge cases and error scenarios

### Browser Testing Plan
- User-facing flows needing Playwright/Chrome testing
- User journey to verify (navigate, click, assert)
- Backend only → "N/A"

### Visual Review Plan (if UI Impact = yes)
For each affected page:
- **URL**: <local URL>
- **Viewport**: 375x812 (mobile) + 1280x800 (desktop if relevant)
- **What to check**: <layout, spacing, colors, touch targets, responsive>
- **User flow**: <tap/click sequence>
- **Screenshot checkpoints**: <states to capture — load, interaction, error, empty>
If no UI changes → "N/A"

### Verification Criteria (HARD EVIDENCE REQUIRED)
For each criterion, specify proof:
- Criterion: <what> → Evidence: <exact command/action>
- Example: "API returns 200" → `curl -s localhost:3001/api/feed | jq .`
- Example: "Login works" → screenshot of logged-in state

### Execution Order
Numbered steps — tests first (TDD), then implementation.

### Risks & Mitigations
- <risk>: <mitigation>

At the very end of your response, output:
ORCHESTRATOR_SUMMARY: <1 sentence, max 20 words, describing outcome>
```

**After worker finishes, offload issue commenting to subagent (Rule 3).**

## Review gate — 3 agents in parallel (`model: "opus"`)

| Reviewer | subagent_type | Focus |
|----------|--------------|-------|
| Architecture | `architecture` | Structurally sound? SOLID? Layer separation? |
| Security | `security` | Security gaps? Input validation? Auth checks? |
| Performance | `performance` | N+1 queries? Missing indexes? |

**Reviewers MUST check:**
- Verification criteria concrete and evidence-based? (not vague)
- Plan addresses ROOT CAUSE (bugs), not symptoms?
- REJECT if criteria say "should work" instead of exact proof

Each outputs `VERDICT` line.

**2/3 approve → proceed, but ALL critical issues from ANY reviewer addressed (see Review Gate Protocol in run.md).** Rejected → ralph retry. **Offload review comment to subagent.**
