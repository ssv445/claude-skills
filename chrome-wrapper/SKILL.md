---
name: chrome-wrapper
description: Use when an agent needs the real internet through a logged-in browser — dashboards, consoles, accounts, research, scraping — via a chrome-wrapper identity driven by agent-browser over CDP. Covers taking your own tab, keeping the CDP attach alive, daemon lifetime, and diagnosing a logged-out identity. Not for testing your own projects (use plain agent-browser).
---

# chrome-wrapper — driving a persistent Chrome identity

`chrome-wrapper` (see `bin/install-chrome-wrapper.md`) manages isolated Chrome **identities**: one identity = one set of logins, its own profile, its own fixed CDP port, its own macOS app. You drive one with `agent-browser --cdp <port>`.

## Which browser

| Pointing at | Use | Why |
|---|---|---|
| Your own project (localhost, preview/staging, e2e, build screenshots) | plain `agent-browser` | Throwaway logged-out profile: no user cookies leak into a test, no test mutates real sessions. |
| The real internet (logged-in accounts, dashboards, research, scraping) | `chrome-wrapper-<identity>` | Logins persist, headless-safe (works under `claude -p`), never touches the user's daily Chrome. |

## The recipe — always your own session and your own tab

```bash
PORT=$(chrome-wrapper-<identity> --port); S="job-$$"
agent-browser --session "$S" --cdp "$PORT" tab new          # bare — `tab new <url>` returns before load
agent-browser --session "$S" --cdp "$PORT" open https://…   # navigates YOUR tab
agent-browser --session "$S" --cdp "$PORT" tab close        # closes only yours
```

**Why a unique `--session` and a new tab.** `--cdp` attaches; it does not launch. A fresh session adopts the *first* page target in the list — measured: an old tab of the user's, not the focused one and not a new one. Every agent on the default session steers that same tab, so two agents (or an agent and the user) end up driving one tab. Two sessions on the same identity can still cross-drive each other's tabs, so don't browse in parallel with a subagent on one identity.

**Why `--cdp "$PORT"` on every command, not just the first.** agent-browser daemons self-shut after idling. If one is reaped mid-task, the next bare `--session` command silently spawns a fresh daemon with *no* attach — its own logged-out browser, wrong identity, the exact failure this tool exists to prevent. Repeating `--cdp` makes the respawn re-attach.

## Daemon lifetime

agent-browser's default 1h **idle** self-shutdown exempts user-attached (`--cdp`) browsers, so attached daemons never die — one machine leaked 35 of them, living up to 6 days. Setting `AGENT_BROWSER_IDLE_TIMEOUT_MS=3600000` explicitly (shell env, Claude Code `settings.json` env, and any job runner's env) drops the exemption. It is idle time, not age: an active session keeps resetting the timer, so only parked daemons die.

## Diagnosing failure

- **Logged-out browser** = wrong identity or wrong port. Stop and ask; never fall back to another identity or to plain agent-browser — they are not interchangeable.
- **Identity not running** → run `chrome-wrapper-<identity>` first. `--port` reads the registry; it does not launch.
- **Logged in yesterday, logged out today, history intact** → a signing problem, not an account problem. `chrome-wrapper signing-identity`; any bundle `NOT pinned` needs `chrome-wrapper rebuild <name>` with the user at a terminal to answer the keychain prompt.
- `chrome-wrapper new` / `rm` and every sign-in need the user at a terminal. They refuse to run unattended by design — ask, never script around them, never handle credentials.

## Why not claude-in-chrome

The `claude-in-chrome` extension only pairs in interactive sessions. Anything built on it silently degrades under `claude -p` — a nightly job ran in fallback mode for 25 days without once failing loudly. chrome-wrapper + agent-browser works headless.
