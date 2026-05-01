---
name: write-blog
version: 5.0.0
description: |
  Write a complete blog post with iterative humanization (multi-model AI-detection
  via codex + gemini, target avg score < 25, max 3 passes — scores treated as lint
  signals, not hard gates), pre-gate agent-team
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
5. **Iterative humanization** — loop until avg AI-likelihood < 25 (max 3 passes), multi-model detection. Scores are lint signals; cap-reached surfaces to user, never publishes silently.
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
Phase 5: Iterative Humanization Loop (max 3; codex + gemini detect; target avg < 25)
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

Applies to: Phase 2.3 (outline) and Phase 4.5+4.7 (draft) — the high-stakes gates. Phase 1.8 (research) uses a single-subagent light check instead. Phase 8.5 (rendered output) uses a 3-subagent mechanical check (no retry budget — it's just formatting bugs).

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

Applies inside: Phase 5 (humanization, per iteration — content is being transformed), Phase 4.9 (link grading per candidate — graders may hallucinate content). Skipped on: Phase 4.5 fact-check, Phase 2.3 + 4.7 expert reviews — those are already 3-way consensus reviews on unchanged source content, so the cross-validation LIF would provide is redundant.

### Heartbeat (per-phase status log)

At the start of every phase, print one short status line to the user so they can see progress instead of staring at silence:

```
[Phase 4.9] Grading 8 external + 5 internal link candidates...
[Phase 5 iter 2] Running humanizer (focus: <top-3 reasons>)...
[Phase 8.1] Starting dev server, watching stdout for URL (timeout: 30s)...
```

Format: `[Phase N.x] <verb-ing> <object>...` — single line, single sentence, present-continuous, no preamble. Skip the heartbeat for trivially fast steps (`< 2s`); use it for any step likely to take more than ~5 seconds.

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

### 1.8 Light Research Sanity Check (NOT full pre-gate review)

Research notes are low-blast-radius — outline (Phase 2) and draft (Phase 3) are where errors compound. So this step is intentionally lightweight: a single `Task` subagent reviews the research notes + audience profile and answers three questions:

> "Looking at this research:
> 1. Any tangential facts that don't serve the audience's goal?
> 2. Any obvious gap (a question this audience would ask that isn't answered)?
> 3. Are stats/examples at the right scale for this audience?
> Output: TANGENTIAL=[list], GAP=[list], SCALE_MISMATCH=[list], or "none" for each."

Address only items the subagent flags concretely (don't speculate). Skip if all three return "none". No retry budget — this is one shot before user.

Then present to user with a light prompt:

> "Research direction looks like: [summary]. Proceed to outline, or refine?"

Wait for confirmation. Full pre-gate-review pattern (3 subagents, retry budget) kicks in at Phase 2.3 (outline) and 4.5+4.7 (draft) where stakes justify the cost.

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

(LIF removed at this step: the 3-persona consensus already provides cross-validation. LIF is reserved for transformation steps like humanization where one artifact mutates content; expert review produces three independent critiques, which already gives the disagreement signal.)

**Synthesize:**

```markdown
## Expert Outline Review
### [Expert] — [key feedback points]
### Where all 3 agree (high confidence): [consensus]
### Actionable changes: [specific changes]
```

**Apply consensus changes silently.** Then present polished outline to user.

### 2.4 GATE 1 — User Approves Polished Outline

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

**Run 4.5 and 4.7 in parallel.** They read the same draft, produce independent findings, and have no shared state. Dispatch both via `Task` at the same time; collect results when both finish; then apply consensus fixes from each. Sequential phasing here adds latency for no benefit.

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

(LIF removed here for the same reason as Phase 2.3 — three personas already provide consensus.)

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

### 4.8 GATE 2 — User Approves Polished Draft

After 4.5 Must-Fix applied AND 4.7 ≥2/3 share-bar passed AND consensus fixes applied (this is sub-phase 4.8 in document order, despite the v4-legacy "GATE 2" name):

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

**T2 — graded, keep if avg ≥ `cfg.links.external.rating_threshold` (default 6):**
- Established tech publications: `theverge.com`, `arstechnica.com`, `wired.com`
- Personal blogs of recognized experts
- Major company engineering blogs: `engineering.fb.com`, `netflixtechblog.com`, etc.

**T3 — graded, default drop unless avg ≥ `cfg.links.external.t3_rating_threshold` (default 8):**
- Medium articles, dev.to articles, LinkedIn articles, random blogs

Repo extends T1 via `links.external.whitelist_t1` in `.write-blog.cfg`.

### 4.9.2 External Link Pipeline

For each `ref_url` in draft's bare reference list:

1. `domain = extract_domain(ref_url)`
2. **Pre-grade fetch (mandatory):** `fetched_content = WebFetch(ref_url, "extract: title, author, publish_date, body main content (first cfg.link_grade.fetch_excerpt_words words, default 1500), paywall_indicator")`. If WebFetch fails (404, timeout, blocked) → drop URL, log reason, do not grade.
3. **T1 lightweight relevance check** (not full grade — just one Task subagent call): "Does this T1 source's fetched content actually address `<section topic>` for `<audience>`? Yes / No / Tangential." Yes → keep. No / Tangential → drop. Reasoning: official docs are authoritative but not always relevant; auto-pass authority, not insertion.
4. **T2 / T3 / unknown — 3-way value grade in parallel** using the fetched content:

   **Prompt template (used by all three graders, same body for each):**

   ```
   Rate the value of this external link for an audience: <audience profile>
   reading a section about <section topic>, in the context of this draft.

   Source URL: <ref_url>
   Fetched title: <fetched_content.title>
   Fetched author: <fetched_content.author>
   Fetched publish date: <fetched_content.publish_date>
   Fetched body excerpt:
   <<<
   <fetched_content.body[:cfg.link_grade.fetch_excerpt_words]>
   >>>
   Paywall indicator: <fetched_content.paywall_indicator>

   Score 0-10 on each dimension, then average:
   - Authority (source credibility on this topic)
   - Relevance (does the fetched body actually address the section topic?)
   - Freshness (current enough for this audience?)
   - UX (no hard paywall, no broken layout, no excessive ads)
   - Uniqueness (adds something the draft doesn't already cover)

   Output ONLY valid JSON: {"score": N, "dimensions": {authority: N, relevance: N, freshness: N, ux: N, uniqueness: N}, "reasons": ["..."]}
   ```

   - `claude_grade` ← `Task` subagent dispatched as:
     ```
     Task(description="Grade external link", prompt="<full prompt above with substitutions>")
     ```
     Pass: full audience profile, section topic, fetched_content fields. Subagent returns JSON.
   - `codex_grade` ← `codex exec "<full prompt above>"` with same substitutions.
   - `gemini_grade` ← `gemini --skip-trust -p "<full prompt above>"` with same substitutions.

   **JSON parse fallback:** If a grader's stdout doesn't parse cleanly, regex-extract the first `{...}` block. If still unparseable, treat that grader as failed and continue with the other two. If 2+ fail, treat as CLI failure (Section 5.5 fallback).

5. Run **Loop-Integrity Filter** on the three grade outputs (catch fabricated relevance claims; ensure graders' reasoning aligns with `fetched_content.body` rather than URL slug).
6. `avg = mean(scores)`. T2 keep if `avg ≥ cfg.links.external.rating_threshold` (default 6); T3 keep if `avg ≥ cfg.links.external.t3_rating_threshold` (default 8); otherwise drop.

After all refs processed:

- Sort kept refs by `avg` desc.
- Truncate to `cfg.links.external.max` (default 10).
- If kept count `< cfg.links.external.min` (default 1) → **fail loud**:

  ```
  AskUserQuestion("External link minimum (≥1) not met after grading.

  Graded results:
  [paste grade trace: URL | scores | drop reason]

  Choose:
  - Provide replacement URL(s) manually (paste below)
  - Lower min to 0 for this post (allow zero external links)
  - Restart Phase 4.9.2 with broader source search")
  ```

### 4.9.3 Internal Link Pipeline

Goal: 1-5 internal links to other posts/pages on the user's site that build topical authority.

1. **Discover post candidates:**
   - `posts = glob(cfg.posts.dir + "/" + cfg.posts.pattern)` relative to repo root.
   - For each `post` (excluding the current draft if it's already saved): parse frontmatter, extract values from fields named in cfg: `cfg.posts.title_field`, `cfg.posts.slug_field`, `cfg.posts.tags_field` (skip if `null`), `cfg.posts.excerpt_field`.
   - Compute keyword overlap between draft body and post (concatenated title + tags + excerpt fields). Bag-of-words intersection over Jaccard is sufficient.

2. **Discover non-post candidates** (if `cfg.url.sitemap` set):
   - Fetch sitemap from `cfg.url.base + cfg.url.sitemap` via WebFetch.
   - Parse `<url><loc>` entries. For each non-post URL, WebFetch + extract `<title>` and `<meta name="description">`. Compute keyword overlap.

3. **Shortlist:** Top `cfg.link_grade.shortlist_multiplier * cfg.links.internal.max` candidates by overlap (default 2 × 5 = 10).

4. **Pre-grade fetch** (already covered for non-post candidates in step 2; for post candidates, the frontmatter title + excerpt are sufficient — no extra fetch needed since posts live in the local repo).

5. **3-way grade** each shortlisted candidate using the 4.9.2 prompt template adapted for internal links (URL = `cfg.url.base + cfg.url.post_path.replace("{slug}", slug_value)`; `fetched_content` = local frontmatter excerpt for posts, or fetched HTML title+description for non-post pages).

6. Run **Loop-Integrity Filter** on grade outputs.

7. Keep candidates with `avg ≥ cfg.links.internal.rating_threshold` (default 6). Sort by `avg` desc. Truncate to `cfg.links.internal.max` (default 5).

8. If kept count `< cfg.links.internal.min` (default 1) → **fail loud**:

   ```
   AskUserQuestion("Internal link minimum (≥1) not met after grading.

   Top-N candidates by raw keyword overlap (N = cfg.link_grade.fail_loud_top_n, default 3) with grade trace:
   [paste: post title | overlap score | grade avg | drop reason]

   Choose:
   - Insert candidate #1 anyway (override grade)
   - Insert candidate #2 anyway
   - Insert candidate #3 anyway
   - Skip internal links for this post (sparse-site override; document reason)
   - Provide a manual internal URL")
   ```

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

**Goal:** Drive avg AI-likelihood score below 25 (0-100 scale, lower = more human) using `humanizer` skill + multi-model detection. Max 5 iterations.

**Why 25, not 10?** External LLM "AI detectors" (codex + gemini) are not calibrated detectors — they are subjective judges using a prompt. Real human technical writing typically scores 15-25 because of necessary formal structures (lists, headings, code blocks, qualifying phrases). Forcing avg<10 risks over-humanizing into uncanny territory: fake quirks, lost technical precision, choppy pacing. The 25 ceiling is a *lint signal*: below it = clean; above it = inspect, don't auto-fail.

### 5.1 Voice Calibration (one-time, before loop)

Read 2-3 of the author's existing posts (from `cfg.posts.dir`). Build a `voice_profile` string capturing: typical sentence length range, humor pattern (dry / direct / none), directness level, common transition words, signature phrases.

**This `voice_profile` is passed into every `/humanizer` invocation in the loop** as part of the focus arg, so the humanizer aligns rewrites with the author's existing voice rather than a generic "more human" target.

### 5.2 Loop

**State contract:** `draft_v0` is the post-Gate-2 + post-link-curation draft (full markdown body, including frontmatter and inserted links). Each iteration produces `draft_v{N}` which becomes input to iteration N+1. The humanizer skill's contract: it takes a markdown body (and optional focus arg), returns a rewritten markdown body of the same shape — preserving frontmatter, code blocks, link URLs, and structure, while rewriting prose.

```
draft_v0 = post-Gate-2, post-link-insertion draft
detector_reasons = []
iteration = 0

while iteration < cfg.humanize.max_iterations (default 3):
    iteration += 1

    # 1. Run humanizer
    focus_arg = f"voice_profile: {voice_profile}; focus on: {detector_reasons}"
    draft_v{iteration} = invoke /humanizer with input=draft_v{iteration-1}, focus=focus_arg
    # /humanizer returns the rewritten full markdown body

    # 2. Loop-Integrity Filter on draft_v{iteration} vs draft_v{iteration-1}
    parallel Task subagents (each gets BOTH versions for diff analysis):
      - Loss Detector: did humanizer strip technical detail or signal?
      - Gap Finder: any audience question now unanswered that was answered before?
      - Hallucination Hunter: did humanizer invent anecdote / stat / quote not in draft_v{iteration-1}?
    apply consensus fixes by reverting flagged passages from draft_v{iteration-1}
    → updated draft_v{iteration}

    # 3. AI-detection vote (parallel) on draft_v{iteration}
    codex_response  = codex exec "<detection prompt with draft_v{iteration} body>"
    gemini_response = gemini --skip-trust -p "<detection prompt with draft_v{iteration} body>"

    # 4. Parse with JSON fallback
    for resp in [codex_response, gemini_response]:
        try: parse JSON directly
        except: regex-extract first {...} block, parse that
        if still failing: mark detector as failed for this iteration
    if both detectors failed: apply Section 5.5 fallback
    if one failed: continue with single-detector mode

    # 5. Compute avg + log
    avg = mean of valid scores
    iteration_log.append({iteration, codex_score, gemini_score, avg, reasons})

    # 6. Pass / continue / cap
    if avg < cfg.humanize.target_score (default 25):
        draft_final = draft_v{iteration}
        EXIT loop  # PASS — proceed to 5.6
    elif iteration == cfg.humanize.max_iterations:
        SURFACE to user (see 5.4)
    else:
        detector_reasons = top 3 reasons across both detectors
        # next iteration uses these as focus arg
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

Score interpretation (lint bands, all from cfg.humanize.*; not hard gates):
- avg < `target_score` (default 25) → **clean**, exit loop
- `band_noticeable`-`band_strong` (default 25-40) → noticeable patterns, continue with detector reasons fed back into next humanizer pass
- `band_strong`-`band_critical` (default 40-60) → strong AI signature, continue + escalate after iteration 3 with "Loss Detector veto" check (don't strip technical signal to hit a number)
- ≥ `band_critical` (default 60) → fundamental issue, surface to user immediately for restructuring decision

### 5.4 Cap Reached Without Pass

If after 5 iterations avg ≥ 25:

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

### 5.6 Post-Humanize Link & Claim Audit (MANDATORY)

The humanizer can rewrite anchors, soften qualifiers, drop caveats, or change wording around cited claims. After loop exits (PASS or cap), run this audit on the deltas between pre-humanize draft and post-humanize draft:

**Step 1 — Link integrity check (mechanical):**

```
for each link inserted in Phase 4.9:
  - confirm the URL is unchanged (humanizer must not alter URLs)
  - confirm the anchor text still exists in surrounding prose and reads naturally
  - if anchor was removed or orphaned → reinsert at next best matching sentence
  - if URL was altered → restore to original
```

**Step 2 — Claim-delta check (3 parallel `Task` subagents on the diff):**

1. *Citation-claim auditor:* "For each linked claim in the post, does the prose still match what the cited source supports? Flag any claim that humanizer softened, exaggerated, or detached from its citation."
2. *Caveat preservation auditor:* "Did humanizer drop hedging, qualifiers, or scope limits that fact-check (Phase 4.5) had specifically required? List dropped caveats."
3. *Number/stat auditor:* "Are all numbers, percentages, and dates from Phase 4.5's VERIFIED set still present and unchanged? Flag any silently rewritten figure."

**Step 3 — Apply consensus fixes:**

- 3/3 or 2/3 agreement on a flagged item → restore from pre-humanize draft (claim, caveat, or number)
- 1/3 → log only

**Step 4 — Final summary line:**

Append to Phase 8.6 summary: `Link integrity: [N]/[N] preserved | Claim audit: [N] restorations`

If restorations > 0, optionally re-run Phase 5 ONE more pass with focus arg `"preserve restored claims and links verbatim"`. Only one extra pass — do not iterate further on this loop.

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
# Crop cfg.images.watermark_crop_px from each edge (default 60) to remove generator watermark.
# Read source dimensions first, subtract 2 * watermark_crop_px from height and width.
sips --cropToHeightWidth $((H - 2*$WCP)) $((W - 2*$WCP)) [cfg.images.posts_dir]/[slug]/header.png
# where H, W = source height/width via `sips -g pixelHeight -g pixelWidth`,
# and WCP = cfg.images.watermark_crop_px (default 60)
[cfg.images.optimizer_cmd]   # e.g. npm run optimize-images
```

Verify watermark removed by reading image. Update frontmatter `feature_image` to match path.

If Chrome tools unavailable: `pbcopy` the prompt, ask user to generate manually, provide crop/optimize commands.

---

## Phase 7: Write File

Write to `[cfg.posts.dir]/[slug].md` with full markdown + frontmatter (per `cfg.frontmatter` schema).

---

## Phase 8: Visual Testing (MANDATORY)

### 8.1 Ensure Dev Server Running and Discover Its URL

Never hardcode the dev server URL. The dev server (Next.js, Astro, Vite, etc.) prints its actual URL on startup, and that may differ across runs (different port if 3000 is busy, IPv6 binding, https when configured). Capture it from the server's stdout.

```bash
# Step 1: only check fallback_url to see if a dev server is already up.
# (Don't hardcode a port list — the dev server prints its own URL when started.)
DEV_URL=""
if curl -s -o /dev/null -w "%{http_code}" "$cfg.dev.fallback_url/" 2>/dev/null | grep -qE "^(200|301|302|404)$"; then
    DEV_URL="$cfg.dev.fallback_url"
    echo "Detected existing dev server at $DEV_URL — not starting a new one."
fi

# Step 2: if nothing answered, start the server and parse its stdout for the URL
if [ -z "$DEV_URL" ]; then
    LOG=$(mktemp)
    eval "$cfg.dev.cmd" > "$LOG" 2>&1 &
    SERVER_PID=$!
    # Poll log up to cfg.dev.startup_timeout_seconds for a URL matching cfg.dev.url_regex
    DEADLINE=$(( $(date +%s) + cfg.dev.startup_timeout_seconds ))
    while [ $(date +%s) -lt $DEADLINE ]; do
        DEV_URL=$(grep -oE "$cfg.dev.url_regex" "$LOG" | head -1)
        [ -n "$DEV_URL" ] && break
        sleep 1
    done
    if [ -z "$DEV_URL" ]; then
        echo "Dev server did not print URL within timeout; using fallback $cfg.dev.fallback_url"
        DEV_URL="$cfg.dev.fallback_url"
    fi
fi
echo "DEV_URL=$DEV_URL"
```

**Important:** never kill `$SERVER_PID` if the user already had a dev server running (per CLAUDE.md "Never kill external processes"). Only stop servers this skill itself started.

### 8.2 Open in Chrome

Navigate to `$DEV_URL + cfg.url.post_path.replace("{slug}", slug)`.

Example: if the dev server prints `http://localhost:3000` and `cfg.url.post_path = "/blog/{slug}"`, the preview URL is `http://localhost:3000/blog/[slug]`.

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

If Chrome tools unavailable: ask user to preview at `$DEV_URL + cfg.url.post_path` (substituted with slug) and confirm.

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
2. Preview: `cfg.dev.cmd` → `$DEV_URL/[slug]` (URL captured from dev-server stdout in 8.1)
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
| Humanization cap (5 iter) hit, avg ≥ 25 | Surface trace; accept / manual fix / restructure |
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
       → Link Curation (3-way grade) → Iterative Humanize Loop (max 3, avg<25)
       → Lint → Image → Write → Visual Test → Commit

REQUIRED: Target audience (ask if missing)
MANDATORY: Humanization loop (run until avg<25 or max 3 passes; scores are lint signals)
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
