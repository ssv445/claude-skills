---
name: draw-architecture
description: "Use when the user asks to draw, diagram, review or audit a system's architecture or structure — overview, modularity, cohesion, coupling, separation of concerns, ownership, boundaries, layers, responsibility matrix, sequence diagram, target vs as-built, gap analysis, architecture review, twelve-factor — or invokes /draw-architecture."
---

# Draw Architecture

One overview diagram that lets a reviewer judge a system's structure at a glance, scored against 8 fixed structure factors, with the gap shown. Recipes are in `views.md`.

**REQUIRED SUB-SKILL:** `explain-visually` — its notebook template, drawing rules, quickstart and publish steps apply to every figure here.

## Input

`/draw-architecture [view] <subject> [vs <target>]`

- **view:** `overview` (default), `responsibilities`, `sequence`, `ops`. Comma-separate to combine.
- **subject:** a repo, folder, file, pasted structure, or nothing (the system in this conversation).
- **vs <target>:** a target design (file or conversation). Adds the target-vs-today gap. Without it, the gap is today vs the 8 factors.

## The 8 structure factors

| # | Factor | Passes when |
|---|---|---|
| F1 | One job per module | Every module's job fits in 5 words with no "and" |
| F2 | One owner per fact | Every store has exactly one writer |
| F3 | Dependencies point one way | No upward arrow, no cycle |
| F4 | Hide internals | Arrows enter a unit through one box only |
| F5 | What changes together, lives together | Each unit has one reason to change |
| F6 | Few connections between units | Bundled arrows between units ≤ 2 × number of units |
| F7 | Small units | 9 code modules or fewer per unit (stores don't count) |
| F8 | Outside world behind one adapter | Each external system we call out to is touched by one module (callers coming in are not scored) |

Counting: a unit includes the stores it writes. Stores are never modules for F1, F7. F6 counts arrows between our own units only; callers and externals are not units.

## Steps

1. **Read `views.md`** and follow the recipe for each chosen view exactly.
2. **Extract one model** from the subject, from code, not from docs: modules (name, layer, unit, job), stores (writers, readers), externals, connections (from → to, what moves). Every view on the page uses these names. Docs that disagree with code → note it in the gap list.
3. **Score the factors** against the model. Each result names the elements it counted, so a pass is checkable and a fail points at something.
4. **Build the page** from the `explain-visually` template, in this order: overview figure, scorecard, gap list, then any extra views. Each SVG gets its own ids (`r1`/`a1`, `r2`/`a2`…).
5. **Run the done-checks** in `views.md`. Fix failures before publishing.
6. **Publish** per `explain-visually` (`icon: "diagram"`). Reply with the link, the pass count (e.g. 6/8), and the top 3 gaps.
