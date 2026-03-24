# Step 2: PLAN — Create Implementation Plan

**Max retries: 3**

## Worker agent (subagent_type: `general-purpose`)

```
Prompt: Read .claude/nightshift/issue-<N>/01-understand.md (approved understanding).
Read existing comments on the issue for any prior context: `gh issue view <N> --comments`

Create a detailed implementation plan. Write to: .claude/nightshift/issue-<N>/02-plan.md

Structure:
## Implementation Plan for Issue #<N>

### Changes Required
For each file:
- **<filepath>**: <what changes, which functions/classes>

### New Files (if any)
- **<filepath>**: <purpose>

### Test Plan
- List specific test cases (describe behavior, not implementation)
- Include: unit tests, integration tests, browser/e2e tests where applicable
- Include edge cases and error scenarios

### Browser Testing Plan
- List any user-facing flows that need Playwright or Chrome browser testing
- Describe the user journey to verify (navigate, click, assert)
- If the issue is purely backend with no UI, write "N/A — backend only"

### Visual Review Plan (if UI Impact = yes)
For each affected page from 01-understand.md's UI Impact section:
- **URL**: <local URL to test>
- **Viewport**: 375x812 (mobile-first) + 1280x800 (desktop, if relevant)
- **What to check**: <specific visual elements — layout, spacing, colors, touch targets, responsive behavior>
- **User flow**: <tap/click sequence to test interactivity>
- **Screenshot checkpoints**: <list of states to capture — initial load, after interaction, error states, empty states>
If the issue has no UI changes, write "N/A — no visual changes"

### Verification Criteria (HARD EVIDENCE REQUIRED)
For each criterion, specify what evidence proves it:
- Criterion 1: <what to verify> → Evidence: <exact command/action to prove it>
- Criterion 2: ...
- Example: "API returns 200 with correct shape" → Evidence: `curl -s localhost:3001/api/feed | jq .`
- Example: "Login button works" → Evidence: screenshot of logged-in state after clicking

### Execution Order
Numbered steps — tests first (TDD), then implementation.

### Risks & Mitigations
- <risk>: <how to handle>

At the very end of your response, output:
ORCHESTRATOR_SUMMARY: <1 sentence, max 20 words, describing outcome>
```

**After the worker finishes, offload issue commenting to a subagent (Rule 3).**

## Review gate — 3 agents in parallel (`model: "opus"`)

| Reviewer | subagent_type | Focus |
|----------|--------------|-------|
| Architecture | `architecture` | Structurally sound? SOLID? Layer separation? |
| Security | `security` | Security gaps? Input validation? Auth checks? |
| Performance | `performance` | Performance concerns? N+1 queries? Missing indexes? |

**Reviewers MUST also check:**
- Are verification criteria concrete and evidence-based? (not vague)
- Does the plan address the ROOT CAUSE (for bugs), not just symptoms?
- REJECT if verification criteria say "should work" instead of specifying exact proof

Each outputs a `VERDICT` line (see Agent Output Formats).

**2/3 approve → proceed, but ALL critical issues from ANY reviewer must be addressed (see Review Gate Protocol in run.md).** Rejected → ralph retry. **Offload review comment to subagent.**
