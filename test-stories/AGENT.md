# Test Stories — Subagent Instructions

QA testing agent. Test ONE story file via Playwright MCP. Report pass/fail per criterion with evidence.

## Browser Tools

| Tool | Purpose |
|------|---------|
| `browser_navigate` | Go to URL |
| `browser_snapshot` | Accessibility snapshot (best for checking elements) |
| `browser_click` | Click element by ref |
| `browser_type` | Type text |
| `browser_evaluate` | Run JS in page |
| `browser_take_screenshot` | Screenshot (1 per story + extra on FAIL) |
| `browser_console_messages` | Check JS errors |
| `browser_network_requests` | Check failed HTTP requests |
| `browser_wait_for` | Wait for text appear/disappear |
| `browser_press_key` | Keyboard key |
| `browser_tabs` | Manage tabs |

**Pattern:** Navigate → snapshot → check refs → click/type → snapshot to verify.

## Execution Flow

### 1. Setup

Just navigate to first URL — Playwright auto-launches browser.

### 2. Parse Story

Extract from STORY TO TEST markdown:

- **Story blocks**: `## STORY-ID: Title` sections
- **Acceptance criteria**: `- [ ]` lines under `### Acceptance Criteria`
- **Known issues**: "Blocked by #N" under `### Known Issues`
- **Auth requirement** from "As a" line:
  - "visitor" / "no login required" → no auth
  - "authenticated" / "logged-in" / "user" → needs auth
- **Target URLs**: Infer from criteria (`/feed`, `/login`, `/create`, `/post/:id`)

**Story ID filter**: If CONFIGURATION specifies ID (not "ALL"), only test that one.

### 3. Authenticate (If Needed)

1. Navigate to base URL
2. `browser_evaluate`:

```javascript
async () => {
  const res = await fetch('http://api.ecomitram.localhost:1355/auth/dev-login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@dev.local' }),
    credentials: 'include'
  });
  const data = await res.json();
  if (data.access_token) {
    document.cookie = `access_token=${data.access_token}; path=/`;
  }
  return { ok: res.ok, hasCookie: document.cookie.includes('access_token') };
}
```

3. Navigate to target page (picks up cookie)

**Users by email:**

| Need | Email |
|------|-------|
| Default auth user | `admin@dev.local` |
| No location set | `newuser@dev.local` |
| Trusted user | `trusted@dev.local` |

Default to `admin@dev.local`.

### 4. Test Each Story

**a. Navigate** directly to target URL (infer from criteria). Never click through menus.

**b. Snapshot** — `browser_snapshot` for accessibility tree with refs.

**c. Check each criterion** (`- [ ]` line):

1. Determine check type: element exists (snapshot), text content (snapshot/evaluate), URL (evaluate → `location.href`), interaction result (click/type → re-snapshot), styling (evaluate computed styles), not visible (confirm absent), cookie/storage (evaluate)

2. Deterministic first: `data-testid` → URLs → text content → AI judgment only for ambiguous criteria

3. Record: **PASS** (what observed, ~10 words) / **FAIL** (expected vs actual) / **SKIP** (known issue ref)

**d. Screenshots** — one per story: `{screenshotDir}/{fileSlug}-{STORY-ID}.png`. Extra on FAIL: `...-FAIL.png`.

**e. Bonus signals** (once per page, after all criteria):
- `browser_console_messages` level `error`
- `browser_network_requests` `includeStatic: false` — note 4xx/5xx

### 5. Handle Known Issues

If "Blocked by #N":
1. Mark related criteria SKIP
2. Still attempt check
3. If passes: `UNBLOCKED: #N may be fixed!`

### 6. Return Report

Format entire response as this report. Nothing else.

```
## {STORY-ID}: {Title} {overall_icon}
  {icon} {criterion} — {evidence}
  ...
  {bonus signals if any}
![{STORY-ID}](./{runTimestamp}/{fileSlug}-{STORY-ID}.png)

---
ISSUES FOUND:
- {one-line per issue}

LEARNINGS:
- {patterns affecting other stories}
```

Use `runTimestamp` and `fileSlug` from CONFIGURATION for screenshot links.

**Icons:** `✓` PASS | `✗` FAIL | `⊘` SKIP (known issue) | `⚠` Warning (console/network)

**Overall per story:** `✓` all pass | `✗` any fail | `⊘` all skip

**Evidence examples:**
- `✓ Feed page loads at /feed — 12 posts visible in snapshot`
- `✗ Hashtag chips visible — no data-testid="hashtag-chip" in snapshot`
- `⊘ OG preview renders — SKIP: Blocked by #91`
- `⚠ Console: 3 errors (React hydration mismatch on PostCard)`
- `⚠ Network: POST /posts/abc/like returned 401`

## Speed Rules

- **Direct navigation only.** Never click through menus.
- **One snapshot per page.** Check multiple criteria from it. Re-snapshot only after page-changing interactions.
- **data-testid first.** Fall back to text/role matching.
- **One screenshot per story.** Extra only on FAIL.
- **Batch page checks.** All criteria for same page from ONE snapshot before navigating.

## Reliability Rules

- Page doesn't load in 15s → FAIL all criteria "page did not load"
- Playwright tool errors → retry once, second failure → report error, skip remaining
- Auth fails → FAIL all auth-required stories "authentication failed"
- Empty/minimal snapshot → wait 2s with `browser_wait_for`, re-snapshot (SPA loading)

## Boundaries

- Do NOT modify files, run terminal commands, fix issues, generate test code
- Do NOT navigate to external URLs (local dev server only)
- Do NOT add checks beyond acceptance criteria
