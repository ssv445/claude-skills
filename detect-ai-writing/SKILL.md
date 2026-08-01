---
name: detect-ai-writing
description: "Use when reviewing or auditing text for AI-generation signals, running a pre-publish check, answering 'does this sound AI?', vetting guest posts / PR copy / user submissions, or producing a findings list to feed a humanizer/fixer pass. Triggers: detect ai writing, ai check, sounds like chatgpt, ai slop check, audit for ai tells."
---

# Detect AI Writing

Detector only. Flag suspicious spans, output a findings report a downstream fixer (e.g. `humanizer`) can act on mechanically. Never rewrite. Never score the whole document.

## Signal Catalog

Strength: **S** strong (can stand alone) · **M** moderate (needs density or a partner signal) · **W** weak (cluster only, never alone).

### Vocabulary

| id | cues | example | str |
|---|---|---|---|
| `fossil-phrase` | Exact strings: "notable works include", "today's fast-paced world", "aims to explore", "stands as a testament", "plays a crucial/pivotal role", "shed light on" | "aims to explore the interplay..." | S |
| `ai-vocab` | Density of: delve, tapestry, testament, pivotal, crucial, landscape (abstract), showcase, underscore, vibrant, intricate, fostering, leverage, robust, seamless, meticulous, boasts, enduring, interplay, enhance. 3+ per paragraph = flag | "rich tapestry ... pivotal role in the evolving landscape" | M |
| `copula-avoidance` | "serves/stands/functions as", "represents", "boasts", "features" where plain "is/has" fits | "serves as the exhibition space" | M |
| `elegant-variation` | Same referent renamed each mention | "protagonist... main character... central figure" | S |
| `quiet-modifier` | "quiet/quietly" on abstractions for false weight | "quietly building something big" | M |
| `hyphen-uniformity` | Perfectly consistent hyphenated compounds at density | "high-quality, data-driven, client-facing" | W |

### Punctuation & formatting

| id | cues | example | str |
|---|---|---|---|
| `em-dash-density` | Several per paragraph / 2+ per sentence — density, never one dash. A paired interruptive "—not Y—" parenthetical counts as the 2+/sentence case, especially wrapping a negation | "pages—brittle—held a map—finally" | M |
| `curly-quotes` | Typographic “quotes” in plain-text contexts (code, wikitext) — paste artifact | “on track” in a config file | M |
| `bold-overuse` | Mechanical bolding of every key term mid-prose | "**debt financing** ... **collateral**" | M |
| `bold-label-bullets` | Bullets shaped `**Label:** sentence restating label`, repeated | "- **Consistency:** Showing up daily builds trust." | S |
| `emoji-decoration` | Emoji prefixing headings/bullets | "🚀 **Launch Phase:**" | S |
| `markdown-leakage` | Raw `**`, `###`, `•` where markdown isn't rendered | "**bold** in an email body" | S |
| `structure-tics` | Skipped heading levels, gratuitous rules/tables, arrow chains, Title Case against house style, heading + one-liner restating it | "## Performance / Speed matters." | M |

### Sentence structure

| id | cues | example | str |
|---|---|---|---|
| `negative-parallelism` | "It's not X, it's Y", "not X but Y", stacked "X rather than Y", interruptive appositive "X—not Y—Z" | "Culture—not software—is the real determinant" | S |
| `staccato-stack` | 3+ punchy fragments, often anaphoric; "No X. No Y. Just Z." | "It's about action. It's about showing up." | S |
| `rule-of-three` | Triads recurring across the text — flag density, not one instance | "innovation, inspiration, and industry insights" | M |
| `false-range` | "From X to Y" where X, Y share no scale | "from the birth of stars to the dance of dark matter" | S |
| `ing-analysis` | Tacked-on participle clauses faking depth: highlighting, underscoring, reflecting, ensuring, fostering, showcasing | ", reflecting the community's deep connection to the land" | S |
| `symmetric-correlative` | "not only... but also", "whether you're X or Y", matched clause lengths — at density | "not only saves time but also improves quality" | M |
| `passive-fragment` | Actor-hiding subjectless fragments in feature prose | "No configuration needed." | W |

### Discourse & framing

| id | cues | example | str |
|---|---|---|---|
| `significance-inflation` | Legacy puffery: "testament to", "pivotal moment", "enduring legacy", "underscores its importance" | "marking a pivotal moment in the evolution of..." | S |
| `promo-tone` | Brochure diction in neutral text: nestled, breathtaking, vibrant, renowned, "in the heart of" | "Nestled within the breathtaking region..." | S |
| `grand-opener` | "In today's fast-paced/digital world", "In an ever-evolving landscape", "In a world where..." | "In today's fast-paced digital landscape..." | S |
| `setup-hype` | Payoff announcements: "Here's the kicker", "But here's the thing", "The result?" | "But here's the kicker:" | S |
| `signposting` | "Let's dive in", "it's worth noting", "it is important to note", "here's what you need to know" | "Let's dive into how caching works." | S |
| `vague-attribution` | Unnamed authorities ("Experts believe", "Studies show") with no citation; prestige-outlet name-lists with no specifics | "Studies show 87% of professionals..." | M |
| `challenges-pivot` | "Despite these challenges..." optimism; "Future Outlook" sections | "Despite these challenges, the town continues to thrive" | S |
| `generic-conclusion` | "In conclusion" + upbeat restatement; "the future looks bright" | "Exciting times lie ahead..." | M |
| `authority-trope` | Faux-depth pivots: "At its core", "The real question is", "what really matters" | "At its core, what really matters is readiness." | M |
| `faux-balance` | Counterargument acknowledged then ignored | "Of course, critics argue X. That said, the benefits are clear." | M |
| `hollow-device` | Generic "Imagine..."/"Picture this:" with no specific detail; metaphors that don't map | "Picture this: inbox overflowing, coffee gone cold." | W |

### Tone

| id | cues | example | str |
|---|---|---|---|
| `sycophancy` | "Great question!", "You're absolutely right", inflated affect on mundane topics | "This is such a fantastic question!" | S |
| `hedge-stack` | 2-3 chained qualifiers in one sentence | "might potentially help in many cases" | S |
| `performed-empathy` | Unsolicited validation ("You're not alone", "And that's okay") or fake candor ("Honestly?", "Real talk") + banal claim | "Struggling? You're not alone." | M |
| `register-mismatch` | "Furthermore/Moreover" opening consecutive casual-venue sentences | "Furthermore, it is imperative to acknowledge..." | M |
| `filler-phrase` | "in order to", "due to the fact that", "has the ability to" | "due to the fact that the data shows" | W |

### Meta / leakage artifacts (near-proof)

| id | cues | example | str |
|---|---|---|---|
| `chat-residue` | "I hope this helps", "Would you like...", "Certainly! Here's a...", "As an AI language model" | "Certainly! Here's a compelling LinkedIn post:" | S |
| `cutoff-disclaimer` | "as of my last training update", "while details are limited in available sources" | "up to my last training update" | S |
| `citation-token` | Leaked markup: `oaicite`, `contentReference`, `turn0search0`, `[cite: 1]`, `【】`, `grok_card` | ":contentReference[oaicite:0]{index=0}" | S |
| `utm-chatbot` | URLs with `utm_source=chatgpt.com`/`openai` | "?utm_source=chatgpt.com" | S |
| `placeholder` | Unfilled template slots | "[Insert name here]" | S |
| `fake-citation` | Dead links, DOIs resolving elsewhere, book cites without pages | DOI → unrelated paper | S |
| `abrupt-cutoff` | Text ending mid-sentence or mid-list | "The three reasons are: 1." | S |

## Detection Procedure

**Pass 1 — span scan.** Read paragraph by paragraph, matching each sentence against the catalog. Record candidates with exact verbatim spans and paragraph numbers.

**Pass 2 — discourse scan.** Re-read for signals only visible across sentences:
- Density tallies: `rule-of-three`, `em-dash-density`, `ai-vocab` per paragraph
- `uniform-rhythm` (W): sentences marching in formation — near-identical length and cadence, no fragments, no rambles
- `emotional-flatline` (W): pleasant-neutral tone regardless of subject; no opinion, no first person, no stray concrete detail
- `style-shift` (M): abrupt mid-document register/formatting change — the paste seam
- Section-ending summary habit; intro-body-conclusion symmetry the piece didn't need

**Pass 3 — calibrate.** Apply the rules below, drop findings that fail, emit the report.

## Calibration — false-positive control

- **W signals never make a finding alone.** Require 2+ weak signals in one sentence, or one weak signal in a paragraph that already has an S/M finding.
- **M signals need density or a partner.** One em dash, one triad, one "crucial" is normal writing.
- **Human counter-signals raise the bar.** First-person anecdotes, concrete specifics (names, dates, numbers), typos, strong opinions, humor, digressions near a candidate span → demand S-strength evidence or drop it.
- **A lone sentence-structure S signal** (negative-parallelism, staccato-stack) in a passage dense with human counter-signals is capped at medium confidence — and dropped if its payoff is concrete (names, numbers, specifics).
- **Domain vocabulary is not AI vocabulary.** "Robust" in statistics, "leverage" in finance are terms of art.
- **Absence proves nothing.** Delve-era words got trained out; clean vocabulary ≠ human.

**Do not flag:** a single em dash or single "not only...but also"; field jargon; correct grammar per se; bullets/headings where that's the genre; one hyphenated compound; quoted material the author cites; Title Case where it IS the house style.

## Output Format (mandatory)

Findings ordered by position in the text:

```
## Findings

1. ¶2 — "marking a pivotal moment in the evolution of regional statistics"
   signals: significance-inflation, ai-vocab
   why: legacy puffery attached to an arbitrary founding date
   confidence: high
   fix-direction: state the fact plainly; delete the significance claim

## Verdict
Findings: 7 in ~450 words → 1.6 per 100 words. Call: mixed.
```

Rules:
- **Span = exact verbatim substring** of the source — the fixer locates it by string match. Never paraphrase or trim mid-word.
- Location = ¶N. ¶1 = first body paragraph; headings/titles are not paragraphs. Findings in the same ¶ are ordered by span position. Signals = catalog ids. Why = one line. Confidence = high | medium (weaker candidates get dropped, not reported).
- Fix-direction = one line naming the kind of edit ("cut the participle clause", "name the source or delete") — **never a rewrite**.
- Discourse-level findings quote one representative span, note "recurs" in the why.
- **Quote only suspicious spans. Never reproduce clean text.**
- Verdict = density + call: heavily-AI-flavored (>2.5/100) / mixed (0.8–2.5) / mostly-clean (<0.8). **Not** a percentage "AI score" — humans and detectors hover near chance on that; only density, clustering, and hard artifacts are reliable.

## Common Mistakes

- **Flagging every em dash** — density signal; good writers use them.
- **Emitting an "X% AI" score** — out of scope; density + qualitative call only.
- **Paraphrasing spans** — the fixer needs an exact substring for lookup.
- **Rewriting while reporting** — fix-direction names the edit type; the fixer edits.
- **Flagging technical terms as `ai-vocab`** — check field register first.
- **Reproducing clean paragraphs "for context"** — suspicious spans only.
- **Treating polish as guilt** — convict on patterns and artifacts, not fluency.
