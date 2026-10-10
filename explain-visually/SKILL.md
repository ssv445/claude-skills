---
name: explain-visually
description: "Use when the user asks to explain, walk through, or help them understand a spec, design, plan, architecture, codebase, flow or concept — or invokes /explain-visually. Produces a hand-drawn engineer's-notebook HTML artifact where each mechanism is an inline-SVG sketch. Triggers: explain this, explain me, walk me through, help me understand, visualize, draw it, how does X work, show me visually."
---

# Explain Visually

Shyam's preferred way to be explained anything non-trivial: a published HTML page in the style of an **engineer's notebook** — squared paper, wobbly ink strokes, handwriting labels, highlighter fills — where each section is one hand-drawn figure of a **mechanism**, plus a short caption. Prose is the caption, not the body.

**Input:** `/explain-visually <thing>`. No argument → the most recent spec, plan or design in this conversation.

## Steps

1. **Find the mechanisms.** Read the source (spec, code, conversation). List the 4–8 things a cold reader would otherwise assemble from prose: where data flows, which parts talk, what a request/page/item moves through, what changes between runs or options, where a boundary is crossed. Each becomes one figure. Done when every load-bearing decision in the source maps to a figure or a short card.
2. **Load the design rules.** Call `Artifact` with `action: "quickstart"`, `intent: "other"` (it carries the page contract), then invoke the `artifact-diagramming` skill.
3. **Build from the template.** `templates/notebook.html` is a complete worked example (the seo-desktop design explainer) containing one of each figure type below. Copy it to the session scratchpad. Keep its tokens, fonts, SVG vocabulary classes and figure pattern; replace all content and drop figure types you don't need. One `<section>` per mechanism: eyebrow + plain `h2`, one `<figure>` with inline `<svg>` + `<figcaption>`.
4. **Draw each figure** (see Drawing rules). Lists of facts that aren't mechanisms — budgets, tool names, scope — go in compact cards or tables after the figures.
5. **Publish** with `Artifact` (`icon: "diagram"`, one-sentence `description`). Reply with the link and one line per figure saying what it shows.

## Drawing rules

- **Mechanism, not names.** Draw the path, the boundary, the state change. A box labelled with a component name and nothing connecting it is not a figure.
- **Pick the shape that fits the claim:**
  | Claim | Figure |
  |---|---|
  | How the parts connect | System map: boxes in a container, labelled arrows, one accent path for the loop that matters |
  | What happens to one item | Flowchart left→right, early-exit boxes in green |
  | How something is classified | Mini wireframes side by side + callouts |
  | What changes over time / runs | Swim-lane bars across columns, event dots, end caps |
  | What gets recomputed | Small graph, changed node amber, neighbours light amber, rest grey |
  | Lifecycle | State pills with labelled transitions |
  | Trust / data boundary | Dashed boundary, crossings marked with a "!" badge |
- **Every arrow carries a verb** (`fetches`, `reads`, `only writer`). Meaning lives on the mark; a legend only for a repeated encoding.
- **Hand-drawn feel, legible text.** Shapes go inside `<g filter="url(#rN)">` (turbulence + displacement); `<text>` stays outside the filter. Each SVG gets its own ids (`r1`/`a1`, `r2`/`a2`, …).
- **Colour = meaning, from tokens only:** blue = store/agent, green = done/cheap/content, amber = changed/in-flight/warning, red = broken/rejected, violet = external, grey = untouched/template. Accent blue stroke for the one path the figure is about.
- **Text sizes:** `.tb` titles, `.t` labels, `.ts` small notes; short labels only, sentences go in the caption.
- **viewBox sized to content**, `min-width: 640px` on the svg so it scrolls inside the figure on phones; `role="img"` + `aria-label` stating the figure's claim.
- **Captions** say what to notice, in 1–3 plain sentences. Follow `google-writing-style` for all prose.

## Gotchas

- Marker arrowheads don't inherit `currentColor` from the line — fill them via a class (`.head`, `.head-acc`).
- Stroke-only highlighter bars: `<line class="k s-blue" stroke-width="16">`.
- Don't preview more than once; publish, then fix only what the user reports.
- Before claiming done, re-read the source once: any decision missing from the page is a gap.
