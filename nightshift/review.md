---
description: "Pre-flight review of GitHub issues before nightshift:run. Checks each issue has story references, acceptance criteria, dependencies, and UI descriptions. Auto-invokes brainstorming to fill gaps interactively."
---

# Nightshift: Issue Review & Gap-Fill

Audit GitHub issues for completeness before autonomous processing. Gaps found → brainstorm with user → update issue.

**Nightshift can only deliver what's well-specified. Garbage in → garbage out.**

## Input

$ARGUMENTS

Parse issue numbers: `#100 #101`, `100 101`, `100,101`.
If none: `gh issue list --label "nightshift" --state open --json number,title --limit 20`

## Review Checklist

Each item: PASS or FAIL with reason.

### Required (all issues)

1. **Story reference** — Body has `Story: docs/user-stories/<file>.md → STORY-ID` OR inline acceptance criteria checkboxes. FAIL if neither.
2. **Acceptance criteria** — Clear, testable. If story ref → verify IDs exist. If inline → must be specific, not vague. Each verifiable with test or screenshot. FAIL if vague/missing/untestable.
3. **Dependencies** — States what it depends on (issues, schemas, endpoints). FAIL if references nonexistent components without declaring dependency.
4. **Scope clarity** — Clear IN/NOT IN boundary. FAIL if ambiguous or multi-interpretable.

### Required (UI-facing only)

5. **UI description** — Page/route, key elements with `data-testid`, user flow. FAIL if creates UI without describing it.
6. **Seed data** — What test data needed. FAIL if feature requires specific data but doesn't mention it.

### UI-facing detection

Issue is UI-facing if ANY: mentions page/component/route/UI/frontend/form/button/screen/modal/dialog, story has `data-testid` criteria, scope is `apps/web/`, mentions navigation paths.

## Process

### Phase 1: Audit All Issues

```
1. gh issue view <N> --json title,body,labels
2. Read body
3. If story reference → read story file
4. Run all checklist items
5. Classify: ALL_PASS | HAS_GAPS
6. HAS_GAPS → record which items failed and why
```

### Phase 2: Report Summary

```
## Issue Review Summary

| # | Title | Story | Criteria | Deps | Scope | UI | Seed | Status |
|---|-------|-------|----------|------|-------|----|------|--------|

READY: N issues
GAPS: N issues (will brainstorm next)
```

Show report, then proceed to Phase 3 for each gap issue.

### Phase 3: Brainstorm Per Issue (auto-invoke)

For each issue with GAPS:

1. Announce: "Brainstorming gaps for issue #<N>: <title>"
2. Show which checklist items failed and why
3. Ask questions **one at a time** to fill each gap
4. Draft missing content
5. Show draft, ask: "Update issue #<N> with this?"
6. If approved: `gh issue edit <N> --body "..."`
7. Re-run checklist to confirm ALL_PASS

### Phase 4: Final Report

```
## Final Status

READY for nightshift:run: #100, #101, ...
STILL HAS GAPS (user declined): #107
BLOCKED (dependency missing): #108

Suggested command: /nightshift:run 100 101 ...
```

## Target Issue Body Format

```markdown
## Summary
<1-2 sentences>

## Story Reference
Story: docs/user-stories/15-campaign-registration.md → REG-01, REG-02

## Acceptance Criteria
- [ ] Criterion 1 (specific, testable)
- [ ] Criterion 2

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
- Fill gaps, don't rewrite issues
- "skip" → mark and move on
- Never modify without showing draft first
- If story file missing, offer to create during brainstorming
