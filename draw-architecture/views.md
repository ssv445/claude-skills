# View recipes

Each recipe states what the view is: its parts, layout and encoding, then the done-check. Colours use the `explain-visually` tokens: blue = our module/store, violet = external, green = done/cheap, amber = changed/warning, red = broken/removed, grey = untouched.

## layers — Layered architecture diagram

- **Claim:** what sits in each layer, and that calls only go down.
- **Layout:** full-width horizontal bands stacked top to bottom, one per layer. Top = closest to the user (UI / entry points), bottom = storage / platform. Layer name in `.tb` at the band's left edge, a `.ts` one-line purpose under it.
- **Inside a band:** one box per module, left to right, `.t` name + `.ts` job (max 5 words).
- **Arrows:** only between bands, pointing down, each with a verb. An arrow that goes up or skips a layer is drawn red with a "!" badge: it is a layering violation worth seeing.
- **Externals** sit outside the bands on the right, violet.
- **Done-check:** every module is in exactly one band; no unlabelled arrow; every upward arrow is red.

## components (c4) — Component diagram

- **Claim:** which modules exist inside one container, and how they connect.
- **Layout:** one dashed container (the app / service), named top-left. Components inside on a grid, entry point top-left, stores bottom. Actors and external systems outside the container: people left, systems right.
- **Box:** `.tb` name, `.ts` "[tech] · one-line job".
- **Arrows:** every one labelled with a verb + what moves ("sends frame", "reads posture"). One accent-blue path for the main loop.
- **Done-check:** no floating box (every box has an arrow); every arrow has a verb; one accent path at most.

## context / containers — C4 levels 1 and 2

- **context:** the system as one box in the centre, people left, external systems right, arrows labelled with what they exchange. Nothing inside the box.
- **containers:** the system boundary dashed; inside, one box per deployable/runnable unit (app, server, database, worker) with tech in `.ts`; arrows labelled with protocol + purpose ("HTTPS · fetch jobs").
- **Done-check:** context has no internals; containers has no code-level modules.

## dfd — Data flow diagram

- **Claim:** how data moves and where it rests.
- **Shapes, fixed:** processes = rounded boxes, numbered `1`, `2`…; data stores = open-ended rectangles (two horizontal lines, no sides) labelled `D1`, `D2`…; external entities = violet squares.
- **Layout:** left to right, sources on the left, sinks on the right.
- **Arrows** carry the data's name, a noun ("frame", "posture score"), not a verb. That is the difference from `components`.
- **Done-check:** every process has at least one input and one output; no arrow runs store-to-store or external-to-store without a process between.

## sequence — Sequence diagram

- **Claim:** the order of messages in one named scenario. Name it in the `h2` ("Frame to glow").
- **Participants:** boxes across the top, ordered by first appearance in the scenario, left to right. Initiator (person/timer) first. Max 7; group the rest.
- **Spacing:** participants evenly spaced, at least 130 px apart; dashed vertical lifelines down from each.
- **Messages:** horizontal arrows, top to bottom in time order, at least 44 px apart, each numbered `1.` `2.`… with a short verb label above the line.
  - Call = solid arrow. Return = dashed arrow, labelled with what returns. Async (fire and forget: a spawn, an event, or a file/DB write nobody waits on) = solid line with an open arrowhead (`<path d="M0 0 L10 5 L0 10" class="k">` marker, no fill) and "async" in `.ts`.
  - Self-call = small loop on the same lifeline.
  - Labels that cross lifelines get a paper-coloured halo: `.halo{paint-order:stroke;stroke:var(--paper);stroke-width:5px}`.
- **Frames:** `alt` / `loop` / `opt` as a labelled dashed box spanning the involved lifelines, guard in `[brackets]`. The frame starts 30 px above its first message (room for the tab label) and ends 20 px below its last.
- **Accent:** the one message the scenario is about in accent blue.
- **Done-check:** numbers strictly increase down the page; every call that expects an answer has a dashed return (async messages need none); no participant without a message.

## responsibilities (raci, crc) — Responsibility matrix

- **Form:** HTML table, not SVG. One row per module, in layer order.
- **Columns, fixed and in this order:** Module · Owns (the facts or state it is the single source of truth for) · Receives (input, from whom) · Sends (output, to whom) · Never does.
- **Cells:** short phrases, one per line. Name the other module in Receives/Sends ("posture ← detector"). "Never does" lists the tempting jobs it must stay out of ("never writes the DB").
- **Below the table:** if one fact has two owners, a red callout naming it (`.callout{border-left:4px solid var(--red);background:var(--hl-red);padding:10px 14px;border-radius:8px}`). One owner per fact is the point of the view.
- **If the user says `raci`:** use this table, not an R/A/C/I letter grid, unless they ask for the letter grid by name.
- **Done-check:** every module from the model has a row; every fact is owned by exactly one row; every Receives has a matching Sends somewhere.

## deps — Module dependency graph

- **Claim:** which module imports which, in code.
- **Layout:** top to bottom DAG. A module sits above everything it depends on; leaves (no dependencies) on the bottom row. Arrows point from the importer down to the imported module, unlabelled (direction is the meaning; say so in the caption).
- **Source:** real imports (grep / read), never guessed. Third-party packages are left out unless asked.
- **Cycles:** both edges red with a "cycle" badge; list them in the caption.
- **Fan-in:** a module imported by 4+ others gets a thicker outline.
- **Done-check:** every edge was seen in an import line; no upward arrow except red cycle edges.

## storage — Data ownership map

- **Figure:** stores as cylinders along the bottom (database, files, cache, remote). Modules above. Each store has exactly one accent-blue arrow labelled "only writer" from its owner. Readers connect with thin grey dashed arrows labelled "reads".
- **Table under it:** Store · What it holds · Writer · Readers · Lifetime (how long data lives / where it is backed up).
- **Done-check:** every store has exactly one writer; a second writer is drawn red and called out.

## adrs — Architecture Decision Records

- **Form:** one card per decision, numbered `ADR-001`…, newest last.
- **Card fields, in order:** Title (the decision as a statement) · Status (proposed / accepted / superseded by ADR-n) · Context (the force that made a choice necessary) · Decision · Options rejected (one line each, with why) · Consequences (what gets easier, what gets harder).
- **Source:** decisions found in the subject or conversation. Don't invent ones that weren't made.
- **Done-check:** every card has a rejected option and a consequence that costs something.

## architecture-board

One page: `layers` figure first, then the `responsibilities` table for the same modules, same names, same order.

## gap-board

- **Pick the view** (default `layers`) and draw it twice side by side on a wide figure: left "Target", right "As-built (today's code)". Same positions for the same module in both.
- **As-built encoding:** module in both = grey; only in today's code = red (to remove); only in target = amber dashed outline (to build); in both but moved layer or changed job = amber fill.
- **Gap list** under the figure: table of Module · Today · Target · Change.
- **As-built** must come from the code, not from the target plan.
- **Done-check:** every amber or red mark has a row in the gap list.
