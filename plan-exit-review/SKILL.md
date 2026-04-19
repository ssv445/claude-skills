---
name: plan-exit-review
version: 2.0.0
description: |
  Review a plan thoroughly before implementation. Challenges scope, reviews
  architecture/code quality/tests/performance, and walks through issues
  interactively with opinionated recommendations.
allowed-tools:
  - Read
  - Grep
  - Glob
  - AskUserQuestion
---

# Plan Review Mode

Review plan before code changes. Every issue: concrete tradeoffs, opinionated recommendation, ask input before assuming direction.

## Priority hierarchy
Context-limited: Step 0 > Test diagram > Opinionated recs > rest. Never skip Step 0 or test diagram.

## Engineering preferences:
* DRY — flag repetition aggressively
* Well-tested non-negotiable; too many > too few
* "Engineered enough" — not fragile, not over-abstracted
* More edge cases > fewer; thoughtfulness > speed
* Explicit over clever
* Minimal diff: fewest new abstractions and files

## Diagrams:
* ASCII diagrams liberally — data flow, state machines, dependency graphs, pipelines, decision trees
* Embed in code comments for complex Models/Controllers/Services/Tests
* **Diagram maintenance = part of change.** Code near diagrams modified → review accuracy, update same commit. Stale > none. Flag stale even outside scope.

## Step 0: Scope Challenge

1. **Existing code solving sub-problems?** Capture from existing flows vs building parallel?
2. **Minimum changes for goal?** Flag deferrable. Ruthless on scope creep.
3. **Smell:** >8 files or >2 new classes/services → challenge.

Ask which option:
1. **SCOPE REDUCTION:** Overbuilt → propose minimal, review that.
2. **BIG CHANGE:** Interactive per section (Arch → Code Quality → Tests → Perf), max 4 issues each.
3. **SMALL CHANGE:** Step 0 + one combined pass, single top issue per section, numbered+lettered options, test diagram, completion summary. One AskUserQuestion round.

**Critical: user skips SCOPE REDUCTION → respect fully.** Make chosen plan succeed. Scope concerns once in Step 0 only. Never silently reduce, skip components, or re-argue for less.

## Review Sections

### 1. Architecture
System design, boundaries, coupling, data flow, bottlenecks, scaling, SPOFs, security (auth/data/API). Need ASCII diagrams? Each new codepath: one realistic production failure — plan accounts for it?

**STOP.** AskUserQuestion NOW. Wait for response.

### 2. Code quality
Organization, DRY violations (aggressive), error handling + missing edge cases (explicit), tech debt hotspots, over/under-engineered. ASCII diagrams in touched files still accurate?

**STOP.** AskUserQuestion NOW. Wait for response.

### 3. Tests
Diagram all new UX/data flow/codepaths/branching. Note what's new. Each new item → JS or Rails test exists?

LLM/prompt changes: check CLAUDE.md "Prompt/LLM changes" patterns. Touched → state eval suites, cases, baselines. AskUserQuestion to confirm.

**STOP.** AskUserQuestion NOW. Wait for response.

### 4. Performance
N+1 queries, DB patterns, memory, caching opportunities, slow paths.

**STOP.** AskUserQuestion NOW. Wait for response.

## Issue format

- Concrete problem, file/line references
- 2-3 options (include "do nothing" where reasonable), each: effort/risk/maintenance in one line
- **Lead with directive:** "Do B. Here's why:" — not "might be worth considering"
- Map to engineering preference. One sentence.
- **AskUserQuestion:** "We recommend [LETTER]: [reason]" then `A) ... B) ... C) ...`. Label: NUMBER + LETTER (e.g. "3B"). Never yes/no or open-ended.

## Required outputs

**NOT in scope** — deferred work, one-line rationale each.

**What already exists** — existing code partially solving sub-problems. Reused or rebuilt?

**TODOS.md** — genuinely valuable deferred work (not "nice to have"):
* What (one line) / Why (concrete value) / Context (3-month pickup) / Depends on
* No vague bullets. Ask user which items to capture.

**Failure modes** — each new codepath from test diagram: one realistic failure. Test covers? Error handling? User sees clear error or silent? No test + no handling + silent → **critical gap**.

**Completion summary:**
```
- Step 0: user chose ___
- Architecture: ___ issues | Code Quality: ___ issues
- Tests: diagram done, ___ gaps | Performance: ___ issues
- NOT in scope: done | What exists: done
- TODOS.md: ___ proposed | Failure modes: ___ critical gaps
```

## Retrospective
Git log for branch — prior review-driven refactors/reverts? More aggressive on those areas.

## Formatting
* NUMBER issues, LETTER options. Label AskUserQuestion with both.
* Recommended option first. One sentence max per option. Pickable in <5s.
* Pause after each section.

## Unresolved decisions
User skips AskUserQuestion or interrupts → track. End of review: "Unresolved decisions that may bite you later" — never silently default.
