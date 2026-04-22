# Phase B — Punch-List Builder

Fresh opus subagent. Runs once per iteration. **Caveman mode** — terse, fragments, drop articles/filler. Code + return blocks exact.

## Worker Prompt

```
Devloop punch-list builder. Iteration <N>, run <run-id>.

Inputs:
- Test-stories: .tmp/devloop/<run-id>/iteration-<N>/test-stories.json
- Story IDs: <story-ids>
- Prior plan: .tmp/devloop/<run-id>/iteration-<N-1>/plan.md (if exists)
- State: state.json (shipped+skipped items)
- Taste: ~/.claude/taste/*.md
- Guidance: CLAUDE.md (project + ~/.claude)

Job: raw test-stories fixes → ordered, filtered, vetted punch-list. Respond caveman-style.

## Steps

1. **Extract.** Per story, list each prioritized fix. 🔴 first. Fields:
   id, source, title, failing_criterion, severity, affected_pages

2. **Filter not-necessary.** Drop if:
   - Already fixed (verify file, report may be stale)
   - Duplicate
   - Shipped prior iter (check state.json commitSha)
   - Feature not polish (new functionality/pages/flows)
   Log: `{id, reason}`.

3. **Adversarial pass.** Per survivor:
   - Real or pedantic?
   - Regression risk?
   - Compounds or fights other items?
   - Shared root cause → merge.
   Log drops/merges.

4. **Taste-skip filter.** Drop if decision NOT in:
   - ~/.claude/taste/*.md
   - CLAUDE.md
   - Nearby code precedent
   - Test-stories report
   Mark `taste-skip` + specific question. Exclude from executable plan.

5. **Order for compounding.**
   - Same file → adjacent
   - Foundational → dependent
   - 🔴 before 🟡 in same group
   - A changes B's inspected code → A first

6. **Write** iteration-<N>/plan.md:

---
# Devloop iteration <N> plan

## Summary
Raw: <n>  Dropped: <n>  Taste-skip: <n>  Executable: <n>

## Executable items (ordered)

### 1. <item-id>
- Source: <story-id>
- Title: <title>
- Failing: <criterion>
- Severity: 🔴
- Pages: <urls>
- Notes: <prior-iter context>

## Taste-skipped
### <item-id>
- Question: <decision needed>
- No precedent: <one line>

## Dropped
- <item-id>: <reason>
---

Return exact:
PUNCH_LIST: <exec> items, <taste> taste-skips, <drop> dropped. Path: iteration-<N>/plan.md
```

## Output Contract

Orchestrator reads only `PUNCH_LIST:` line. Plan file is source of truth.
