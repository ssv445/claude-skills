---
description: Ship a task end-to-end -- issue, branch, implement, test, PR
---

# Ship: GitHub-Driven Development Workflow

You are given a task to ship. This command handles the full lifecycle: issue creation, planning, implementation, testing, and PR.

## Task

$ARGUMENTS

## Prerequisites

Before anything, verify the environment:

1. **Check git repo**: Run `git rev-parse --is-inside-work-tree`. If this fails, stop and tell the user: "Not inside a git repository."
2. **Check gh CLI**: Run `gh auth status`. If this fails, stop and tell the user: "GitHub CLI is not authenticated. Run `gh auth login` first."
3. **Identify default branch**: Run `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'` to get the base branch (main/master).
4. **Check clean working tree**: Run `git status --porcelain`. If there are uncommitted changes, warn the user and ask whether to stash them or abort.

## Phase 1: Research and Plan (Iterative Agent Team)

### Step 1: Research via team-research agent
Use the `team-research` agent (Task tool with `subagent_type: "team-research"`) to run parallel research:
- Web researcher finds docs, APIs, patterns, pitfalls
- Code researcher explores codebase, git history, existing patterns
- Synthesizer merges findings into an actionable research brief

### Step 2: Plan and Validate (up to 3 iterations)

Use TeamCreate to spawn a team called "ship-planning". Run up to 3 iterations of the plan-validate cycle, starting from the research brief.

#### Agent 1: Plan Builder (subagent_type: general-purpose)
Draft a concrete implementation plan from the research brief:
- What files need to change (with line numbers where possible)
- What new files are needed (if any)
- What tests to add or modify
- Risks, edge cases, and dependencies between changes
- On iterations 2+: revise the plan incorporating validator feedback

#### Agent 2: Plan Validator (subagent_type: general-purpose)
Validate the plan against reality:
- Verify every file and function referenced actually exists
- Confirm proposed changes don't conflict with recent commits
- Check that claimed interfaces/APIs match actual code
- Identify gaps, missing steps, or incorrect assumptions
- On iterations 2+: verify that previous iteration's issues are resolved

#### Agent 3: Reviewer (subagent_type: general-purpose)
Review the validated plan. Decide: **accept or iterate**.

**If satisfied** (no significant gaps, plan is grounded in reality):
- Produce a final recommendation with ordered implementation steps
- Set `accepted = true`

**If not satisfied** (gaps, wrong assumptions, missing context):
- Write feedback listing gaps, incorrect claims, unanswered questions
- Set `accepted = false` → next iteration
- Can request targeted follow-up research from team-research if needed

**On iteration 3** (final round): Accept the plan regardless, but clearly list remaining uncertainties.

### After the loop

Present the final plan to the user. Clean up the team with TeamDelete.

**STOP. Ask the user to approve the plan before proceeding.**

## Phase 2: Create GitHub Issue

Once the plan is approved:

1. Create a GitHub issue with a descriptive title and body:
   ```bash
   gh issue create --title "<concise title>" --body "<task description and acceptance criteria>"
   ```
2. Capture the issue number from the output.
3. Post the implementation plan as a comment on the issue:
   ```bash
   gh issue comment <NUMBER> --body "<the approved plan in markdown>"
   ```
4. Tell the user the issue number and link.

## Phase 3: Branch and Implement

1. Make sure you are on the default branch and it is up to date:
   ```bash
   git checkout <default-branch> && git pull
   ```
2. Create a feature branch named after the issue:
   ```bash
   git checkout -b feat/issue-<NUMBER>-<short-slug>
   ```
   - Use kebab-case for the slug (3-5 words max from the task title)
   - Example: `feat/issue-42-add-user-auth`
3. Implement the changes according to the approved plan.
   - Follow existing code conventions
   - Keep changes minimal and focused
   - Add or update tests for the changes

## Phase 4: Test and Verify

1. Run the project's test suite. Look for test commands in `package.json`, `Makefile`, `pyproject.toml`, or similar.
2. Run the project's linter if configured.
3. If tests or linting fail:
   - Fix the issues
   - Re-run until green
   - If stuck after 2 attempts, stop and ask the user for help

**STOP. Show the user a summary of changes (`git diff --stat`) and test results. Ask for approval to proceed with commit and PR.**

## Phase 5: Commit, Push, and PR

Once the user approves:

1. **Stage changes**: Add only the relevant files by name. Never use `git add -A` or `git add .`.
2. **Commit** with a message referencing the issue:
   ```bash
   git commit -m "$(cat <<'EOF'
   <descriptive commit message> (#<NUMBER>)

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```
3. **Push** the branch:
   ```bash
   git push -u origin feat/issue-<NUMBER>-<short-slug>
   ```
4. **Create the pull request**:
   ```bash
   gh pr create --title "<PR title>" --body "$(cat <<'EOF'
   ## Summary
   <2-3 bullet points describing the changes>

   ## Test Plan
   - <how changes were tested>

   Closes #<NUMBER>
   EOF
   )"
   ```
5. **Post PR link on the issue**:
   ```bash
   gh issue comment <NUMBER> --body "PR: <PR_URL>"
   ```

## Phase 6: Report

Print a final summary:
```
--- Ship Complete ---
Issue:  #<NUMBER> - <title>
Branch: feat/issue-<NUMBER>-<short-slug>
PR:     <PR_URL>
Status: Ready for review
```

## Rules

- **Never skip tests**. If no test runner is found, tell the user.
- **Never force push**. If push fails, diagnose and ask the user.
- **Never commit secrets**. Skip `.env`, credentials, or key files.
- **Keep the issue open**. The PR's `Closes #N` will close it on merge.
- **If anything fails unexpectedly**, stop and explain rather than guessing.
