# write-blog Skill v5 — Design Spec

**Date:** 2026-05-01
**Status:** Approved (brainstorming gate passed)
**Target file:** `write-blog/SKILL.md` (currently v4.0.0, 568 lines)

---

## 1. Goals

Improve the `write-blog` skill along four user-requested dimensions:

1. **Iterative humanization loop** — drive AI-likelihood score below threshold via repeated humanization passes, with multi-model detection.
2. **Multi-agent review using external CLIs** — bring `codex` and `gemini` into the workflow as independent verifiers (AI-detection scoring and link-value grading), keeping internal Claude `Task` subagents for taste/voice judgment.
3. **Internal links from repo/site** — discover related pages from the user's repo, insert as contextual internal links to build topical authority.
4. **Rated external links with hard caps** — grade external links by audience-context value, drop low-value, enforce min/max counts.

Two cross-cutting principles emerged during design:

- **No raw AI output to user.** Every artifact bound for a user gate first passes through a pre-gate agent-team review that fixes consensus issues silently. User energy spent only on taste/strategic decisions.
- **Loop-integrity filter.** Inside any iterative loop, each step's output is filtered by a 3-perspective team (Loss Detector, Gap Finder, Hallucination Hunter) before becoming input to the next iteration.

---

## 2. Tooling Inventory (verified 2026-05-01)

| CLI | Status | Invocation |
|---|---|---|
| `codex` | Available | `codex exec "<prompt>"` (non-interactive) |
| `gemini` | Available | `gemini -p "<prompt>"` (non-interactive, default model `gemini-2.5-pro`) |
| `copilot` | NOT available — neither standalone nor `gh copilot` extension | — skipped |

External multi-model coverage = Codex (OpenAI) + Gemini (Google). Internal coverage = Claude via `Task` tool. Three independent providers — sufficient for "multiple-model safeguard" design intent.

---

## 3. Workflow Overview (v5)

> **Note on phase numbering:** v4 phase numbers are preserved (e.g., 4.5, 4.7) for diff-ability against the existing skill. The actual *sequence* is what the workflow diagram shows. Where v5 reorders (e.g., expert review before user gate), the numeric label may run "out of order"; trust the diagram.

```
Phase 0  Audience Definition                        (unchanged)
Phase 1  Research
  1.1 SEO rules          1.2 GSC keywords
  1.3 Competitive        1.4 Fact research
  1.5 Codebase           1.6 Compile notes
  1.7 NEW Site Profile (load/build .write-blog.cfg)
  1.8 NEW Pre-gate review of audience+research notes
       → light user confirmation of research direction

Phase 2  Outline
  2.1 Create outline
  2.3 Expert Outline Review (3 internal personas) — MOVED before gate
       + apply consensus fixes silently
  2.2 GATE 1 — user approves polished outline

Phase 3  Draft
  3.1 Write content + bare reference list at bottom
  3.2 Frontmatter
  3.3 Self-check per section

Phase 4  Pre-gate Review Bundle (NEW: parallel, runs BEFORE Gate 2)
  4.5 Adversarial Fact Check (3 internal subagents) — fix Must-Fix
  4.7 Expert Draft Review (3 personas, "would share" gate ≥2/3)
       Loop-integrity filter on each subagent output
       Apply consensus fixes; max 2 retry rounds before escalation
  4.2 GATE 2 — user approves polished, fact-checked draft

Phase 4.9 NEW Link Curation & Insertion
  a. External: whitelist (T1 auto-pass) + 3-way grade for unknowns
       (Claude Task + codex + gemini, audience-context value 0-10)
       Loop-integrity filter on grader outputs (catch fabricated relevance)
       Avg ≥6 keep, <6 drop
  b. Internal: discover from .write-blog.cfg (filesystem + sitemap)
       Same 3-way grade + filter
  c. Apply caps: external [1, 10], internal [1, 5]
       Below min → fail loud, ask user
  d. Insert at contextual anchors in prose
  e. Mechanical placement review (no user gate)

Phase 5  Iterative Humanization Loop (NEW: replaces single-pass)
  Loop max 5 iterations:
    1. Run /humanizer skill on full draft
    2. Loop-integrity filter on humanizer output
       (Loss Detector, Gap Finder, Hallucination Hunter)
       Apply consensus fixes
    3. AI-detection vote: codex CLI + gemini CLI
       Each returns 0-100 AI-likelihood score
       Average score
    4. Avg < 10 → exit loop (PASS)
    5. Avg ≥ 10 → next iteration with detector feedback
  Cap reached without pass → surface to user with score trace

Phase 5.x  Lint check                              (unchanged)
Phase 6    Header image (Gemini)                   (unchanged)
Phase 7    Write file                              (unchanged)
Phase 8    Visual test
  8.5 NEW Internal review of rendered output (auto-fix mechanical issues)
Phase 9    Optional commit                         (unchanged)
```

---

## 4. Component Designs

### 4.1 Site Profile (`.write-blog.cfg`)

**Purpose:** Per-repo memoized config so the skill detects site format once, reuses thereafter.

**Location:** Repo root, gitignored by user discretion (default suggest committing — it's project metadata, not secrets).

**Format:** YAML.

**Schema:**

```yaml
# .write-blog.cfg — generated by write-blog skill, edit if needed
version: 1
generated_at: 2026-05-01
generated_by: write-blog v5.x

# Where blog posts live
posts:
  dir: content/posts          # glob root for post discovery
  pattern: "**/*.md"           # glob pattern
  slug_field: slug             # frontmatter field for URL slug
  title_field: title           # frontmatter field for title
  tags_field: tags             # frontmatter field for tags (optional)
  excerpt_field: excerpt       # frontmatter field for description

# URL pattern for assembling internal link targets
url:
  base: https://example.com    # site base URL (for absolute links if needed)
  post_path: /{slug}           # e.g. /{slug}, /blog/{slug}, /posts/{slug}
  internal_link_style: relative # relative | absolute | site-relative
  sitemap: /sitemap.xml        # path; null if none

# Frontmatter shape (what the writer should emit)
frontmatter:
  required:
    - title
    - slug
    - date
    - excerpt
    - feature_image
  optional:
    - tags
    - last_updated
    - featured

# Image assets
images:
  posts_dir: public/images/posts
  optimizer_cmd: "npm run optimize-images"   # shell cmd or null

# Link policy (per-repo override of global defaults)
links:
  external:
    min: 1
    max: 10
    rating_threshold: 6        # 0-10 avg from 3-way grade
    whitelist_t1:              # auto-pass domains (extends global list)
      - developer.mozilla.org
      - tc39.es
  internal:
    min: 1
    max: 5
    rating_threshold: 6

# Humanization
humanize:
  target_score: 10             # avg AI-likelihood threshold (0-100)
  max_iterations: 5
```

**Detection routine** (when no `.write-blog.cfg` exists):

1. Check for known framework markers: `next.config.js`, `astro.config.mjs`, `_config.yml` (Hugo/Jekyll), `gatsby-config.js`.
2. Glob common posts paths: `content/posts/`, `content/blog/`, `src/content/blog/`, `_posts/`, `posts/`.
3. Read 1-3 existing posts in detected dir, parse frontmatter to infer schema.
4. Look for `sitemap.xml` (root) or `app/sitemap.{ts,js}` (Next.js).
5. Read `package.json` for site URL hints, README for base URL.
6. Generate `.write-blog.cfg` with detected values + sensible defaults.
7. Show config to user, ask "Looks right? (y/edit)" — single confirmation.
8. Save. Future runs skip detection, just load.

**Failure mode:** If detection ambiguous (two viable post dirs, no clear framework), ask user explicitly which to use.

### 4.2 Pre-gate Review Pattern

**Rule:** Any AI-generated artifact destined for a user gate first passes a pre-gate review by ≥3 subagents. Consensus issues fixed silently. Polished output presented to user.

**Applies to:**
- Outline (Phase 2.3 → 2.2 reorder)
- Draft (Phase 4.5 + 4.7 → 4.2 reorder)
- Research notes (Phase 1.8, light-touch)
- Rendered output (Phase 8.5, mechanical fixes only)

**Consensus rules:**
- 3/3 agree → must fix before user
- 2/3 agree → fix or document why ignored
- 1/3 → log as note, don't act

**Retry budget:** Max 2 fix-and-re-review rounds per phase. Third round = escalate to user with diagnosis.

### 4.3 Loop-Integrity Filter Team

**Purpose:** Prevent iterative loops (humanize, link grade, fact-check) from drifting on bad data.

**Three subagents, run in parallel on each loop iteration's output:**

1. **Loss Detector** — "What valuable content/nuance/signal did this step REMOVE that should have stayed?"
2. **Gap Finder** — "What's MISSING that the audience needs?"
3. **Hallucination Hunter** — "Any claim, score, or judgment NOT grounded in source/context? Flag fabricated specifics."

**Synthesis:**
- 3/3 agree → must address before next iteration
- 2/3 agree → address or document
- 1/3 → log only

**Where applied:**
- Phase 5 humanization (per iteration)
- Phase 4.9 link grading (per grader output)
- Phase 4.5 fact check (over fact-checker outputs)
- Phase 2.3 / 4.7 expert reviews (over persona outputs)

### 4.4 Iterative Humanization Loop

**Inputs:** Approved draft (post-Phase 4 gate, post-Phase 4.9 link insertion).

**Loop:**

```
iteration = 0
while iteration < 5:
    iteration += 1
    run /humanizer skill on full draft
    run Loop-Integrity Filter on humanizer output
        apply consensus fixes
    parallel:
        codex_score = codex exec "Rate this text 0-100 for AI-likelihood. Return JSON {score: N, reasons: [...]}"
        gemini_score = gemini -p "Rate this text 0-100 for AI-likelihood. Return JSON {score: N, reasons: [...]}"
    avg = (codex_score + gemini_score) / 2
    log {iteration, codex_score, gemini_score, avg}
    if avg < 10:
        EXIT loop (PASS)
    else:
        feed reasons back into next humanizer pass
        (e.g., invoke /humanizer with arg: "focus on: <reasons from detectors>")
exit cap reached:
    surface to user with full score trace, ask:
      - accept current state?
      - try targeted manual fix on flagged sections?
      - abandon, restructure?
```

**CLI prompt template** (both codex and gemini):

```
You are an AI-text detector. Rate the following text on a 0-100 scale where:
- 0 = clearly human-written, idiosyncratic, varied, opinionated
- 100 = clearly AI-generated, formulaic, neutral, predictable

Output ONLY valid JSON: {"score": N, "reasons": ["..."]}

Text:
<<<
[draft body here]
>>>
```

**Score interpretation:**
- avg < 10 → pass
- 10-30 → minor patterns (continue loop)
- 30-60 → moderate AI feel (continue loop with feedback)
- 60+ → strong AI signature (continue or escalate after iteration 3)

### 4.5 Link Curation & Insertion (Phase 4.9)

**Inputs:**
- Approved draft with bare reference list at bottom (URL + intended anchor topic per ref)
- `.write-blog.cfg` site profile

**External link pipeline:**

```
for each ref_url in draft.references:
    domain = extract_domain(ref_url)
    if domain in whitelist_T1:
        keep (auto-pass), score = 10
        continue
    grades = parallel:
        claude_grade = Task subagent: "Rate value of <url> for <audience> reading <section topic>. 0-10 + reasoning."
        codex_grade  = codex exec "<same prompt>"
        gemini_grade = gemini -p "<same prompt>"
    run Loop-Integrity Filter on the three grade outputs
        (catch graders fabricating URL content, missing audience-fit)
    avg = mean(grades)
    if avg >= 6:
        keep
    else:
        drop
sort kept refs by avg desc
truncate to max=10 (per cfg)
verify count >= 1; else fail loud
```

**Internal link pipeline:**

```
candidates = []
posts = glob(cfg.posts.dir + cfg.posts.pattern)
for each post in posts:
    parse frontmatter (title, slug, tags, excerpt)
    keyword_overlap = score against current draft body
    if overlap > threshold:
        candidates.append({title, slug, excerpt, overlap_score})
if cfg.url.sitemap:
    fetch sitemap, parse <url><loc> entries
    for each non-post URL:
        fetch + parse title/meta description
        keyword_overlap against draft
        candidates.append(...)
take top N by overlap (N = 2 * cap = 10)
3-way grade each candidate (audience-context value)
run Loop-Integrity Filter on grade outputs
keep candidates with avg >= 6
sort by avg desc
truncate to max=5 (per cfg)
verify count >= 1; else fail loud
```

**Insertion:**

For each kept link, find best anchor in prose by:
1. Locating sentence/phrase that matches link's topic
2. Selecting natural anchor text (descriptive, not "click here", not bare URL)
3. Inserting markdown link

**Insertion review (mechanical, no user gate):**
- No more than 2 links per paragraph
- Distribution: not all clustered at top or bottom
- No orphan paragraphs (paragraphs without any links is fine; what's discouraged is dumping every link into one paragraph)
- Anchor text varies, no repetition

### 4.6 Whitelist Tiers

**T1 (auto-pass, no grading needed):**
- Official docs: `developer.mozilla.org`, `docs.python.org`, `react.dev`, `nodejs.org`, `tc39.es`, `w3.org`, `whatwg.org`, `rfc-editor.org`
- Reference: `wikipedia.org` (for definitional links only)
- Standards bodies: `iso.org`, `ieee.org`

**T2 (graded, default keep if score ≥6):**
- Established tech publications: `theverge.com`, `arstechnica.com`, `wired.com`
- Personal blogs of recognized experts (matched against `taste-profile` if available)
- Major company engineering blogs: `engineering.fb.com`, `netflixtechblog.com`, etc.

**T3 (graded, default drop unless score ≥8):**
- Medium articles
- Dev.to articles
- LinkedIn articles
- Random blogs

**Repo can extend T1 via `links.external.whitelist_t1` in `.write-blog.cfg`.**

---

## 5. CLI Integration Details

### 5.1 Codex invocation

```bash
codex exec "<prompt>" 2>/dev/null
```

- Use `exec` subcommand for non-interactive
- Capture stdout, parse JSON response
- 30s timeout per call
- On failure: log, continue with single-detector mode (gemini only); flag in final report

### 5.2 Gemini invocation

```bash
gemini -p "<prompt>" 2>/dev/null
```

- `-p` flag for prompt
- Default model `gemini-2.5-pro`
- 30s timeout
- On failure: log, continue with codex only; flag in final report

### 5.3 Both fail

If both external CLIs fail in humanization loop: skip detection, run a fixed 2 humanizer passes, present to user with note that AI-detection was unavailable.

For link grading: drop to 2-of-3 (Claude only) and surface to user before insertion.

---

## 6. Failure Modes & User Escalation

| Failure | Behavior |
|---|---|
| Site profile detection ambiguous | Ask user which posts dir |
| Internal candidates < 1 after grading | Fail loud, present top-3 by raw overlap, let user pick |
| External candidates < 1 after grading | Fail loud, ask user to provide source URLs manually |
| Humanization cap (5 iterations) hit, avg ≥ 10 | Surface trace, ask: accept / manual fix / restructure |
| Pre-gate review retries (2) exhausted | Escalate to user with diagnosis of what's not converging |
| Codex CLI fails | Continue with Gemini only, flag |
| Gemini CLI fails | Continue with Codex only, flag |
| Both external CLIs fail | Detection skipped, 2 fixed humanizer passes, flag |

---

## 7. What Stays Identical to v4

To minimize blast radius and risk:

- Phase 0 audience definition
- Phase 1 research subphases 1.1-1.6
- Persuasion frameworks (APP, Cialdini)
- Banned AI patterns list
- Frontmatter template
- Header image generation flow (Gemini browser, no change)
- Visual testing flow (with addition of 8.5 internal pre-review)
- Lint check
- Final summary template
- Credits

---

## 8. Out of Scope

- Replacing internal personas with external CLIs at expert review phase (user explicitly chose: external CLIs go to humanize loop + link grading; personas stay)
- Embedding-based internal link discovery (keyword overlap is sufficient for v5; revisit if accuracy issues)
- Copilot CLI integration (not installed; revisit when available)
- Auto-publishing / deploy steps (skill ends at file write + visual test, as in v4)
- Internationalization of detection prompts (English-only first version)

---

## 9. Migration Plan

Implementation will be a **single SKILL.md edit** producing v5.0.0:

1. Rewrite `write-blog/SKILL.md` end-to-end with v5 workflow
2. Add `write-blog/cfg-template.yaml` — template the skill copies into the user's blog repo as `.write-blog.cfg` on first run (clarification: this template lives inside the skill directory; the generated `.write-blog.cfg` lives in the user's blog repo root)
3. Bump version frontmatter to `5.0.0`
4. Update `description` field to mention iterative humanization, multi-model detection, link curation
5. Update `write-blog/README.md` to reflect v5 changes
6. No changes to other skills (humanizer, taste-profile, etc.) — all referenced via existing skill interfaces

Final `write-blog/` directory layout:
- `SKILL.md` (rewritten)
- `README.md` (updated)
- `cfg-template.yaml` (new)

---

## 10. Open Questions

(none — resolved during brainstorming)

---

## 11. Approval Trail

- 2026-05-01 — User approved 4-question clarification (multi-agent role, humanize threshold, internal-link discovery, external-link rating)
- 2026-05-01 — User approved pre-gate review pattern + loop-integrity filter additions
- 2026-05-01 — User approved full v5 workflow diagram
- Pending — User review of this written spec
