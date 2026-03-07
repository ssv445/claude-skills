---
name: test-stories
version: 1.0.0
description: |
  AI-driven user story testing. Reads user story markdown files and executes
  acceptance criteria as intelligent browser tests using subagents.
  Use: /test-stories, /test-stories 02-feed, /test-stories FEED-05,
  /test-stories docs/user-stories/
allowed-tools:
  - Agent
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
---

# Test Stories — AI-Driven User Story Testing

Execute user story acceptance criteria as intelligent browser tests.

## Usage

The user invokes this skill with an optional filter argument:

| Input | Behavior |
|-------|----------|
| (none) | Run all stories in `docs/user-stories/` |
| `02-feed` | Run `docs/user-stories/02-feed.md` |
| `FEED-05` | Run only story ID `FEED-05` from its parent file |
| `docs/user-stories/` | Run all `.md` files in that folder |
| `docs/some-subfolder/` | Run all `.md` files in that folder |

## Prerequisites Check

Before running tests, verify dev servers are up:

1. Use Bash to curl `http://ecomitram.localhost:1355` — if it fails, tell user: "Start web server: `pnpm --filter @ecomitram/web dev`"
2. Use Bash to curl `http://api.ecomitram.localhost:1355/health` — if it fails, tell user: "Start API server: `pnpm --filter @ecomitram/api dev`"

If either server is down, STOP and ask the user to start them. Do not proceed.

## Step 1: Resolve Target Story Files

Parse the user's argument to determine which files to test:

1. **No argument**: Glob `docs/user-stories/*.md` — collect all files, sort by filename
2. **Looks like a file name** (e.g., `02-feed`, no uppercase, has digits): Try `docs/user-stories/{arg}.md`. If not found, try `docs/user-stories/*{arg}*.md`
3. **Looks like a story ID** (e.g., `FEED-05` — uppercase letters, hyphen, digits): Grep all files in `docs/user-stories/` for `## {arg}:`. Use the matching file, pass the story ID as filter.
4. **Looks like a folder path** (ends with `/` or contains `/`): Glob `{path}/*.md`

Store:
- `storyFiles`: list of absolute file paths
- `storyIdFilter`: specific story ID to test, or `null` for all stories in each file

## Step 2: Load Agent Instructions

Read the file `~/.claude/skills/test-stories/AGENT.md` into a variable. This is the complete instruction set for each testing subagent.

## Step 3: Create Run Folder

Before dispatching subagents:

1. Generate a timestamp: `YYYY-MM-DD-HHmm` (e.g., `2026-03-06-1430`) using `date +%Y-%m-%d-%H%M`
2. Create the screenshot directory: `mkdir -p test-results/stories/{timestamp}/`
3. Store:
   - `runTimestamp`: the timestamp string
   - `screenshotDir`: absolute path to `test-results/stories/{timestamp}/`
   - `reportPath`: `test-results/stories/{timestamp}.md`

## Step 4: Dispatch Subagents (Sequential)

For each story file in `storyFiles`:

1. Read the story file content
2. Derive a `fileSlug` from the filename (e.g., `01-auth` from `01-auth.md`)
3. Spawn a **general-purpose subagent** with this prompt:

```
You are a QA testing agent. Follow the AGENT INSTRUCTIONS below exactly.

## AGENT INSTRUCTIONS

{contents of AGENT.md}

## STORY TO TEST

{contents of the story markdown file}

## CONFIGURATION

- Base URL: http://ecomitram.localhost:1355
- API URL: http://api.ecomitram.localhost:1355
- Story ID filter: {storyIdFilter or "ALL"}
- Screenshot dir: {absolute path to screenshotDir}
- File slug: {fileSlug}
- Run timestamp: {runTimestamp}

Execute the tests now and return your report.
```

**Subagent settings:**
- `subagent_type`: `general-purpose`
- `model`: `sonnet` (faster than opus for execution)
- `description`: `Test {filename}` (e.g., "Test 02-feed.md")

3. Wait for subagent to complete
4. Store the returned report text

**If a subagent fails/crashes:** Record `"## {filename}: AGENT ERROR\n{error message}"` and continue.

## Step 5: Write Report & Print Summary

After all subagents complete:

### 5a. Build the report content

Assemble a markdown report with this structure:

```markdown
# Test Stories Report — {YYYY-MM-DD HH:mm}

**Scope:** {comma-separated list of story files tested}
**Summary:** X passed, Y failed, Z skipped

## {filename} (e.g., 01-auth.md)

### {STORY-ID}: {Title} {overall_icon}
  {icon} {criterion text} — {evidence}
  {icon} {criterion text} — {evidence}
![{STORY-ID}](./{runTimestamp}/{fileSlug}-{STORY-ID}.png)

### {STORY-ID}: {Title} {overall_icon}
  {icon} {criterion text} — {evidence}
![{STORY-ID} FAIL](./{runTimestamp}/{fileSlug}-{STORY-ID}-FAIL.png)

---

## Failures Summary
1. **{STORY-ID}**: {one-line description}
...

## Learnings
- {patterns or observations}
```

Count totals across all reports:
- Total passed (lines starting with `✓`)
- Total failed (lines starting with `✗`)
- Total skipped (lines starting with `⊘`)

Analyze learnings by scanning all reports for patterns:
- Same failure text across multiple stories → "Systemic: {description}"
- Console errors mentioned → "Frontend/API errors detected"
- Network failures mentioned → "API endpoints failing"
- "UNBLOCKED" mentions → "Issues potentially fixed: {list}"
- Missing data-testid → "Components missing test IDs: {list}"

### 5b. Write report file

Use the `Write` tool to save the report to `{reportPath}` (i.e., `test-results/stories/{runTimestamp}.md`).

### 5c. Print brief summary to chat

Print only a short summary to chat (not the full report):

```
Test report saved: test-results/stories/{runTimestamp}.md
Screenshots: test-results/stories/{runTimestamp}/
Summary: X passed, Y failed, Z skipped
```

If there are failures, list them briefly (one line each).

## Rules

- Do NOT open browser yourself — subagents handle all browser interaction
- Do NOT modify any files — this is diagnosis only, never fix anything
- Do NOT dispatch subagents in parallel — sequential to avoid browser conflicts
- Keep main context clean — only store the report text from each subagent
- If all servers are up, proceed without asking — don't ask "should I start testing?"
