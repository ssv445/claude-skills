---
name: write-blog
version: 4.0.0
description: |
  Write a complete blog post with expert persona reviews, adversarial fact-checking,
  GSC keyword research, automated image generation, visual testing, and mandatory
  humanization. Every outline and draft is reviewed by 3 topic-relevant tech writer
  personas (e.g., Simon Willison, Julia Evans, Swyx) who evaluate shareability.
  The bar: at least 2/3 experts would share the post before it proceeds.
  v4: Added expert persona reviews at outline AND draft stages, with
  topic-matched expert selection and "would they share it" quality gate.
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

Technical blog writer. Structured workflow with two approval gates.

## Core Principles

1. **Target audience REQUIRED** — ask if not provided, never proceed without it
2. **APP formula** for hooks, **Cialdini** for engagement
3. **Two approval gates** — outline + draft, saves rewrite time
4. **ALWAYS humanize** — mandatory, never skip
5. **Human imagery only** — realistic/natural, never sci-fi or abstract AI art

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
Phase 0: Audience Definition ──►
Phase 1: Research + GSC Keywords ──► Phase 2: Outline ──► [GATE 1] ──►
Phase 2.3: Expert Outline Review (3 personas) ──►
Phase 3: Draft ──► [GATE 2] ──►
Phase 4.5: Adversarial Fact Check (3 subagents) ──►
Phase 4.7: Expert Draft Review (3 personas, 2/3 must "would share") ──►
Phase 5: Polish, Lint & Humanize ──► Phase 6: Header Image (Gemini) ──►
Phase 7: Write File ──► Phase 8: Visual Testing (Chrome) ──► Phase 9: Optional Commit
```

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
**Who:** [Specific description]
**Experience Level:** [Beginner/Intermediate/Advanced with THIS topic]
**Current Situation:** [Pain they have]
**Goal:** [What they want]
**Constraints:** [Time, budget, team, stack]

### Already Know
- [Assumed knowledge]

### Don't Know (gaps to fill)
- [Knowledge gap]

### Likely Questions
- [Question they'd ask]
- [Objection they'd have]

### What Makes This Useful to Them
- [Specific outcome]
```

**Keep profile visible throughout all phases. Every decision references it.**

---

## Phase 1: Research

### 1.1 Load SEO Rules

Read `.claude/SEO-RULES.md` if exists. Extract: title max length (usually 46 chars + suffix), meta description (120-160), image requirements, URL format.

### 1.2 GSC Keyword Research (if MCP available)

**Step 1:** Find existing rankings for topic — `enhanced_search_analytics` with `queryFilter: [topic]`, `filterOperator: "contains"`, 90-day range, `rowLimit: 50`

**Step 2:** Find quick wins — same query with `enableQuickWins: true`. Queries ranking 4-10 with low CTR = ideal title/heading candidates.

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

Explore for relatable examples: challenges audience would face, solutions at their complexity level, relevant metrics.

### 1.6 Compile Research Notes

```markdown
## Target Audience Reminder
[Paste audience profile]

## Competitive Insights
- Existing content assumes: [knowledge they may not have]
- Gap I can fill: [specific thing audience needs]
- My unique angle: [one sentence]

## Key Facts
1. [Fact that matters to them] - [Source URL]

## From Experience (if codebase)
- [Relatable example/challenge]

## Questions MY AUDIENCE Would Ask
- [Based on knowledge gaps and constraints]
```

---

## Phase 2: Outline & First Approval Gate

### 2.1 Create Outline

```markdown
## Proposed Blog Post Outline

**Title:** [Under 46 chars]
**Slug:** [kebab-case]
**Target Length:** [word count]

### Target Audience
**Who:** [from Phase 0] | **Goal:** [what they want] | **Constraints:** [limitations]

### Why This Helps THEM
- [Gap it fills] | [Question it answers] | [Constraint it addresses]

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

### 2.2 APPROVAL GATE 1

**STOP. Present outline to user.** Include audience profile, structure, how it helps them.

AskUserQuestion options:
- **Approve outline** — proceed to writing
- **Adjust audience** — refine target
- **Revise structure** — change sections/flow
- **Change angle** — different value prop

**Do NOT proceed until user approves.**

### 2.3 Expert Outline Review

After user approves, 3 expert personas review. Pick based on topic:

| Subject Area | Good Picks |
|---|---|
| AI/LLM tooling | Simon Willison, Swyx, Andrej Karpathy |
| React/Frontend | Dan Abramov, Kent C. Dodds, Guillermo Rauch |
| DevOps/Infrastructure | Charity Majors, Kelsey Hightower, Julia Evans |
| Systems/Performance | Thorsten Ball, Julia Evans, Dan Luu |
| Business/SaaS | Patrick McKenzie (patio11), Sahil Lavingia, Swyx |
| Security | Troy Hunt, tptacek, Julia Evans |
| Developer experience | Swyx, Cassidy Williams, Guillermo Rauch |

Don't force-fit. Match expert to actual topic.

**Subagent prompt per expert:**
```
You are [Expert Name], known for [specialty] at [blog/site].
Review this blog OUTLINE for audience: [audience]. Be specific, direct.
Focus on: Would you click this title? Structure compelling or listicle-feeling?
Strongest/weakest section? Would it get shared on Twitter/HN? Missing anything?
[Insert outline]
```

**Synthesize:**
```markdown
## Expert Outline Review
### [Expert] — [Key feedback points]
### Where all 3 agree (high confidence): [consensus]
### Actionable changes: [specific changes]
```

Apply agreed changes. Present revised outline for final approval.

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
## Implementation (at THEIR level, code they can use, explain what THEY might not know)
## Trade-offs (relevant to THEM, honest)
## Results (at their scale, SOCIAL PROOF)
## Is This Right for You? (good fit / not good fit / middle-ground)
[Closing: personal note + question for engagement]
```

### 3.3 Frontmatter

```yaml
---
title: "[Under 46 chars]"
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

### 3.4 Audience Check Per Section

After each section: Would [audience] understand? Am I explaining known things? (cut) Assuming unknown things? (explain) At their scale? Helps them specifically?

---

## Phase 4: Draft Review & Second Gate

### 4.1 Self-Review Checklist

**Audience Fit (MOST IMPORTANT):**
- [ ] Written for specific audience, not generic
- [ ] At their experience level
- [ ] Addresses their constraints
- [ ] Uses their language

**SEO:** Title <46 chars, excerpt 120-160, kebab slug, one H1, proper heading hierarchy

**Content:** 5+ inline source links, comparison table, honest trade-offs, personal voice

**AI Pattern Check:** No banned words, no em dash excess, no "Additionally/Furthermore/Moreover", no "**Bold:** text" lists, no generic conclusions

### 4.2 APPROVAL GATE 2

**STOP. Present full draft.** AskUserQuestion options:
- Approve draft / Revise content / Adjust tone / Add-remove sections / Run humanizer

**Do NOT proceed until user approves.**

---

## Phase 4.5: Adversarial Fact Check (MANDATORY)

After draft approval, before polishing. Spawn 3 parallel subagents:

**Subagent 1 — Skeptic:** Mark each claim VERIFIED / UNVERIFIABLE / SUSPICIOUS. Focus: numbers, before/after comparisons, implied causation, "most people" claims.

**Subagent 2 — Devil's Advocate:** Flag EXAGGERATION / MISSING CONTEXT / CHERRY PICKING / FALSE PRECISION / OVERSELLING. Suggest honest alternative phrasing for each.

**Subagent 3 — Consistency Checker:** Numbers match between sections? Opening claims match content? Contradictions? Title/meta accurate? Promises delivered? Code matches prose?

### Synthesize

```markdown
## Adversarial Fact Check Results
### Must Fix (wrong/misleading) — [finding, flagged by whom]
### Should Fix (exaggeration/missing context) — [finding, suggested fix]
### Internal Inconsistencies — [section X vs section Y]
### Passed — [areas all 3 agreed accurate]
```

**Fix all "Must Fix" before proceeding.** Present "Should Fix" to user. Same issue flagged by multiple subagents = almost certainly real.

---

## Phase 4.7: Expert Draft Review

Same 3 experts from Phase 2.3 review complete draft.

**Subagent prompt per expert:**
```
You are [Expert Name]. Review this COMPLETE blog post for audience: [audience]. Be harsh.
Focus on: Opening earn attention in 3 sentences? Strongest/weakest section?
Would you share with your audience? Why/why not? Twitter/HN shareable?
Hand-waving instead of specifics? Honest content ring true or performed?
Technical depth right? Claims credible? Pacing issues?
[Insert full draft]
```

**Synthesize:**
```markdown
## Expert Draft Review
### [Expert] — Would share? [YES/NO] | Strongest: [x] | Weakest: [x] | Key feedback: [points]

### The "would they share it" test:
- 3/3 → proceed to polish
- 2/3 → fix weak points, proceed
- 1/3 or 0/3 → stop, discuss with user, may need structural rewrite
```

**Bar: at least 2/3 would share.**

---

## Phase 5: Polish, Lint & Humanize (MANDATORY)

### 5.1 Humanization (ALWAYS RUN — NOT OPTIONAL)

**Voice calibration:** Read 2-3 author's existing posts. Match sentence length, humor, directness, transitions.

**Process:**
1. Per-section pass with `/humanizer`
2. Full-post pass with `/humanizer` — at least **twice**
3. Read aloud test — sounds like press release or LinkedIn? Rewrite.

**Red flags:** "In today's...", "It's worth noting...", "This approach not only X but also Y", "Let's dive in", "Ultimately", "In conclusion", "Moreover", "Furthermore", "leverage", "streamline", "robust", "comprehensive", "journey" (metaphor), "game-changing", "revolutionize"

**Manual patterns (if not using /humanizer):**

Remove AI: bold list headers → flowing paragraphs, em dashes → commas/periods, parallel structures → vary, rule of three → use 2 or 4, "Additionally" → just start sentence.

Add human: opinions ("felt validating", "bad feeling"), uncertainty ("I'm not sure"), emotions ("frustrating", "tedious"), casual ("Here's the thing"), subtle humor.

**Soulless check:** Same-length sentences? All neutral? No humor? Robotic read aloud? Would human say this?

### 5.2 Lint Check

```bash
which vale && vale content/posts/[slug].md
# Or: npm run lint
```

Report errors for awareness.

### 5.3 Header Image (MANDATORY)

**CRITICAL: No sci-fi, no abstract AI art, no futuristic imagery.**

#### Prompt Rules

**REQUIRED:** Real humans/workspaces, natural settings, authentic environments, natural lighting, candid moments, MacBook Pro / iPhone 16 Pro Max if devices shown, "No text overlays" at end.

**BANNED:** Sci-fi/futuristic, abstract geometric, glowing/neon, robots/AI imagery, isometric, "digital"/"cyber", floating UI, stock cliches (handshakes, pointing at screens).

#### Generate via Gemini

1. Open `https://gemini.google.com/app` in new tab
2. Click "Create image" tool button
3. Enter prompt, click "Send message"
4. Wait 15-20 seconds

#### Download

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

#### Crop & Optimize

```bash
mkdir -p public/images/posts/[slug]/
cp ~/Downloads/tmp/[slug]-header.png public/images/posts/[slug]/header.png
sips --cropToHeightWidth [height-60] [width-60] public/images/posts/[slug]/header.png
npm run optimize-images
```

Verify watermark removed by reading image. Update frontmatter: `feature_image: /images/posts/[slug]/header.png`

**If Chrome tools unavailable:** Copy prompt to clipboard with `pbcopy`, ask user to generate manually, provide crop/optimize commands.

---

## Phase 6: Write File & Complete

### 6.1 Write File

Write to `content/posts/[slug].md` with full markdown + frontmatter.

### 6.2 Visual Testing (MANDATORY)

#### Ensure dev server running
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3021/ || npm run dev &
```

#### Open in Chrome
Navigate to `http://localhost:3021/[slug]`

#### Visual Checklist (scroll full page, screenshot each viewport)

**Layout:** Header image loads, title renders, all headings render as headings, no raw markdown visible.
**Code Blocks:** Syntax highlighting, no horizontal overflow, no broken fences.
**Images:** All load, SVGs render, reasonable sizing.
**Content:** Tables render as tables, links clickable, bold/italic correct, lists render properly.
**Spacing:** No huge gaps, no jammed sections, proper code block margins.

Fix issues → refresh → re-check.

**If Chrome tools unavailable:** Ask user to preview at `http://localhost:3021/[slug]`.

### 6.3 Final Summary

```markdown
## Blog Post Created

**File:** `content/posts/[slug].md`
**Title:** [title] ([X] chars) | **Meta:** [excerpt] ([X] chars)
**Word Count:** ~[X] | **Sources:** [X] inline links
**Target Audience:** [who] | **How It Helps:** [specific value]

### Next Steps
1. Generate header image using prompt above
2. Add to `/public/images/posts/[slug]/`
3. `npm run optimize-images`
4. Preview: `npm run dev` → `/[slug]`
5. Commit when ready
```

### 6.4 Optional Commit

If user wants: `git add content/posts/[slug].md && git commit -m "Add blog post: [title]"` or use `/commit`.

---

## Handling Feedback

| Feedback | Action |
|----------|--------|
| "Too specific" | Broaden audience |
| "Too generic" | Add codebase examples |
| "Sounds AI-written" | Run /humanizer |
| "Missing [topic]" | Research + add section |
| "Too long" | Consolidate |
| "Needs sources" | More web research |
| "Title too long" | Shorten to <46 chars |
| "Not my voice" | Ask for voice examples |

---

## Quick Reference

```
Workflow: Audience → Research → Outline → [GATE 1] → Expert Review → Draft → [GATE 2] →
         Fact Check → Expert Review → Humanize → Image → Write → Visual Test → Commit

REQUIRED: Target audience (ask if missing)
MANDATORY: Humanization (never skip)
Title: max 46 chars (60 with suffix)
Meta: 120-160 chars
Min sources: 5 inline links
Paragraphs: 5-6 lines max
End with: Question

APP: AGREE (pain) → PROMISE (benefit) → PREVIEW (roadmap)
Cialdini: Reciprocity, Authority, Social Proof, Liking, Scarcity, Consistency
Images: Human/realistic/natural — NO sci-fi/abstract/AI art
```

---

## Credits

**[Joe Karlsson](https://www.joekarlsson.com/2025/10/building-a-claude-code-blog-skill-what-i-learned-systematizing-content-creation/)**: Two approval gates, automated linting, encode standards.

**[Neil Patel](https://neilpatel.com/blog/how-to-write-blog-post/)**: APP Formula, short paragraphs, end with question, subheadings for skimmability.

**[Robert Cialdini](https://www.influenceatwork.com/)**: 6 Principles of Persuasion applied to content.
