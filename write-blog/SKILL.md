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

---

## Phase 0: Audience Definition (REQUIRED)

If no audience provided, STOP. AskUserQuestion:

```
"Who specifically is this blog for? Examples:
- 'Junior devs learning React for the first time'
- 'Solo founders building their first SaaS'
- 'Backend devs who've never touched Docker'
Who's your target reader?"
```

### Audience Profile Template

```markdown
## Target Audience Profile
**Who:** [specific description]
**Experience Level:** [beginner / intermediate / advanced with THIS topic]
**Current Situation:** [pain they have]
**Goal:** [what they want]
**Constraints:** [time, budget, team, stack]

### Already Know
- [assumed knowledge]

### Don't Know (gaps to fill)
- [knowledge gap]

### Likely Questions
- [question they'd ask]
- [objection they'd have]

### What Makes This Useful to Them
- [specific outcome]
```

Keep profile visible throughout all phases. Every decision references it.

---

## Phase 1: Research

### 1.1 Load SEO Rules

Read `.claude/SEO-RULES.md` if exists. Extract: title max length (usually 46 chars + suffix), meta description (120-160), image requirements, URL format.

### 1.2 GSC Keyword Research (if MCP available)

**Step 1:** Existing rankings — `enhanced_search_analytics` with `queryFilter: [topic]`, `filterOperator: "contains"`, 90-day range, `rowLimit: 50`

**Step 2:** Quick wins — same query with `enableQuickWins: true`. Queries ranking 4-10 with low CTR = title/heading candidates.

**Step 3:** Compile:

```markdown
## GSC Keyword Analysis
**Existing rankings:** [table: Query, Impressions, Clicks, CTR, Position]
**Quick wins (rank 4-10, low CTR):** [list]
**Title recommendations:** [2 options with char counts]
**Slug recommendation:** [primary keyword]
```

If GSC MCP unavailable, skip — rely on competitive analysis.

### 1.3 Audience-Focused Competitive Analysis

Search: `"[topic] for [audience type]"`, `"[topic] guide [experience level]"`, `"how to [topic] [audience constraint]"`

For top 3-5 results, analyze from audience's perspective:

| Article | Assumes Reader Knows | Skips/Glosses Over | Audience Gap |
|---------|---------------------|-------------------|--------------|
| [URL] | [prereqs assumed] | [what they skip] | [what YOUR audience needs] |

### 1.4 Fact Research

Search for data relevant to audience's situation: stats at their scale, benchmarks at their level, case studies from similar contexts.

### 1.5 Codebase Research (if provided)

Explore for relatable examples: challenges the audience would face, solutions at their complexity level, relevant metrics.

### 1.6 Compile Research Notes

```markdown
## Target Audience Reminder
[paste audience profile]

## Competitive Insights
- Existing content assumes: [knowledge they may not have]
- Gap I can fill: [specific thing audience needs]
- My unique angle: [one sentence]

## Key Facts
1. [fact that matters to them] — [source URL]

## From Experience (if codebase)
- [relatable example/challenge]

## Questions MY AUDIENCE Would Ask
- [based on knowledge gaps and constraints]
```

### 1.7 Site Profile (`.write-blog.cfg`)

**Goal:** Detect once per repo, reuse forever. Stores posts dir, frontmatter shape, URL pattern, sitemap path, link policy, humanize thresholds.

**Routine:**

1. If `.write-blog.cfg` exists at repo root → load it, skip detection.
2. Otherwise detect:
   - Framework markers: `next.config.js`, `astro.config.mjs`, `_config.yml` (Hugo/Jekyll), `gatsby-config.js`.
   - Glob common posts paths: `content/posts/`, `content/blog/`, `src/content/blog/`, `_posts/`, `posts/`.
   - Read 1-3 existing posts in detected dir; parse frontmatter to infer schema.
   - Look for `sitemap.xml` (root) or `app/sitemap.{ts,js}` (Next.js).
   - Read `package.json` `homepage` and `README` for site URL hints.
3. Render config from the skill's `cfg-template.yaml` (path: `${SKILL_DIR}/cfg-template.yaml`) with detected values + sensible defaults; write to `<repo-root>/.write-blog.cfg`.
4. AskUserQuestion: show config, "Looks right?" — single confirmation. On "edit", let user revise then save.
5. If detection ambiguous (two viable post dirs, no clear framework) → ask user which to use before writing config.

**Failure mode:** Cannot detect at all → write minimal cfg with placeholders, ask user to fill in posts dir + URL base before continuing.

### 1.8 Pre-gate Research Review

Apply Pre-gate Review Pattern to research notes + audience profile:

**Subagent prompts (3 parallel `Task` calls):**

1. *Relevance reviewer:* "Are research findings actually relevant to this audience? Flag any tangential facts that pad the post without serving the audience's goal."
2. *Gap reviewer:* "What's missing from research that this specific audience needs? Identify questions they'd have that aren't answered yet."
3. *Audience-fit reviewer:* "Are the cited stats / examples at the right scale and experience level for this audience? Flag mismatches."

Apply consensus fixes (rerun research where needed). Then present polished notes to user with light prompt:

> "Research direction looks like: [summary]. Proceed to outline, or refine?"

Wait for confirmation.

---

## Phase 2: Outline

### 2.1 Create Outline

```markdown
## Proposed Blog Post Outline

**Title:** [under 46 chars]
**Slug:** [kebab-case]
**Target Length:** [word count]

### Target Audience
**Who:** [from Phase 0] | **Goal:** [what they want] | **Constraints:** [limitations]

### Why This Helps THEM
- [gap it fills] | [question it answers] | [constraint it addresses]

### Structure (APP Formula)

1. **Hook** — AGREE: [their pain] → PROMISE: [benefit] → PREVIEW: [roadmap]
2. **Problem** — as THEY experience it, stats at their context (AUTHORITY)
3. **Prerequisites** — only if needed, quick primer or link out
4. **Solution** — why it fits THEIR situation, credentials (AUTHORITY), alternatives (RECIPROCITY)
5. **Implementation** — steps at their level, code at their complexity, short paragraphs (5-6 lines max)
6. **Trade-offs** — honest, relevant to their situation/scale (LIKING)
7. **Results** — metrics at their scale, "others have seen..." (SOCIAL PROOF)
8. **Is This Right for You?** — good fit / not good fit / middle-ground
9. **Closing** — personal note, **end with question** (drives engagement)

### Differentiation Checklist
- [ ] Addresses THEIR specific situation
- [ ] At THEIR experience level
- [ ] Answers THEIR questions
- [ ] Respects THEIR constraints
```

### 2.3 Expert Outline Review (runs BEFORE Gate 1)

Per Pre-gate Review Pattern. Pick 3 experts based on topic:

| Subject Area | Good Picks |
|---|---|
| AI/LLM tooling | Simon Willison, Swyx, Andrej Karpathy |
| React/Frontend | Dan Abramov, Kent C. Dodds, Guillermo Rauch |
| DevOps/Infrastructure | Charity Majors, Kelsey Hightower, Julia Evans |
| Systems/Performance | Thorsten Ball, Julia Evans, Dan Luu |
| Business/SaaS | Patrick McKenzie (patio11), Sahil Lavingia, Swyx |
| Security | Troy Hunt, tptacek, Julia Evans |
| Developer experience | Swyx, Cassidy Williams, Guillermo Rauch |

Don't force-fit — match expert to actual topic.

**Subagent prompt per expert (`Task` tool):**

```
You are [Expert Name], known for [specialty] at [blog/site].
Review this blog OUTLINE for audience: [audience]. Be specific, direct.
Focus on: Would you click this title? Structure compelling or listicle-feeling?
Strongest/weakest section? Would it get shared on Twitter/HN? Missing anything?
[insert outline]
```

Run Loop-Integrity Filter Team on the three persona outputs (catch fabricated quotes, blanket harshness that misses what works, gaps in critique).

**Synthesize:**

```markdown
## Expert Outline Review
### [Expert] — [key feedback points]
### Where all 3 agree (high confidence): [consensus]
### Actionable changes: [specific changes]
```

**Apply consensus changes silently.** Then present polished outline to user.

### 2.2 GATE 1 — User Approves Polished Outline

AskUserQuestion options:
- **Approve outline** — proceed to writing
- **Adjust audience** — refine target
- **Revise structure** — change sections / flow
- **Change angle** — different value prop

Do NOT proceed until user approves.

<!-- PHASES_END -->

## Quick Reference

(filled in by later task)

## Credits

(filled in by later task)
