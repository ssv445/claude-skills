# View recipes

Colours use the `explain-visually` tokens. On the overview, colour has only four meanings: blue = our module, violet = external, red = a failed factor, and (gap figures only) amber = to build. Everything else is ink on paper.

## overview — the one diagram

Five marks, nothing else.

| Mark | Drawn as |
|---|---|
| Module | Box: `.tb` name, `.ts` job (≤ 5 words). A store is the same box drawn as a cylinder. |
| Unit | Dashed rounded outline around the modules one owner controls / that change together. Unit name top-left in `.ts`. An outline may span bands. |
| Layer | Full-width band behind the boxes, top = entry points (UI, CLI, timers), bottom = stores and platform. Layer name in `.ts` at the left edge. |
| Connection | One solid arrow style, labelled with what moves (a noun: "job spec", "frame"). Points down or sideways. |
| Broken rule | The offending box, outline or arrow in red, with a badge naming the factor (`F3`). |

- **Readable at a glance:** at most 12 code boxes and 15 arrows. Above that, draw one box per unit (its job + module count) instead of its modules, and add one zoom figure per unit that has a fail, drawn with the same recipe.
- **Zoom on F1 fails:** a module that fails F1 (one box doing several jobs, e.g. one big file) gets a zoom figure of its internal parts (functions or sections, with `file:line`), drawn with this recipe and scored for F2–F5 inside it. Problems inside a big box, such as a cycle between two of its parts, must not disappear because the box is drawn whole.
- **Stores** sit as small cylinders inside the unit that writes them, in the bottom band. Its writer gets the only arrow. Readers are not drawn as arrows; they are listed under the cylinder in `.ts` ("read by health"). A reader from another unit is an F4 break: one red arrow per reader-unit → owning-unit pair, not one per file. A store written only by a person (a hand-edited config) gets its writer arrow from that caller. A folder several units write into is one cylinder, drawn red for F2, with the writers listed under it.
- **Bundle arrows:** one arrow per (from, to) pair; the label names up to two things that move, then "+n".
- **Callers** (people, timers, dashboards, other services that call in) sit in the top band, violet. **Externals we call out to** sit on the right, violet. F8 is scored on externals only. Many similar things (20 jobs, all scripts) are one box with a count.
- **Cycles:** one red double-headed curved arrow with a `cycle` badge, so it reads as a loop even when both boxes share a band.
- **Layout:** modules on a grid inside their band. Positions are fixed by the model so the same module sits in the same place in every figure on the page, including both halves of a gap figure. The svg may set `min-width` up to 1000px, and the page column may widen to 1180px for it.
- **No** sequence numbers, sync/async styles, legends for single-use marks, or hover cards. Those belong to `sequence` and `responsibilities`.
- **Under the figure, one line of counts:** code modules · stores · units · arrows between units · red marks · largest unit (code modules).
- **Done-check:** ≤ 12 code boxes and ≤ 15 arrows per figure; every module is in one band and one unit; every arrow has a label; every red mark has a factor badge and a fail or warn row in the scorecard, and every fail row has a red mark.

## scorecard — always under the overview

HTML table, one row per factor F1–F8, in order.

| Column | Content |
|---|---|
| # · Factor | `F3` · Dependencies point one way |
| Result | Pass / Warn / Fail / N/A pill (green / amber / red / grey). Warn = over the limit by one, or the result flips on a counting choice (say which). |
| Evidence | What was counted: "14 arrows checked, 1 upward: `health → run`" with `file:line` where code shows it |
| Gap | For a fail: what must change, one line ("move lock handling out of `run` into `lock.ts`") |

Header line above the table: `6 / 8 factors pass`.

- **N/A** only when the factor cannot apply (no stores → F2), with the reason in Evidence.
- **Done-check:** every Evidence cell names counted elements; no "looks fine".

## gap list — always, after the scorecard

The auditor's to-do list. Table: Module/unit · Today · Target · Change · Factor.

- **Without `vs <target>`:** the target is "passes all 8 factors". One row per fail from the scorecard, plus a row per doc-vs-code mismatch found while extracting the model (Factor column = `doc`).
- **With `vs <target>`:** draw the overview twice in one wide figure, "Target" left, "Today (from code)" right, same positions. On the Today half: module in both = plain; only in today = red (to remove); only in target = amber dashed outline (to build); in both but different layer, unit or job = amber fill. Then score the factors for both: the scorecard gets two Result columns, Target and Today. Every amber or red mark gets a gap-list row.
- Order rows by blast radius: what most other modules depend on goes first.
- **Done-check:** every red/amber mark and every failed factor has at least one row.

## responsibilities — drill-down

- HTML table, one row per module, in layer order.
- **Columns, fixed:** Module · Owns (facts or state it is the single source of truth for) · Receives (input ← from whom) · Sends (output → to whom) · Never does (tempting jobs it must stay out of).
- A fact with two owners → red callout under the table (`.callout{border-left:4px solid var(--red);background:var(--hl-red);padding:10px 14px;border-radius:8px}`) and an F2 fail in the scorecard.
- `raci` means this table, not an R/A/C/I letter grid, unless the user names the letter grid.
- **Done-check:** every module has a row; every fact has one owner; every Receives has a matching Sends.

## sequence — drill-down

- Name the scenario in the `h2` ("One tick fires one job").
- **Participants:** boxes across the top, ordered by first appearance, initiator first, max 7, ≥ 130 px apart, dashed lifelines down. Use the overview's module names.
- **Messages:** horizontal, top to bottom in time order, ≥ 44 px apart, numbered `1.` `2.`… with a short verb label.
  - Call = solid arrow. Return = dashed arrow labelled with what returns. Async (a spawn, an event, a write nobody waits on) = solid line, open arrowhead (`<path d="M0 0 L10 5 L0 10" class="k">` marker, no fill), "async" in `.ts`.
  - Self-call = small loop on the lifeline.
  - Labels crossing lifelines get a halo: `.halo{paint-order:stroke;stroke:var(--paper);stroke-width:5px}`.
- **Frames:** `loop` / `alt` / `opt` as a dashed box over the involved lifelines, guard in `[brackets]`, starting 30 px above its first message and ending 20 px below its last.
- One accent-blue message: the one the scenario is about.
- **Done-check:** numbers strictly increase down the page; every call that expects an answer has a dashed return; every participant has a message.

## ops — optional Twelve-Factor scorecard

Only when asked. Same table shape as the scorecard, rows = the twelve factors (codebase, dependencies, config, backing services, build/release/run, processes, port binding, concurrency, disposability, dev/prod parity, logs, admin processes). Kept as its own section so deployment findings don't mix with structure findings.
