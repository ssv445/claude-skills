# Write Blog Skill (v5.0.0)

A Claude Code skill for writing complete, well-researched, human-sounding technical blog posts with **audience-first approach**, **persuasion frameworks**, **iterative humanization with multi-model AI-detection**, **curated internal + external links**, and **pre-gate agent review**.

## What's New in v5

- **Iterative humanization loop** — runs `/humanizer` repeatedly, scored by `codex` and `agy` (Gemini-pinned) CLIs each pass; loops until avg AI-likelihood < 25 (max 3 passes). Scores are lint signals — Loss Detector has veto if humanization would strip technical precision.
- **Per-repo `.write-blog.cfg`** — auto-detected on first run from `cfg-template.yaml`. Stores posts dir, frontmatter shape, URL pattern, sitemap path, link policy, humanize thresholds. One-time setup, reused forever.
- **Link curation with 3-way value grading** — Claude + Codex + Agy (Gemini-pinned) each score every external/internal link 0-10 in audience context. Hard caps: ≥1 and ≤10 external, ≥1 and ≤5 internal. T1 whitelist (MDN, RFC, etc.) auto-passes.
- **Internal links from repo/site** — discovers related posts via filesystem scan + sitemap fetch, picks the highest-rated for topical authority.
- **Pre-gate agent review** — every artifact bound for a user gate (research notes, outline, draft, rendered output) is first reviewed by a 3-subagent team that fixes consensus issues silently. User energy spent only on taste calls.
- **Loop-integrity filter** — inside every iterative loop (humanize, link grade, fact check), 3 subagents (Loss Detector, Gap Finder, Hallucination Hunter) catch drift on bad data per iteration.

## Core Principles

1. **Audience is REQUIRED** — Generic content helps no one
2. **Persuasion through structure** — APP formula + Cialdini's principles
3. **No raw AI output to user** — Pre-gate review on every artifact
4. **Iterative humanization** — Loop until avg AI-likelihood < 25 (multi-model detect, lint-mode)
5. **Curated links** — At least 1 internal + 1 external; all graded; hard caps respected
6. **Human imagery only** — No sci-fi, no abstract AI art

## Frameworks Used

### APP Formula (Introductions)
From Brian Dean / Neil Patel:
- **Agree** - Acknowledge reader's pain/situation
- **Promise** - Clear benefit from reading
- **Preview** - Brief roadmap of what's coming

### Cialdini's 6 Principles (woven throughout)
- **Reciprocity** - Give value first (free tips, templates)
- **Authority** - Share experience, cite experts
- **Social Proof** - "Others have seen..."
- **Liking** - Be relatable, share struggles
- **Scarcity** - Timely info, recent data
- **Consistency** - Build on reader's beliefs

## Usage

```
/write-blog <topic> --audience <who> [--codebase <path>]
```

### Examples

```bash
/write-blog "Docker dev containers" --audience "backend devs new to containers"
/write-blog "Migrating from WordPress" --audience "agency devs with client sites" --codebase ~/www/project
```

## Workflow (v5)

```
Audience → Research + Site Profile → Outline + Expert Review → [GATE 1]
        → Draft (bare ref list) → Fact Check + Expert Review → [GATE 2]
        → Link Curation (3-way grade, caps) → Iterative Humanize Loop (max 3, avg<25)
        → Lint → Image → Write → Visual Test → Commit
```

### Two User Gates (post-team-review)
1. **Outline Gate** — outline is reviewed by 3 expert personas first; user sees polished version.
2. **Draft Gate** — draft passes adversarial fact check + expert "would share" gate first; user sees polished version.

### Iterative Humanization
Runs in a scored loop: `/humanizer` → 3-perspective filter (loss/gap/hallucination) → `codex` + `agy` (Gemini-pinned) rate AI-likelihood → repeat until avg < 25 or max 3 iterations. Cap reached → surfaces full score trace to user.

### External CLI Reviewers
- `codex exec "<prompt>"` — independent OpenAI-model verifier
- `agy --model "Gemini 3.1 Pro (High)" -p "<prompt>"` — independent Google-model verifier (replaces deprecated `gemini -p`)
- Used for: AI-detection scoring, link value grading
- Failure modes: one fails → continue with the other; both fail → fallback paths defined per phase

## Structure Tips (Neil Patel)

- **Subheadings** - Make content skimmable
- **Short paragraphs** - 5-6 lines max
- **End with question** - Drives engagement
- **Link out** - Cite sources, build authority
- **Give first** - Value before any ask

## Image Prompts

**REQUIRED: Human, realistic imagery**

```
✅ Developer at desk in natural lighting
✅ Hands on keyboard, real environment
✅ Team discussing around whiteboard
```

**BANNED: Sci-fi and abstract**

```
❌ Futuristic/cyber aesthetics
❌ Abstract geometric shapes
❌ Glowing/neon effects
❌ Robots or AI imagery
❌ Isometric illustrations
```

## Quality Controls

### Mandatory Humanization
Every post runs `/humanizer` or equivalent pass.

### Banned AI Words
delve, crucial, enhance, foster, landscape, tapestry, underscore, pivotal, showcase, vibrant, revolutionary, game-changing, seamless, leverage, synergy

### Banned Patterns
- Bold headers in lists
- "It's not just X, it's Y"
- Excessive em dashes
- "Additionally/Furthermore/Moreover"
- Generic positive conclusions

## Credits

- **[Joe Karlsson](https://www.joekarlsson.com/2025/10/building-a-claude-code-blog-skill-what-i-learned-systematizing-content-creation/)** - Approval gates, encode standards
- **[Neil Patel](https://neilpatel.com/blog/how-to-write-blog-post/)** - APP formula, structure tips
- **[Robert Cialdini](https://www.influenceatwork.com/)** - 6 Principles of Persuasion
