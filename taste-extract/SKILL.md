---
name: taste-extract
description: |
  Extract taste principles from conversation history, memory files, and CLAUDE.md files.
  Builds a taste profile at ~/.claude/taste/ used by eval-criteria for taste-informed evaluation.
  Run once to bootstrap, then periodically to compound.
---

# Taste Extraction

## Input

Optional: `--scope <project|global|all>` (default: all)

## Data Sources (process in order)

### Layer 1: Structured Sources (high confidence)

**1a. Feedback memory files**
Find `~/.claude/projects/*/memory/feedback_*.md`. Each file IS a taste principle. Extract: principle, why, project, map to dimension.

**1b. Global CLAUDE.md (`~/.claude/CLAUDE.md`)**
"Core Principles" section + rules/conventions → taste entries with confidence: high.

**1c. Project CLAUDE.md files**
Find `~/www/*/CLAUDE.md` + `shyam_works/projects/*/CLAUDE.md`. Extract: user context, constraints, conventions, target audience. Reveals product taste.

### Layer 2: Conversation History (medium confidence)

Process JSONL files for taste signals.

**2a. Corrections** — Find in `~/.claude/projects/*/` + `subagents/`: user messages with "no", "don't", "wrong", "actually", "I prefer", "too complex", "over-engineered". Extract: what was corrected + what user wanted instead + rejected assistant action.

**2b. Approvals** — "yes", "perfect", "exactly", "ship it", or user proceeds without pushback after non-obvious choice. Only record approvals where alternative was reasonable.

**2c. Tool rejections** — tool_result with "rejected", "denied". Strong signal. Extract: tool + action + user's next message.

**2d. Repeated instructions** — Same instruction in 3+ sessions = strong signal.

### Layer 3: Git History (supporting evidence)

Voluntary refactors: `git log --author=shyam --all --oneline` — commits that refactor without bug/feature driver. Shows what user improves when they don't have to.

## Taste Dimensions

| Dimension | File | Covers |
|-----------|------|--------|
| architecture | ~/.claude/taste/architecture.md | System design, complexity, file structure, abstractions |
| product | ~/.claude/taste/product.md | Feature completeness, "done" definition, shipping decisions |
| ux | ~/.claude/taste/ux.md | User empathy, target audience, usability, accessibility |
| code | ~/.claude/taste/code.md | Code style, error handling, naming, patterns |
| process | ~/.claude/taste/process.md | Git workflow, PR style, review, deployment, CI |
| communication | ~/.claude/taste/communication.md | Error messages, UI copy, naming for users |

## Output Format

```markdown
# Taste: {Dimension}

Last updated: {date}
Sources: {N} feedback files, {N} conversation signals, {N} CLAUDE.md rules
Total principles: {N}

---

### {Principle Title}

{One-line principle statement}

- **Confidence:** {low|medium|high} ({N} sources)
- **Last seen:** {date}
- **Sources:**
  - {source type}: {brief description} ({project}, {date or session})
- **Applies when:** {context}
- **Counter-examples:** {when doesn't apply, if known}

---
```

### Confidence Rules

| Evidence | Confidence |
|----------|-----------|
| Single conversation correction | low |
| Feedback memory file (curated) | medium |
| CLAUDE.md rule (codified) | high |
| 3+ independent sources confirm | high |
| Correction + codified rule agree | high |

### Deduplication

Before adding: check if similar exists. Yes → merge evidence, bump confidence, update last_seen. No → add new. Contradicts existing → keep both, note contradiction, flag for review.

## Processing Strategy

Layer 1 first (fast, high confidence, ~50 files). Then Layer 2: 20 most recent sessions per project. With `--deep`: all sessions (subagents per project, 2 parallel max). Layer 3 last, supporting only.

Layer 2 subagents: one per project (max 2 parallel). Each reads project's JSONL, extracts signals. Main agent merges across projects.

## Post-Extraction

1. Write taste files to `~/.claude/taste/`
2. Print summary:
   ```
   Taste extraction complete:
   - architecture: {N} principles ({N} high, {N} medium, {N} low)
   - product/ux/code/process/communication: {N} each
   Total: {N} principles from {N} sources
   Review: open ~/.claude/taste/ to validate
   ```
3. Flag contradictions for manual review
4. Commit: `chore: extract taste profile from {N} sources`

## Re-running (Incremental)

If taste files exist: only process sessions newer than `Last updated`. Merge new findings (dedup, bump confidence). Skip Layer 1 re-processing unless `--full` flag.
