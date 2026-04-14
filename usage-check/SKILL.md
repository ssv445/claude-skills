---
name: usage-check
description: "Check Claude.ai usage limits (hourly/weekly) via Chrome browser. Runs in subagent to keep main context clean. Optional threshold arg triggers warning. Usage: /usage-check or /usage-check 80"
---

# Usage Check

Check Claude.ai plan usage limits via browser automation. Runs entirely in a subagent.

## Trigger
- `/usage-check` — report current usage
- `/usage-check <threshold>` — report + warn if any limit exceeds threshold %

## Execution

**Always run in a subagent.** Never pollute main context with browser tool results.

Spawn a subagent with this prompt (fill in threshold from `$ARGUMENTS`, default 80 if blank):

---

### Subagent Prompt

```
You are checking Claude.ai usage limits. Report in caveman style (no articles, minimal words).

THRESHOLD: <threshold>%

Steps:
1. Call mcp__claude-in-chrome__tabs_context_mcp with createIfEmpty=true
2. If no tab on claude.ai/settings/usage, create one via mcp__claude-in-chrome__tabs_create_mcp with url "https://claude.ai/settings/usage", wait 3s
3. Call mcp__claude-in-chrome__get_page_text on that tab
4. Parse the text for:
   - Current session: % used, resets in
   - Weekly all models: % used, resets
   - Weekly sonnet only: % used, resets (if present)
   - Extra usage: spent, limit, balance (if present)
5. Report in this exact format:

SESSION: <X>% used | resets <time>
WEEKLY (all): <X>% used | resets <time>
WEEKLY (sonnet): <X>% used | resets <time>
EXTRA: $<spent>/$<limit> | balance $<bal>

If threshold provided, add:
⚠ OVER THRESHOLD: <list any limits exceeding threshold%>
or:
✓ All limits below <threshold>%

If page not loaded or not logged in, say: "Can't read usage page. Login to claude.ai first."
```

---

## Subagent Config

- **type**: `mcp-fetch` (has browser MCP access)
- **tools needed**: `mcp__claude-in-chrome__tabs_context_mcp`, `mcp__claude-in-chrome__tabs_create_mcp`, `mcp__claude-in-chrome__get_page_text`
- **isolation**: none (needs existing browser session)

## Example Output

```
SESSION: 5% used | resets 3 hr 29 min
WEEKLY (all): 10% used | resets Sun 8:30 AM
WEEKLY (sonnet): 15% used | resets 5 hr 29 min
EXTRA: $16.70/$50 | balance $183.29

✓ All limits below 80%
```

## Common Mistakes
- Running browser tools in main agent — always subagent
- Not checking if usage page tab already exists — reuse it
- Forgetting extra usage section — include if visible
