---
name: eval-criteria
description: |
  Generate task-specific evaluation criteria from an implementation plan.
  Use after writing a plan (via writing-plans skill) or manually on any plan file.
  Produces a scored eval file that the eval-verifier agent uses post-implementation.
---

# Eval Criteria Generator

## Step 1: Resolve Input

Plan path from argument, else most recent `.md` in `docs/superpowers/plans/`. Read fully.

Also read:
- Project `CLAUDE.md` (conventions)
- `~/.claude/taste/`: `architecture.md`, `product.md`, `ux.md`, `code.md`, `process.md`, `communication.md`
  - HIGH confidence → apply automatically; MEDIUM → advisory

## Step 2: Parse Plan

Extract: **goal** (header), **task count/names** (### Task N:), **file paths** (Create/Modify/Test), **tech stack**, **requirements** (task title + steps).
- **UI work?** — scan for: React, CSS, HTML, component, page, layout, form, modal, dialog, .tsx, .jsx, .css, .scss
- **Personas affected** — end user, admin, developer/API consumer, system/infra

## Step 3: Complexity

Count unique non-test files (Create + Modify):
- **1-2** → Light (5-8 criteria) | **3-8** → Standard (10-18) | **9+** → Heavy (20-30)

## Step 4: Select Dimensions

| Pattern | Criteria | Owner |
|---------|----------|-------|
| auth, permission, login, session, token, password | Security | security |
| database, migration, query, SQL, prisma, drizzle | Performance + Architecture | performance, architecture |
| api, endpoint, route, controller, handler | Error handling + Security | error-handling, security |
| component, page, layout, form, modal, .tsx, .jsx, .css | UX/Craft | ux-reviewer, visual-reviewer, content-reviewer |
| test, spec, .test., .spec. | Testing | testing |
| config, env, infra, deploy, docker, ci | Architecture | architecture |

No match → architecture + error-handling defaults.

## Step 5: Generate Criteria

### 5a. Functional (pass/fail)
One per plan task outcome. **What:** expected behavior. **verify:** intent, not exact commands ("check that...", "confirm...", "test by...").

### 5b. Code Quality (scored 1-5)
Per auto-select mapping. Category + **owner** + **verify** — specific to THIS plan, not generic.
Apply taste from `~/.claude/taste/code.md` + `architecture.md`: HIGH confidence principles relevant to plan → add or weave into category.

### 5c. UX/Craft (scored 1-5)
Only if UI work detected. Category + owner + verify.
Apply taste from `~/.claude/taste/ux.md`: HIGH confidence → specific criteria.

### 5d. Completeness (pass/fail)
Per affected persona only. Standard checks: End User (full flow), Admin (manage via UI not DB), API (full CRUD), System (reversible migration).

**Taste flag:** New entity/feature without admin UI task → FLAG as intentional omission. ("A feature without management UI is not a feature" — taste/product.md)

### 5e. Taste (scored 1-5)
HIGH confidence taste principles directly relevant to plan. Each has owner, verify, taste source reference. Only include with relevant principles.

## Step 6: Write Output

```bash
mkdir -p docs/superpowers/evals/
```

Write to `docs/superpowers/evals/YYYY-MM-DD-{feature}-eval.md`:

```markdown
# Evaluation Criteria: {feature_name}

---
plan_path: {relative path}
plan_modified: {ISO timestamp}
complexity: {light|standard|heavy} ({N} criteria)
generated: {date}
taste_sources: {files read}
---

## Functional (pass/fail)
- [ ] {requirement}
  - verify: {intent}

## Code Quality (scored 1-5)
- **{category}** — {plan-specific description}
  - owner: {dimension}
  - verify: {intent}

## UX/Craft (scored 1-5)
<!-- only if UI work detected -->
- **{category}** — {description}
  - owner: {dimension}
  - verify: {intent}

## Completeness (pass/fail)
- [ ] {persona}: {capability}
  - verify: {intent}

## Taste (scored 1-5)
- **{principle}** — {plan-specific}
  - owner: {dimension}
  - verify: {intent}
  - taste: {source}#{principle}
```

Update plan file: add `**Eval:** {eval_file_path}` after `**Tech Stack:**` or `**Spec:**` line (else before first `---`).

```bash
git add docs/superpowers/evals/{eval-file} {plan-file}
git commit -m "chore: generate eval criteria for {feature}"
```

Print summary:
```
Eval criteria generated:
- Complexity: {tier} ({N} total)
- Functional: {N} | Code Quality: {N} | UX/Craft: {N} (or "skipped")
- Completeness: {N} persona checks ({flagged} flagged)
- Taste: {N} principles | Sources: {files}
- Eval file: {path}
```
