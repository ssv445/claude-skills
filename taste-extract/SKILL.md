---
name: taste-extract
description: |
  Extract taste principles from conversation history, memory files, and CLAUDE.md files.
  Builds a taste profile at ~/.claude/taste/ used by eval-criteria for taste-informed evaluation.
  Run once to bootstrap, then periodically to compound.
---

# Taste Extraction

**Announce:** "I'm using the taste-extract skill to extract taste principles from your work history."

Taste = accumulated judgment about how systems should work, how to keep architecture minimal, how to make things usable. It's revealed through consistent choices, corrections, and approvals across sessions.

## Input

Optional argument: `--scope <project|global|all>` (default: all)
- `global` — extract from global CLAUDE.md + global memory only
- `project` — extract from current project's history + memory only
- `all` — extract from everything

## Data Sources (process in this order)

### Layer 1: Structured Sources (high confidence, already curated)

These are pre-labeled taste data. Extract directly.

**1a. Feedback memory files**
```
Find all: ~/.claude/projects/*/memory/feedback_*.md
Each file IS a taste principle. Extract:
- The principle (what to do / not do)
- The "Why" (the reason / incident)
- The project it came from
- Map to a taste dimension (see Dimensions below)
```

**1b. Global CLAUDE.md (~/. claude/CLAUDE.md)**
```
Read the "Core Principles" section and any rules/conventions.
Each principle → taste entry with confidence: high (explicitly codified)
```

**1c. Project CLAUDE.md files**
```
Find all CLAUDE.md files in:
- ~/www/*/CLAUDE.md (code repos)
- shyam_works/projects/*/CLAUDE.md (management)
Extract: user context, constraints, conventions, target audience descriptions
These reveal product taste (who the user is, what matters)
```

### Layer 2: Conversation History (medium confidence, needs clustering)

Process JSONL files to find taste signals. This is the heavy lift.

**2a. Find correction signals**
```
For each JSONL file in ~/.claude/projects/*/  and subagents/:
  Parse user messages that follow assistant actions.
  Look for correction patterns:
  - Explicit: "no", "don't", "wrong", "not that", "stop", "remove", "undo"
  - Preference: "actually", "I prefer", "let's do X instead", "simpler"
  - Quality: "too complex", "over-engineered", "half-baked", "not complete"

  For each correction found:
  - Extract: what was corrected + what the user wanted instead
  - Extract: the assistant's action that was rejected (tool call or text before the correction)
  - Record: project, session ID, approximate context
```

**2b. Find approval signals**
```
Look for approval patterns in user messages:
  - Explicit: "yes", "perfect", "good", "exactly", "looks right", "ship it"
  - Implicit: user proceeds without pushback after a non-obvious choice

  For each approval:
  - Extract: what approach was approved
  - Note: approvals of obvious things are noise. Only record approvals of
    choices where the alternative was also reasonable.
```

**2c. Find tool rejections**
```
Look for tool_result messages containing:
  - "rejected", "doesn't want to proceed", "denied"
  - These are strong taste signals — user explicitly said no to an action

  For each rejection:
  - Extract: what tool was called + what it tried to do
  - Extract: user's next message (often explains why)
```

**2d. Find repeated instructions**
```
Look for user messages that appear across multiple sessions:
  - Same instruction in 3+ sessions = strong taste signal
  - Examples: "keep it simple", "don't add comments", "check the browser"
```

### Layer 3: Git History (supporting evidence)

**3a. Voluntary refactors**
```
git log --author=shyam --all --oneline | look for:
  - Commits that refactor without a bug/feature driver
  - These show what the user improves when they don't have to
  - Patterns: file splits, renames, simplifications
```

## Taste Dimensions

Classify each extracted principle into one of these dimensions:

| Dimension | File | What it covers |
|-----------|------|---------------|
| architecture | ~/.claude/taste/architecture.md | System design, complexity, file structure, abstractions |
| product | ~/.claude/taste/product.md | Feature completeness, what "done" means, shipping decisions |
| ux | ~/.claude/taste/ux.md | User empathy, target audience, usability, accessibility |
| code | ~/.claude/taste/code.md | Code style, error handling, naming, patterns |
| process | ~/.claude/taste/process.md | Git workflow, PR style, review, deployment, CI |
| communication | ~/.claude/taste/communication.md | Error messages, UI copy, naming things for users |

## Output Format

Each taste file follows this structure:

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
  - {source type}: {brief description} ({project}, {date or session})
- **Applies when:** {context where this principle should be checked}
- **Counter-examples:** {when this doesn't apply, if known}

---
```

### Confidence Rules

| Evidence | Confidence |
|----------|-----------|
| Single conversation correction | low |
| Feedback memory file (already curated) | medium |
| CLAUDE.md rule (explicitly codified) | high |
| 3+ independent sources confirm same principle | high |
| Correction + codified rule agree | high |

### Deduplication

Before adding a principle:
1. Check if a similar principle already exists in the taste file
2. If yes: merge evidence, bump confidence if warranted, update last_seen
3. If no: add as new entry
4. If contradicts existing: keep both, note the contradiction, flag for review

## Processing Strategy

5,242 JSONL files at 2GB is too much for one pass. Process in batches:

1. **Start with Layer 1** (structured sources) — fast, high confidence, ~50 files
2. **Sample Layer 2** — process 20 most recent sessions per project, extract signals
3. **Expand Layer 2** — if running with `--deep`, process all sessions (use subagents per project, 2 at a time max)
4. **Layer 3** — git log analysis, supporting evidence only

For Layer 2, use subagents:
- Spawn one subagent per project (max 2 parallel per resource limits)
- Each subagent reads that project's JSONL files, extracts taste signals
- Main agent merges results across projects

## Post-Extraction

1. Write taste files to `~/.claude/taste/`
2. Print summary:
   ```
   Taste extraction complete:
   - architecture: {N} principles ({N} high, {N} medium, {N} low confidence)
   - product: {N} principles
   - ux: {N} principles
   - code: {N} principles
   - process: {N} principles
   - communication: {N} principles

   Total: {N} principles from {N} sources

   Review: open ~/.claude/taste/ to validate
   ```
3. Flag any contradictions found for manual review
4. Commit: `chore: extract taste profile from {N} sources`

## Re-running (Incremental Mode)

If taste files already exist:
- Only process sessions newer than the `Last updated` date in each taste file
- Merge new findings with existing (dedup, bump confidence)
- Don't re-process Layer 1 unless `--full` flag is passed
