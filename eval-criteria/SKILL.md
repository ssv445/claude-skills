---
name: eval-criteria
description: |
  Generate task-specific evaluation criteria from an implementation plan.
  Use after writing a plan (via writing-plans skill) or manually on any plan file.
  Produces a scored eval file that the eval-verifier agent uses post-implementation.
---

# Eval Criteria Generator

**Announce:** "I'm using the eval-criteria skill to generate evaluation criteria from the plan."

Generate task-specific, taste-informed evaluation criteria from an implementation plan. Criteria cover functional requirements (pass/fail), code quality (scored), UX/craft (scored), and completeness across personas.

## Step 1: Resolve Input

If a plan path is provided as argument, use it.
Otherwise, find the most recent `.md` file in `docs/superpowers/plans/`.
Read the plan file fully before proceeding.

Also read:
- The project's `CLAUDE.md` if it exists (for project-specific conventions)
- Taste files at `~/.claude/taste/` (for taste-informed criteria):
  - `architecture.md`, `product.md`, `ux.md`, `code.md`, `process.md`, `communication.md`
  - Each contains principles with confidence levels — only apply HIGH confidence principles automatically; MEDIUM confidence principles are advisory

## Step 2: Parse Plan

Extract from the plan:
- **Goal** (from header)
- **Task count and names** (### Task N: headings)
- **All file paths** (Create/Modify/Test lines under each task)
- **Tech stack** (from header)
- **Requirements** (what each task achieves — the task title + step descriptions)
- **UI work present?** (scan for: React, CSS, HTML, component, page, layout, form, modal, dialog, .tsx, .jsx, .css, .scss in file paths or task descriptions)
- **Personas affected** (who touches this feature: end user, admin, developer/API consumer, system/infra)

## Step 3: Estimate Complexity

Count unique files across all tasks (Create + Modify, excluding Test files):
- **1-2 files** → Light (5-8 criteria)
- **3-8 files** → Standard (10-18 criteria)
- **9+ files** → Heavy (20-30 criteria)

## Step 4: Select Dimensions

Scan file paths and task descriptions for these patterns to auto-select relevant code quality categories:

| Pattern in files/descriptions | Criteria added | Owner dimension |
|-------------------------------|---------------|-----------------|
| auth, permission, login, session, token, password | Security | security |
| database, migration, query, SQL, prisma, drizzle | Performance + Architecture | performance, architecture |
| api, endpoint, route, controller, handler | Error handling + Security | error-handling, security |
| component, page, layout, form, modal, .tsx, .jsx, .css | UX/Craft | ux-reviewer, visual-reviewer, content-reviewer |
| test, spec, .test., .spec. | Testing | testing |
| config, env, infra, deploy, docker, ci | Architecture | architecture |

No match = architecture + error-handling as defaults.

## Step 5: Generate Criteria

### 5a. Functional Criteria (pass/fail)

One criterion per plan task outcome / requirement. Each includes:
- **What:** clear statement of the expected behavior
- **verify:** verification intent — what to check, NOT exact commands (the eval-verifier resolves these at runtime). Use phrases like "check that...", "confirm...", "test by..."

### 5b. Code Quality Criteria (scored 1-5)

Selected by the auto-select mapping above. Each includes:
- **Category name** and specific description for THIS plan (not generic)
- **owner:** which review dimension evaluates this
- **verify:** what to check

**Apply taste principles:** Read `~/.claude/taste/code.md` and `~/.claude/taste/architecture.md`. For each HIGH confidence principle relevant to this plan, add it as a specific criterion or weave it into an existing category.

Examples of taste-informed criteria:
- If plan touches TypeScript: "No `any` or `as` assertions — use `unknown` + type guards" (from taste/code.md)
- If plan adds new entity: "Settings stored on entity, not generic table" (from taste/architecture.md)
- If plan adds state machine: "Minimal states — no pause/draft unless explicitly required" (from taste/architecture.md)

### 5c. UX/Craft Criteria (scored 1-5)

Only generated if UI work is detected. Each includes category, owner, verify.

**Apply taste principles:** Read `~/.claude/taste/ux.md`. For HIGH confidence principles relevant to this plan, add specific criteria:
- "Browser testing performed at 375px, 768px, 1280px" (from taste: browser testing non-negotiable)
- "User-facing outputs show summary, not raw detail" (from taste: keep outputs simple)

### 5d. Completeness Criteria (pass/fail)

For each affected persona, generate a completeness check:

```
## Completeness (pass/fail)

- [ ] End User: can complete the full flow without help
  - verify: walk through the user journey start to finish
- [ ] Admin: can manage this feature via UI (not database)
  - verify: check CRUD operations available in admin panel
- [ ] API: endpoints are complete (not just Read — Create/Update/Delete if applicable)
  - verify: check all CRUD endpoints exist and return proper responses
- [ ] System: migration is reversible, existing data handled
  - verify: run migration up and down, check existing records
```

Only include personas actually affected by the plan. Skip personas the plan doesn't touch.

**Apply taste:** "A feature without management UI is not a feature" (taste/product.md, HIGH confidence). If the plan creates a new entity/feature but has no admin UI task, FLAG it:
```
- [ ] FLAGGED: {entity} has no admin management UI in this plan — intentional?
  - verify: confirm admin can create/edit/delete {entity} via UI, not just database
```

### 5e. Taste Criteria (scored 1-5)

Apply relevant HIGH confidence taste principles as an additional scored section. Select only principles that directly relate to what the plan builds:

```
## Taste (scored 1-5)

- **Simplicity** — no over-engineering, minimal states, simple infrastructure
  - owner: architecture
  - verify: check for unnecessary abstractions, premature optimization, unused flexibility
  - taste: architecture.md#simplicity-over-infrastructure, architecture.md#fewer-states
- **User language** — UI copy uses domain terms, not technical jargon
  - owner: ux-reviewer
  - verify: check labels, error messages, empty states for plain language
  - taste: product.md#use-domain-language, communication.md#always-ask-whats-simpler
```

Only include taste criteria with relevant principles. Don't add generic taste checks.

## Step 6: Write Output

### 6a. Create evals directory
```bash
mkdir -p docs/superpowers/evals/
```

### 6b. Write eval file

Write to `docs/superpowers/evals/YYYY-MM-DD-{feature}-eval.md`:

```markdown
# Evaluation Criteria: {feature_name}

---
plan_path: {relative path to plan file}
plan_modified: {ISO timestamp of plan file's last modification}
complexity: {light|standard|heavy} ({N} criteria)
generated: {today's date}
taste_sources: {list of taste files read}
---

## Functional (pass/fail)

- [ ] {requirement 1}
  - verify: {intent}
- [ ] {requirement 2}
  - verify: {intent}

## Code Quality (scored 1-5)

- **{category}** — {specific description for this plan}
  - owner: {dimension}
  - verify: {intent}

## UX/Craft (scored 1-5)
<!-- only present if UI work detected -->

- **{category}** — {specific description}
  - owner: {dimension}
  - verify: {intent}

## Completeness (pass/fail)

- [ ] {persona}: {can do what}
  - verify: {intent}

## Taste (scored 1-5)

- **{principle}** — {specific to this plan}
  - owner: {dimension}
  - verify: {intent}
  - taste: {source file}#{principle name}
```

### 6c. Update plan file

Add `**Eval:** {eval_file_path}` to the plan header.
Insertion logic: find the line starting with `**Tech Stack:**` or `**Spec:**`, insert after it. If neither found, insert before the first `---` separator.

### 6d. Commit

```bash
git add docs/superpowers/evals/{eval-file}
git add {plan-file}
git commit -m "chore: generate eval criteria for {feature}"
```

### 6e. Print summary

```
Eval criteria generated:
- Complexity: {tier} ({N} total criteria)
- Functional: {N} pass/fail checks
- Code Quality: {N} scored categories
- UX/Craft: {N} scored categories (or "skipped — no UI work")
- Completeness: {N} persona checks ({flagged} flagged)
- Taste: {N} principles applied
- Taste sources: {files read}
- Eval file: {path}

The implementation agent will see these criteria before starting work (sprint contract).
The eval-verifier agent will verify against these after implementation.
```
