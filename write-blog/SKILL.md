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

---

## Phase 3: Write Draft

### 3.1 Writing Guidelines

**Audience-first:** Write at THEIR level, use THEIR language, address THEIR constraints, answer THEIR questions, give THEM actionable steps.

**DO:** First person, specific numbers with source links, relatable anecdotes, acknowledge uncertainty, vary sentence length, tables for comparisons, exit ramps ("If you're in situation X, try Y instead"), short paragraphs (5-6 lines max).

**BANNED AI Patterns:**
- Words: delve, crucial, enhance, foster, landscape, tapestry, underscore, pivotal, showcasing, vibrant, revolutionary, game-changing, seamless, robust, leverage, synergy, groundbreaking
- Patterns: "**Bold Header:** text" in lists, "It's not just X, it's Y", rule of three for everything, em dash (—) excess, "Additionally/Furthermore/Moreover" starters, generic conclusions, curly quotes

### 3.2 Blog Structure (APP + Persuasion)

```markdown
# [Title — speaks to THEIR situation]

<!-- APP FORMULA -->
[AGREE → PROMISE → PREVIEW]

## Problem (as THEY experience it)
## Quick Background (only if THEY need it — skip if they'd know)
## Solution (why it fits THEIR situation, alternatives for different constraints)
## Implementation (at THEIR level, code they can use)
## Trade-offs (relevant to THEM, honest)
## Results (at their scale, SOCIAL PROOF)
## Is This Right for You? (good fit / not good fit / middle-ground)
[Closing: personal note + question for engagement]

---

## References (bare list, links inserted in Phase 4.9)

- [topic-1]: <https://source.example/article-a>
- [topic-2]: <https://docs.example.com/section>
- [topic-3]: <https://blog.example/post>
```

**IMPORTANT:** Cite sources only as bare URLs in this list during Phase 3. Do NOT yet embed inline markdown links in prose. Phase 4.9 inserts curated links after fact-check + grading.

### 3.3 Frontmatter

```yaml
---
title: "[under 46 chars]"
slug: [kebab-case]
date: [ISO today]
last_updated: [ISO today]
excerpt: "[120-160 chars]"
feature_image: /images/posts/[slug]/header.jpg
featured: 1
type: post
status: published
visibility: public
show_title_and_feature_image: 1
---
```

(Field names follow `.write-blog.cfg` `frontmatter` schema; adjust if cfg overrides.)

### 3.4 Audience Check Per Section

After each section: Would [audience] understand? Am I explaining things they know? (cut) Assuming things they don't? (explain) At their scale? Helps them specifically?

---

## Phase 4: Pre-gate Review Bundle (runs BEFORE Gate 2)

### 4.1 Self-Review Checklist

**Audience Fit (most important):**
- [ ] Written for specific audience, not generic
- [ ] At their experience level
- [ ] Addresses their constraints
- [ ] Uses their language

**SEO:** Title <46 chars, excerpt 120-160, kebab slug, one H1, proper heading hierarchy.

**Content:** Reference list at bottom contains ≥5 candidate URLs (not inserted yet); comparison table; honest trade-offs; personal voice.

**AI Pattern Check:** No banned words, no em dash excess, no "Additionally/Furthermore/Moreover", no "**Bold:** text" lists, no generic conclusions.

### 4.5 Adversarial Fact Check (3 internal subagents, parallel)

**Subagent 1 — Skeptic:** Mark each claim VERIFIED / UNVERIFIABLE / SUSPICIOUS. Focus: numbers, before/after comparisons, implied causation, "most people" claims.

**Subagent 2 — Devil's Advocate:** Flag EXAGGERATION / MISSING CONTEXT / CHERRY PICKING / FALSE PRECISION / OVERSELLING. Suggest honest alternative phrasing for each.

**Subagent 3 — Consistency Checker:** Numbers match between sections? Opening claims match content? Contradictions? Title/meta accurate? Promises delivered? Code matches prose? Reference URLs cited correctly?

Run Loop-Integrity Filter on the three subagent outputs (catch fabricated "verified" statuses, missed claims, defensible claims wrongly flagged).

**Synthesize:**

```markdown
## Adversarial Fact Check Results
### Must Fix (wrong/misleading) — [finding, flagged by whom]
### Should Fix (exaggeration/missing context) — [finding, suggested fix]
### Internal Inconsistencies — [section X vs section Y]
### Passed — [areas all 3 agreed accurate]
```

**Fix all "Must Fix" before proceeding.** Same issue flagged by multiple subagents = almost certainly real.

### 4.7 Expert Draft Review (3 personas, "would share" gate)

Same 3 experts from Phase 2.3 review the complete draft.

**Subagent prompt per expert (`Task` tool):**

```
You are [Expert Name]. Review this COMPLETE blog post for audience: [audience]. Be harsh.
Focus on: Opening earn attention in 3 sentences? Strongest/weakest section?
Would you share with your audience? Why/why not? Twitter/HN shareable?
Hand-waving instead of specifics? Honest content ring true or performed?
Technical depth right? Claims credible? Pacing issues?
[insert full draft]
```

Run Loop-Integrity Filter on persona outputs.

**Synthesize:**

```markdown
## Expert Draft Review
### [Expert] — Would share? [YES/NO] | Strongest: [x] | Weakest: [x] | Key feedback: [points]

### "Would they share it" test:
- 3/3 → proceed to user gate
- 2/3 → fix consensus weak points silently, then proceed
- 1/3 or 0/3 → STOP. Surface to user with diagnosis. May need structural rewrite.
```

**Bar: at least 2/3 would share.** If yes, apply consensus fixes silently. Retry budget: max 2 rounds.

### 4.2 GATE 2 — User Approves Polished Draft

After 4.5 Must-Fix applied AND 4.7 ≥2/3 share-bar passed AND consensus fixes applied:

AskUserQuestion options:
- Approve draft / Revise content / Adjust tone / Add-remove sections

Do NOT proceed until user approves.

---

## Phase 4.9: Link Curation & Insertion

**Inputs:** Approved draft (post-Gate 2) with bare reference list + `.write-blog.cfg` site profile.

### 4.9.1 Whitelist Tiers (External Links)

**T1 — auto-pass, no grading needed:**
- Official docs: `developer.mozilla.org`, `docs.python.org`, `react.dev`, `nodejs.org`, `tc39.es`, `w3.org`, `whatwg.org`, `rfc-editor.org`
- Reference: `wikipedia.org` (definitional links only)
- Standards bodies: `iso.org`, `ieee.org`

**T2 — graded, default keep if avg ≥6:**
- Established tech publications: `theverge.com`, `arstechnica.com`, `wired.com`
- Personal blogs of recognized experts
- Major company engineering blogs: `engineering.fb.com`, `netflixtechblog.com`, etc.

**T3 — graded, default drop unless avg ≥8:**
- Medium articles, dev.to articles, LinkedIn articles, random blogs

Repo extends T1 via `links.external.whitelist_t1` in `.write-blog.cfg`.

### 4.9.2 External Link Pipeline

For each `ref_url` in draft's bare reference list:

1. `domain = extract_domain(ref_url)`
2. If `domain in whitelist_T1` (global ∪ cfg overrides) → keep, skip grading.
3. Else, run **3-way value grade in parallel:**

   **Prompt template (used by all three graders):**

   ```
   Rate the value of <URL> for an audience: <audience profile>
   reading a section about <section topic>, in the context of this draft.

   Consider: authority of source, relevance to audience, freshness,
   uniqueness of information vs alternatives.

   Output ONLY valid JSON: {"score": N, "reasons": ["..."]}
   Score is 0-10 (0 = useless, 10 = essential).
   ```

   - `claude_grade` ← `Task` subagent
   - `codex_grade` ← `codex exec "<prompt>"`
   - `gemini_grade` ← `gemini -p "<prompt>"`

4. Run **Loop-Integrity Filter** on the three grade outputs (catch fabricated relevance claims; ensure none of the graders cite content they didn't fetch).
5. `avg = mean(scores)`. T2 keep if `avg ≥ 6`; T3 keep if `avg ≥ 8`; otherwise drop.

After all refs processed:

- Sort kept refs by `avg` desc.
- Truncate to `cfg.links.external.max` (default 10).
- If kept count `< cfg.links.external.min` (default 1) → **fail loud**: surface to user with full grade trace, ask to provide replacement URLs manually.

### 4.9.3 Internal Link Pipeline

Goal: 1-5 internal links to other posts/pages on the user's site that build topical authority.

1. **Discover post candidates:**
   - `posts = glob(cfg.posts.dir + "/" + cfg.posts.pattern)` relative to repo root.
   - For each `post` (excluding the current draft if it's already saved): parse frontmatter, extract `title`, `slug`, `tags`, `excerpt`.
   - Compute keyword overlap between draft body and post (title + tags + excerpt). Simple bag-of-words intersection over Jaccard is sufficient.

2. **Discover non-post candidates** (if `cfg.url.sitemap` set):
   - Fetch sitemap from `cfg.url.base + cfg.url.sitemap`.
   - Parse `<url><loc>` entries. For each non-post URL, fetch + extract `<title>` and `<meta name="description">`. Compute keyword overlap.

3. **Shortlist:** Top `2 * cfg.links.internal.max` candidates by overlap (default top 10).

4. **3-way grade** each shortlisted candidate using the same prompt template as 4.9.2 (URL = `cfg.url.base + cfg.url.post_path.replace("{slug}", slug)`).

5. Run **Loop-Integrity Filter** on grade outputs.

6. Keep candidates with `avg ≥ cfg.links.internal.rating_threshold` (default 6). Sort by `avg` desc. Truncate to `cfg.links.internal.max` (default 5).

7. If kept count `< cfg.links.internal.min` (default 1) → **fail loud**: surface top-3 candidates by raw overlap with grade trace, ask user to pick or skip.

### 4.9.4 Insertion

For each kept link (external + internal):

1. Locate sentence/phrase in prose that matches the link's topic.
2. Pick natural anchor text (descriptive — not "click here", not bare URL, not the same anchor twice).
3. Insert markdown link: `[anchor](URL)`. For internal links use `cfg.url.internal_link_style` (relative / absolute / site-relative).

**Mechanical placement review (no user gate, fix silently):**
- No more than 2 links per paragraph.
- Don't cluster all links at top or bottom — distribute through body.
- Anchor text varies; no repetition.
- If a link can't find a natural anchor in prose, place it in a "Further reading" footer block.

Remove the bare reference list at the bottom of the draft once links are inserted (the curated link set replaces it).

### 4.9.5 Final Link Audit Report

Append to phase output (internal log; not part of post):

```markdown
## Link Curation Report
**External:** [N] kept (T1 auto-pass: [X], graded-keep: [Y], dropped: [Z])
**Internal:** [N] kept (graded-keep: [X], dropped: [Y])
**Hard caps respected:** ext [N]/10, int [N]/5
**Min thresholds met:** ext ≥1 ✅, int ≥1 ✅
```

---

## Phase 5: Iterative Humanization Loop

**Goal:** Drive avg AI-likelihood score below 10 (0-100 scale, lower = more human) using `humanizer` skill + multi-model detection. Max 5 iterations.

### 5.1 Voice Calibration (one-time, before loop)

Read 2-3 of the author's existing posts (from `cfg.posts.dir`). Note: typical sentence length, humor pattern, directness, transitions.

### 5.2 Loop

```
iteration = 0
while iteration < cfg.humanize.max_iterations (default 5):
    iteration += 1

    # 1. Run humanizer
    invoke /humanizer on the full draft
        (on iteration ≥ 2, pass detector reasons as focus arg:
         /humanizer "focus on: <reasons from previous detection>")

    # 2. Loop-Integrity Filter on humanizer output
    parallel Task subagents:
      - Loss Detector: did humanizer strip technical detail?
      - Gap Finder: any audience question lost?
      - Hallucination Hunter: did humanizer invent anecdote / stat?
    apply consensus fixes

    # 3. AI-detection vote (parallel)
    codex_score  = codex exec "<detection prompt>"
    gemini_score = gemini -p "<detection prompt>"

    # 4. Compute avg + log
    avg = mean(codex_score, gemini_score)
    log {iteration, codex_score, gemini_score, avg, reasons}

    # 5. Pass / continue / cap
    if avg < cfg.humanize.target_score (default 10):
        EXIT loop  # PASS
    elif iteration == max:
        SURFACE to user (see 5.4)
    else:
        carry detector reasons into next humanizer pass
```

### 5.3 Detection Prompt (used by both codex and gemini)

```
You are an AI-text detector. Rate the following text 0-100 where:
- 0   = clearly human-written, idiosyncratic, varied, opinionated
- 100 = clearly AI-generated, formulaic, neutral, predictable

Output ONLY valid JSON: {"score": N, "reasons": ["..."]}

Text:
<<<
[full draft body]
>>>
```

Score interpretation:
- avg < 10 → **pass**
- 10-30 → minor patterns, continue
- 30-60 → moderate AI feel, continue with feedback
- 60+ → strong AI signature, escalate after iteration 3

### 5.4 Cap Reached Without Pass

If after 5 iterations avg ≥ 10:

```markdown
## Humanization Loop — Cap Reached
| Iter | codex | gemini | avg | top reasons |
|------|-------|--------|-----|-------------|
| 1 | ... | ... | ... | ... |
| ... |
| 5 | ... | ... | ... | ... |
```

AskUserQuestion:
- Accept current state (publish despite score)
- Apply targeted manual fix on flagged sections
- Abandon — restructure draft

### 5.5 Both External CLIs Fail

If neither codex nor gemini responds in a given iteration: skip detection that iteration, run 2 fixed humanizer passes (current + one more), present to user with note "AI-detection unavailable; humanizer ran 2 fixed passes."

If only one CLI responds: continue with single-detector mode (no avg, just that score). Flag in final report.

---

## Phase 5.x: Lint Check

```bash
which vale && vale content/posts/[slug].md
# Or per repo: npm run lint
```

Report lint errors for awareness; non-blocking unless severe.

---

## Phase 6: Header Image (MANDATORY)

**CRITICAL: No sci-fi, no abstract AI art, no futuristic imagery.**

### 6.1 Prompt Rules

**REQUIRED:** Real humans / workspaces, natural settings, authentic environments, natural lighting, candid moments, MacBook Pro / iPhone 16 Pro Max if devices shown, "No text overlays" appended.

**BANNED:** Sci-fi/futuristic, abstract geometric, glowing/neon, robots/AI imagery, isometric, "digital"/"cyber", floating UI, stock cliches (handshakes, pointing at screens).

### 6.2 Generate via Gemini Browser

1. Open `https://gemini.google.com/app` in new tab.
2. Click "Create image" tool button.
3. Enter prompt, click "Send message".
4. Wait 15-20 seconds.

### 6.3 Download

```javascript
const img = document.querySelector('img[alt=", AI generated"]');
const canvas = document.createElement('canvas');
canvas.width = img.naturalWidth;
canvas.height = img.naturalHeight;
canvas.getContext('2d').drawImage(img, 0, 0);
const a = document.createElement('a');
a.href = canvas.toDataURL('image/png');
a.download = '[slug]-header.png';
document.body.appendChild(a);
a.click();
document.body.removeChild(a);
```

### 6.4 Crop & Optimize

```bash
mkdir -p [cfg.images.posts_dir]/[slug]/
cp ~/Downloads/tmp/[slug]-header.png [cfg.images.posts_dir]/[slug]/header.png
sips --cropToHeightWidth [height-60] [width-60] [cfg.images.posts_dir]/[slug]/header.png
[cfg.images.optimizer_cmd]   # e.g. npm run optimize-images
```

Verify watermark removed by reading image. Update frontmatter `feature_image` to match path.

If Chrome tools unavailable: `pbcopy` the prompt, ask user to generate manually, provide crop/optimize commands.

---

## Phase 7: Write File

Write to `[cfg.posts.dir]/[slug].md` with full markdown + frontmatter (per `cfg.frontmatter` schema).

---

## Phase 8: Visual Testing (MANDATORY)

### 8.1 Ensure Dev Server Running

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3021/ || npm run dev &
```

(Port from project conventions; default 3021.)

### 8.2 Open in Chrome

Navigate to `http://localhost:3021/[slug]` (or whatever URL pattern matches `cfg.url.post_path`).

### 8.3 Visual Checklist (scroll full page, screenshot each viewport)

- **Layout:** Header image loads, title renders, all headings render as headings, no raw markdown visible.
- **Code Blocks:** Syntax highlighting, no horizontal overflow, no broken fences.
- **Images:** All load, SVGs render, reasonable sizing.
- **Content:** Tables render as tables, links clickable, bold/italic correct, lists render properly.
- **Spacing:** No huge gaps, no jammed sections, proper code block margins.

### 8.5 Internal Review of Rendered Output (Pre-gate)

After capturing screenshots, run 3 parallel Task subagents on the screenshots + rendered HTML:

1. *Mechanical issues:* "Any broken markdown rendering, missing image, raw frontmatter showing? Flag specifics."
2. *Spacing/layout:* "Any obvious layout breakage — squished sections, huge gaps, cut-off code blocks?"
3. *Link integrity:* "Any link that visually looks broken (404, missing anchor)? Cross-check against insertion log."

Apply consensus mechanical fixes silently (these are formatting bugs, no taste call).

Only escalate to user if a real problem requires content change (e.g., a section that doesn't render).

If Chrome tools unavailable: ask user to preview at `http://localhost:3021/[slug]` and confirm.

### 8.6 Final Summary

```markdown
## Blog Post Created

**File:** `[cfg.posts.dir]/[slug].md`
**Title:** [title] ([X] chars) | **Meta:** [excerpt] ([X] chars)
**Word Count:** ~[X]
**External links:** [N]/10 | **Internal links:** [N]/5
**Humanize avg score:** [N]/100 (after [I] iterations)
**Target Audience:** [who] | **How It Helps:** [specific value]

### Next Steps
1. Image already generated and optimized.
2. Preview: `npm run dev` → `/[slug]`
3. Commit when ready.
```

---

## Phase 9: Optional Commit

If user wants:

```bash
git add [cfg.posts.dir]/[slug].md [cfg.images.posts_dir]/[slug]/
git commit -m "Add blog post: [title]"
```

Or invoke `/commit`.

---

## Failure Modes & User Escalation

| Failure | Behavior |
|---|---|
| Site profile detection ambiguous | Ask user which posts dir |
| Internal link candidates < 1 after grading | Fail loud, present top-3 by raw overlap |
| External link candidates < 1 after grading | Fail loud, ask user for replacement URLs |
| Humanization cap (5 iter) hit, avg ≥ 10 | Surface trace; accept / manual fix / restructure |
| Pre-gate review retries (2) exhausted | Escalate to user with diagnosis |
| Codex CLI fails | Continue with Gemini only, flag in summary |
| Gemini CLI fails | Continue with Codex only, flag in summary |
| Both external CLIs fail (humanize) | Skip detection, 2 fixed humanizer passes, flag |
| Both external CLIs fail (link grade) | Drop to Claude-only, surface to user before insertion |

---

## Handling Feedback

| Feedback | Action |
|----------|--------|
| "Too specific" | Broaden audience |
| "Too generic" | Add codebase examples |
| "Sounds AI-written" | Re-run Phase 5 humanize loop |
| "Missing [topic]" | Research + add section |
| "Too long" | Consolidate |
| "Needs more sources" | Add to bare reference list, re-run Phase 4.9 |
| "Title too long" | Shorten to <46 chars |
| "Not my voice" | Ask for voice examples; re-run Phase 5 |

---

## Quick Reference

```
Workflow: Audience → Research → Site Profile → Outline → Expert Review → [GATE 1]
       → Draft (with bare ref list) → Fact Check + Expert Review → [GATE 2]
       → Link Curation (3-way grade) → Iterative Humanize Loop (max 5, avg<10)
       → Lint → Image → Write → Visual Test → Commit

REQUIRED: Target audience (ask if missing)
MANDATORY: Humanization loop (run until avg<10 or max 5 passes)
Title: max 46 chars (60 with suffix)
Meta: 120-160 chars
External links: ≥1, ≤10 (per cfg)
Internal links: ≥1, ≤5 (per cfg)
External CLIs: codex exec / gemini -p
Pre-gate review on every artifact (3-subagent team)
Loop-integrity filter inside every iterative loop

APP: AGREE → PROMISE → PREVIEW
Cialdini: Reciprocity, Authority, Social Proof, Liking, Scarcity, Consistency
Images: Human/realistic/natural — NO sci-fi/abstract/AI art
```

---

## Credits

**[Joe Karlsson](https://www.joekarlsson.com/2025/10/building-a-claude-code-blog-skill-what-i-learned-systematizing-content-creation/)** — Two approval gates, automated linting, encode standards.

**[Neil Patel](https://neilpatel.com/blog/how-to-write-blog-post/)** — APP Formula, short paragraphs, end with question, subheadings for skimmability.

**[Robert Cialdini](https://www.influenceatwork.com/)** — 6 Principles of Persuasion applied to content.

**v5 (2026-05-01):** Iterative humanization with multi-model detection (codex + gemini), per-repo `.write-blog.cfg`, link curation with 3-way value grading, pre-gate review pattern, loop-integrity filter team.
