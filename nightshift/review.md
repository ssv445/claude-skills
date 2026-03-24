---
description: "Pre-flight review of GitHub issues before nightshift:run. Checks each issue has story references, acceptance criteria, dependencies, and UI descriptions. Auto-invokes brainstorming to fill gaps interactively."
---

# Nightshift: Issue Review & Gap-Fill

Audit GitHub issues for completeness before autonomous processing. For each issue with gaps, brainstorm with the user to fill them — then update the issue.

**Core principle: Nightshift can only deliver what's well-specified. Garbage in → garbage out.**

## Input

$ARGUMENTS

Parse issue numbers from arguments. Accept: `#100 #101`, `100 101`, `100,101`.
If none provided: `gh issue list --label "nightshift" --state open --json number,title --limit 20`

## Review Checklist

For each issue, check these requirements. Each is PASS or FAIL with a specific reason.

### Required (all issues)

1. **Story reference** — Issue body contains a reference to a user story file:
   - Format: `Story: docs/user-stories/<file>.md → STORY-ID, STORY-ID`
   - OR: acceptance criteria written directly in the issue body as checkboxes
   - FAIL if: no story reference AND no acceptance criteria checkboxes

2. **Acceptance criteria** — Clear, testable criteria exist:
   - If story referenced → read the file, verify the story IDs exist, extract criteria
   - If inline → verify they are specific (not vague like "should work well")
   - Each criterion should be verifiable with a test or screenshot
   - FAIL if: criteria are vague, missing, or not testable

3. **Dependencies** — Issue states what it depends on:
   - Other issues that must be completed first
   - Schemas/models/endpoints it assumes exist
   - FAIL if: issue references components that don't exist and doesn't declare the dependency

4. **Scope clarity** — Issue has a clear boundary:
   - What's IN scope and what's NOT
   - FAIL if: scope is ambiguous or could be interpreted multiple ways

### Required (UI-facing issues only)

5. **UI description** — Issue describes what the user sees:
   - Page/route where the UI lives
   - Key UI elements with `data-testid` values
   - User flow (what happens when user clicks/submits/navigates)
   - FAIL if: issue creates UI but has no description of what it looks like or how it works

6. **Seed data** — Issue notes what test data is needed:
   - What data must exist for the feature to be testable
   - FAIL if: feature requires specific data (campaigns, users, orgs) but doesn't mention it

### Detection: Is it UI-facing?

An issue is UI-facing if ANY of these are true:
- Title/body mentions: page, component, route, UI, frontend, form, button, screen, modal, dialog
- Story file references acceptance criteria with `data-testid`
- Issue is in `apps/web/` scope
- Issue mentions navigation (`/campaigns`, `/feed`, etc.)

## Process

### Phase 1: Audit All Issues

For each issue in the input:

```
1. gh issue view <N> --json title,body,labels
2. Read the issue body
3. If story reference found → read the story file
4. Run all checklist items
5. Classify: ALL_PASS | HAS_GAPS
6. If HAS_GAPS → record which items failed and why
```

### Phase 2: Report Summary

Present a table to the user:

```
## Issue Review Summary

| # | Title | Story | Criteria | Deps | Scope | UI | Seed | Status |
|---|-------|-------|----------|------|-------|----|------|--------|
| 100 | Campaign schemas | ✓ | ✓ | ✓ | ✓ | — | — | READY |
| 104 | Participation reg | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | GAPS |
| 107 | Campaign list UI | ✓ | ✓ | ✗ | ✓ | ✗ | ✓ | GAPS |

READY: 3 issues
GAPS: 5 issues (will brainstorm next)
```

Show the report. Then immediately proceed to Phase 3 for each issue with gaps.

### Phase 3: Brainstorm Per Issue (auto-invoke)

For each issue with GAPS, in order:

1. **Announce:** "Brainstorming gaps for issue #<N>: <title>"

2. **Show the gaps:** List exactly which checklist items failed and why

3. **Ask questions one at a time** to fill each gap:
   - For missing story reference: "Which user story does this implement? Here are the available stories: ..." (list files from `docs/user-stories/`)
   - For missing acceptance criteria: "What should this feature do? Let me draft acceptance criteria..."
   - For missing UI description: "What should this page/form look like? What are the key elements?"
   - For missing dependencies: "This issue references X which doesn't exist yet. Is it covered by another issue?"
   - For missing seed data: "This feature needs test data. What campaigns/users/orgs should exist?"

4. **Draft the fix:** Write the missing content (story reference, criteria, UI description, etc.)

5. **Show the draft** and ask: "Should I update issue #<N> with this?"

6. **Update the issue:** If approved, use `gh issue edit <N> --body "..."` to add the missing sections

7. **Re-run checklist** on the updated issue to confirm ALL_PASS

### Phase 4: Final Report

After all issues processed:

```
## Final Status

READY for nightshift:run: #100, #101, #102, #103, #104
STILL HAS GAPS (user declined to fix): #107
BLOCKED (dependency missing): #108

Suggested command: /nightshift:run 100 101 102 103 104
```

## Issue Body Format (target)

After review + gap-fill, each issue should have this structure:

```markdown
## Summary
<1-2 sentences describing the feature/fix>

## Story Reference
Story: docs/user-stories/15-campaign-registration.md → REG-01, REG-02

## Acceptance Criteria
- [ ] Criterion 1 (specific, testable)
- [ ] Criterion 2
- [ ] ...

## UI Description (if UI-facing)
- Page: `/campaigns/[slug]/register`
- Key elements:
  - Registration form (`data-testid="registration-form"`)
  - Submit button (`data-testid="register-submit"`)
- User flow: User fills form → submits → sees success + "Start Quiz" button

## Seed Data (if needed)
- Active NSPC 2026 campaign (quiz type)
- Org with enrollment + QR code

## Dependencies
- Depends on: #101 (campaign schemas), #102 (campaign CRUD)
- Blocked by: none

## Scope
- IN: Registration form, API endpoint, validation
- NOT IN: Quiz player, certificate generation
```

## Rules

- One question at a time during brainstorming
- Multiple choice when possible
- Don't over-engineer — fill gaps, don't rewrite issues
- If user says "skip" for an issue, mark it and move on
- Never modify issues without showing the draft first
- Keep the brainstorming focused on the specific gaps, not redesigning the feature
- If a story file doesn't exist yet, offer to create it during brainstorming

## Example Invocation

```
/nightshift:review 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114
```

```
/nightshift:review  (picks up issues labeled "nightshift")
```
