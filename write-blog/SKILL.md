---
name: write-blog
version: 5.0.0
description: |
  Write a complete blog post with iterative humanization (multi-model AI-detection
  via codex + gemini, target avg score < 10, max 5 passes), pre-gate agent-team
  review (no raw AI output reaches user), curated internal + external links
  (3-way value grading by Claude + Codex + Gemini, hard caps 1-10 ext / 1-5 int),
  per-repo .write-blog.cfg site profile, expert persona reviews, and adversarial
  fact-checking. v5: adds iterative humanize loop, external-CLI multi-model
  scoring, and link curation.
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - WebSearch
  - WebFetch
  - Task
  - Bash
  - AskUserQuestion
  - Skill
---

# Write Blog Post

Technical blog writer. v5 adds: per-repo site profile, multi-model AI-detection
loop, link curation with 3-way grading, pre-gate review on every artifact.

<!-- PHASES_START -->

## Core Principles

1. **Target audience REQUIRED** — ask if not provided, never proceed without it
2. **APP formula** for hooks, **Cialdini** for engagement
3. **Two user gates** — outline + draft. Pre-gate agent review fixes consensus issues silently before showing user.
4. **No raw AI output to user.** Every artifact passes through team review first.
5. **Iterative humanization** — loop until avg AI-likelihood < 10 (max 5 passes), multi-model detection.
6. **Curated links** — at least 1 internal + 1 external; max 5 internal, 10 external; all graded.
7. **Human imagery only** — realistic/natural, never sci-fi or abstract AI art.

## Persuasion Frameworks

### APP Formula (Introductions)
1. **Agree** — acknowledge reader's pain/situation
2. **Promise** — clear benefit from reading
3. **Preview** — brief roadmap

### Cialdini's 6 Principles (weave naturally, don't force all 6)

| Principle | Application |
|-----------|-------------|
| **Reciprocity** | Give value first (tips, templates, examples) |
| **Authority** | Credentials, experience, cite experts |
| **Social Proof** | Adoption stats, "others have..." |
| **Liking** | Be relatable, share struggles, humor |
| **Scarcity** | Timely info, recent data |
| **Consistency** | Build on reader's existing beliefs |

## Input

**Required:** Topic + Target Audience (STOP and ask if audience missing)
**Optional:** Codebase reference for personal experience

## Workflow

```
Phase 0: Audience Definition →
Phase 1: Research (1.1-1.6) → 1.7 Site Profile (load/build .write-blog.cfg)
       → 1.8 Pre-gate review of audience+research notes
       → light user confirmation of research direction
Phase 2: Outline (2.1) → 2.3 Expert Outline Review (3 personas, fix consensus silently)
       → [GATE 1] user approves polished outline
Phase 3: Draft (content + bare reference list at bottom)
Phase 4: Pre-gate Review Bundle
       → 4.5 Adversarial Fact Check (3 internal subagents) — fix Must-Fix
       → 4.7 Expert Draft Review (3 personas, "would share" gate ≥2/3)
         (Loop-Integrity Filter on subagent outputs)
       → [GATE 2] user approves polished, fact-checked draft
Phase 4.9: Link Curation & Insertion (3-way grade external + internal, caps + filter)
Phase 5: Iterative Humanization Loop (max 5; codex + gemini detect; target avg < 10)
Phase 5.x: Lint check
Phase 6: Header image (Gemini)
Phase 7: Write file
Phase 8: Visual test (8.5 internal pre-review of rendered output)
Phase 9: Optional commit
```

---

## Cross-Cutting Patterns

### Pre-gate Review Pattern

**Rule:** Every AI-generated artifact destined for a user gate first passes a 3-subagent pre-gate review. Consensus issues are fixed silently. Polished output reaches the user.

Consensus rules:
- 3/3 agree on issue → must fix before user
- 2/3 agree → fix or document why ignored
- 1/3 → log, don't act

Retry budget: max 2 fix-and-re-review rounds per phase. Third round = escalate to user with diagnosis.

Applies to: Phase 1.8 (research), Phase 2.3 (outline), Phase 4.5+4.7 (draft), Phase 8.5 (rendered output).

### Loop-Integrity Filter Team

**Purpose:** Inside iterative loops (humanize, link grade, fact check), each step's output is filtered by 3 subagents before becoming input to the next iteration. Catches drift on bad data.

Three subagents, run in parallel:

1. **Loss Detector** — "What valuable content / nuance / signal did this step REMOVE that should have stayed? List specifics."
2. **Gap Finder** — "What's MISSING that the audience needs but isn't present? What would they ask that isn't answered?"
3. **Hallucination Hunter** — "Any claim, score, or judgment NOT grounded in source/context? Flag fabricated specifics, invented stats, made-up quotes, unsupported scoring rationale."

Synthesis:
- 3/3 agree → must address before next iteration
- 2/3 agree → address or document why ignored
- 1/3 → log only, continue

Applies inside: Phase 5 (humanization, per iteration), Phase 4.9 (link grading per candidate), Phase 4.5 (fact-check outputs), Phase 2.3 + 4.7 (expert reviews).

### External CLI Reviewers

`codex` and `gemini` CLIs provide independent-model verification. Used for:

- AI-detection scoring in humanization loop (Phase 5)
- Value grading of links in audience context (Phase 4.9)

Invocation:

```bash
codex exec "<prompt>" 2>/dev/null      # 30s timeout
gemini -p "<prompt>" 2>/dev/null       # 30s timeout, default gemini-2.5-pro
```

Both return text/JSON; parse score field. On failure of one, continue with the other and flag in final report. If both fail in humanize loop: skip detection, run 2 fixed humanizer passes, present to user with note. If both fail in link grading: drop to Claude-only, surface to user before insertion.

<!-- PHASES_END -->

## Quick Reference

(filled in by later task)

## Credits

(filled in by later task)
