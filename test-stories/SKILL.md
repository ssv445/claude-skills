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

# Test Stories

Execute user story acceptance criteria as browser tests via subagents.

## Usage

| Input | Behavior |
|-------|----------|
| (none) | All stories in `docs/user-stories/` |
| `02-feed` | `docs/user-stories/02-feed.md` |
| `FEED-05` | Only story ID `FEED-05` from its parent file |
| `docs/user-stories/` | All `.md` files in that folder |
| `docs/some-subfolder/` | All `.md` files in that folder |

## Prerequisites

Curl both before starting — if either fails, STOP and tell user:

1. `http://ecomitram.localhost:1355` — "Start web server: `pnpm --filter @ecomitram/web dev`"
2. `http://api.ecomitram.localhost:1355/health` — "Start API server: `pnpm --filter @ecomitram/api dev`"

## Step 1: Resolve Target Files

Parse argument:

1. **No arg**: Glob `docs/user-stories/*.md`, sort by filename
2. **Looks like filename** (lowercase, digits, e.g. `02-feed`): Try `docs/user-stories/{arg}.md`, fallback `docs/user-stories/*{arg}*.md`
3. **Looks like story ID** (uppercase+hyphen+digits, e.g. `FEED-05`): Grep `docs/user-stories/` for `## {arg}:`, use matching file, pass ID as filter
4. **Looks like folder** (ends with `/` or contains `/`): Glob `{path}/*.md`

Store: `storyFiles` (absolute paths), `storyIdFilter` (specific ID or `null`)

## Step 2: Load Agent Instructions

Read `~/.claude/skills/test-stories/AGENT.md` into variable.

## Step 3: Create Run Folder

1. Timestamp: `date +%Y-%m-%d-%H%M` → `YYYY-MM-DD-HHmm`
2. `mkdir -p test-results/stories/{timestamp}/`
3. Store: `runTimestamp`, `screenshotDir` (absolute), `reportPath`: `test-results/stories/{timestamp}.md`

## Step 4: Dispatch Subagents (Sequential)

For each story file:

1. Read file content
2. Derive `fileSlug` from filename (e.g. `01-auth` from `01-auth.md`)
3. Spawn general-purpose subagent:

```
You are a QA testing agent. Follow the AGENT INSTRUCTIONS below exactly.

## AGENT INSTRUCTIONS
{contents of AGENT.md}

## STORY TO TEST
{story markdown content}

## CONFIGURATION
- Base URL: http://ecomitram.localhost:1355
- API URL: http://api.ecomitram.localhost:1355
- Story ID filter: {storyIdFilter or "ALL"}
- Screenshot dir: {screenshotDir}
- File slug: {fileSlug}
- Run timestamp: {runTimestamp}

Execute the tests now and return your report.
```

Settings: `subagent_type: general-purpose`, `model: sonnet`, `description: Test {filename}`

4. Wait for completion, store report
5. **If subagent crashes:** Record `"## {filename}: AGENT ERROR\n{error}"`, continue

## Step 5: Write Report & Print Summary

### 5a. Build Report

```markdown
# Test Stories Report — {YYYY-MM-DD HH:mm}

**Scope:** {story files tested}
**Summary:** X passed, Y failed, Z skipped

## {filename}

### {STORY-ID}: {Title} {overall_icon}
  {icon} {criterion} — {evidence}
![{STORY-ID}](./{runTimestamp}/{fileSlug}-{STORY-ID}.png)

---

## Failures Summary
1. **{STORY-ID}**: {one-line description}

## Learnings
- {patterns or observations}
```

Count totals: `✓` = passed, `✗` = failed, `⊘` = skipped

Analyze learnings:
- Same failure across stories → "Systemic: {description}"
- Console errors → "Frontend/API errors detected"
- Network failures → "API endpoints failing"
- UNBLOCKED mentions → "Issues potentially fixed: {list}"
- Missing data-testid → "Components missing test IDs: {list}"

### 5b. Write report to `{reportPath}`

### 5c. Print brief summary to chat

```
Test report saved: test-results/stories/{runTimestamp}.md
Screenshots: test-results/stories/{runTimestamp}/
Summary: X passed, Y failed, Z skipped
```

List failures briefly if any (one line each).

## Rules

- Do NOT open browser yourself — subagents handle all browser interaction
- Do NOT modify any files — diagnosis only
- Do NOT dispatch subagents in parallel — sequential to avoid browser conflicts
- Keep main context clean — only store report text from each subagent
- If servers up, proceed without asking
