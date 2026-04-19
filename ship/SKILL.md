---
description: Ship a task end-to-end -- issue, branch, implement, test, PR
---

# Ship

## Task

$ARGUMENTS

## Prerequisites

1. `git rev-parse --is-inside-work-tree` — fail → "Not inside a git repository."
2. `gh auth status` — fail → "GitHub CLI not authenticated. Run `gh auth login`."
3. `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'` — get base branch.
4. `git status --porcelain` — uncommitted changes → warn, ask stash or abort.

## Phase 1: Research and Plan (Iterative)

### Step 1: Research
Use `team-research` agent (Task tool, `subagent_type: "team-research"`): web researcher + code researcher + synthesizer → actionable research brief.

### Step 2: Plan and Validate (up to 3 iterations)

TeamCreate "ship-planning", run plan-validate cycle from research brief:

**Agent 1: Plan Builder** — Draft concrete plan: files to change (with line numbers), new files, tests, risks, edge cases, dependencies. Iterations 2+: incorporate validator feedback.

**Agent 2: Plan Validator** — Verify every file/function exists, no conflicts with recent commits, interfaces match actual code, identify gaps. Iterations 2+: verify previous issues resolved.

**Agent 3: Reviewer** — Decide accept or iterate.
- Satisfied (no gaps, grounded): final recommendation with ordered steps, `accepted = true`
- Not satisfied: feedback listing gaps/incorrect claims, `accepted = false` → next iteration. Can request follow-up research.
- Iteration 3 (final): accept regardless, list remaining uncertainties.

### After loop

Present final plan. TeamDelete. **STOP. Ask user to approve before proceeding.**

## Phase 2: Create GitHub Issue

1. `gh issue create --title "<title>" --body "<description + acceptance criteria>"`
2. Capture issue number.
3. `gh issue comment <NUMBER> --body "<approved plan>"` — post plan as comment.
4. Tell user issue number + link.

## Phase 3: Branch and Implement

1. `git checkout <default-branch> && git pull`
2. `git checkout -b feat/issue-<NUMBER>-<short-slug>` — kebab-case, 3-5 words max.
3. Implement per approved plan. Follow existing conventions. Minimal + focused. Add/update tests.

## Phase 4: Test and Verify

1. Run test suite (check `package.json`, `Makefile`, `pyproject.toml`).
2. Run linter if configured.
3. Failures → fix, re-run. Stuck after 2 attempts → ask user.

**STOP. Show `git diff --stat` + test results. Ask approval for commit and PR.**

## Phase 5: Commit, Push, PR

1. Stage relevant files by name. Never `git add -A` or `git add .`.
2. Commit:
   ```bash
   git commit -m "$(cat <<'EOF'
   <descriptive message> (#<NUMBER>)

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```
3. `git push -u origin feat/issue-<NUMBER>-<short-slug>`
4. Create PR:
   ```bash
   gh pr create --title "<PR title>" --body "$(cat <<'EOF'
   ## Summary
   <2-3 bullet points>

   ## Test Plan
   - <how tested>

   Closes #<NUMBER>
   EOF
   )"
   ```
5. `gh issue comment <NUMBER> --body "PR: <PR_URL>"`

## Phase 6: Report

```
--- Ship Complete ---
Issue:  #<NUMBER> - <title>
Branch: feat/issue-<NUMBER>-<short-slug>
PR:     <PR_URL>
Status: Ready for review
```

## Rules

- Never skip tests. No test runner found → tell user.
- Never force push. Push fails → diagnose, ask user.
- Never commit secrets (.env, credentials, keys).
- Keep issue open — PR's `Closes #N` handles it on merge.
- Unexpected failure → stop and explain, don't guess.
