---
name: draw-architecture
description: "Use when the user asks to draw, diagram or document a system's architecture by a named view — layered diagram, component diagram, C4, data flow diagram (DFD), sequence diagram, responsibility matrix, RACI, CRC cards, module dependency graph, data ownership map, storage view, ADRs, architecture board, gap analysis, as-built vs target, architecture description — or invokes /draw-architecture."
---

# Draw Architecture

Draws named architecture views so each one comes out in the same, predictable shape every time. Each view has a fixed recipe in `views.md`. The style, template and publishing come from the `explain-visually` skill.

**REQUIRED SUB-SKILL:** `explain-visually` — its notebook template, drawing rules, quickstart and publish steps apply to every figure here.

## Input

`/draw-architecture <view | board | all> <subject>`

- **view:** one or more names from the table below, comma-separated.
- **board:** `architecture-board` or `gap-board` (composites).
- **all:** the full architecture description, every view that has content.
- **subject:** a file path, a repo or folder, a pasted structure, or nothing (the system discussed in this conversation).

## Views

| Say | You get | Form |
|---|---|---|
| `layers` | Layered architecture diagram | SVG |
| `components` (alias `c4`) | Component diagram, C4 Component level | SVG |
| `dfd` | Data flow diagram | SVG |
| `sequence` | Sequence diagram for one scenario | SVG |
| `responsibilities` (alias `raci`, `crc`) | Responsibility matrix: owns / receives / sends / never does | Table |
| `deps` | Module dependency graph | SVG |
| `storage` | Data ownership map | SVG + table |
| `adrs` | Architecture Decision Records | Cards |
| `context`, `containers` | C4 Context / Container levels | SVG |
| `architecture-board` | `layers` + `responsibilities` on one page | Composite |
| `gap-board` | Target vs as-built for the same view, with a gap list | Composite |

## Steps

1. **Read `views.md`.** Each chosen view has a recipe: what it must show, its fixed layout, its encoding, and a done-check. Follow the recipe exactly; it is what makes the output "as expected".
2. **Extract the model once.** From the subject, list modules (name, layer, one-line job), stores, external actors, and the messages between them. Every view on the page draws from this one list, so names match across views. Facts you could not verify go in a "Not verified" note at the end, never drawn as fact.
3. **Build the page** from the `explain-visually` template. One `<section>` per view, in the order of the Views table. For `all`, a view with no content for this subject is left out and named in the footer; views the user didn't ask for aren't mentioned. Vocabulary the template lacks (open arrowheads, label halos, callouts) is defined in `views.md`; add it to the page's CSS/defs.
4. **Run each view's done-check** before publishing. Fix failures; don't ship them.
5. **Publish** per `explain-visually` (`icon: "diagram"`). Reply with the link and one line per view.

## Ids on multi-figure pages

Every SVG gets its own filter and marker ids: `r1`/`a1` in the first figure, `r2`/`a2` in the second, and so on. Shared ids make later figures pick up the first figure's arrowheads.
