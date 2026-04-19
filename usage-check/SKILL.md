---
name: usage-check
description: "Check Claude.ai usage limits (hourly/weekly) via Chrome browser. Runs in subagent to keep main context clean. Optional threshold arg triggers warning. Usage: /usage-check or /usage-check 80"
---

# Usage Check

Check Claude.ai usage limits via browser. **Always run in subagent** — never pollute main context.

- `/usage-check` — report current usage
- `/usage-check <threshold>` — report + warn if any limit exceeds threshold %

## Subagent Prompt

Spawn subagent with this (fill threshold from `$ARGUMENTS`, default 80):

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

## Subagent Config

- **type**: `mcp-fetch` (has browser MCP access)
- **tools**: `mcp__claude-in-chrome__tabs_context_mcp`, `mcp__claude-in-chrome__tabs_create_mcp`, `mcp__claude-in-chrome__get_page_text`

## Gotchas

- Always subagent — never browser tools in main
- Reuse existing usage page tab if open
- Include extra usage section if visible
