---
name: chrome-wrapper
description: Use when an agent needs the real internet through a logged-in browser — dashboards, consoles, accounts, research, scraping — via a chrome-wrapper identity driven by agent-browser over CDP. Covers taking your own window, keeping the CDP attach alive, daemon lifetime, and diagnosing a logged-out identity. Not for testing your own projects (use plain agent-browser).
---

# chrome-wrapper — driving a persistent Chrome identity

`chrome-wrapper` (see `bin/install-chrome-wrapper.md`) manages isolated Chrome **identities**: one identity = one set of logins, its own profile, its own fixed CDP port, its own macOS app. You drive one with `agent-browser --cdp <port>`.

## Which browser

| Pointing at | Use | Why |
|---|---|---|
| Your own project (localhost, preview/staging, e2e, build screenshots) | plain `agent-browser` | Throwaway logged-out profile: no user cookies leak into a test, no test mutates real sessions. |
| The real internet (logged-in accounts, dashboards, research, scraping) | `chrome-wrapper-<identity>` | Logins persist, headless-safe (works under `claude -p`), never touches the user's daily Chrome. |

## The recipe — always your own session and your own window

```bash
PORT=$(chrome-wrapper-<identity> --port); S="job-$$"
W=$(chrome-wrapper-<identity> --window)                        # a NEW window, yours alone; prints its tab id
agent-browser --session "$S" --cdp "$PORT" --pin-tab tab "$W"  # bind your session to it
agent-browser --session "$S" --cdp "$PORT" open https://…      # navigates YOUR tab
chrome-wrapper-<identity> --close-window "$W"                  # done: closes your window and every tab in it
```

**Why a window, not `tab new`.** `agent-browser tab new` opens in whichever window Chrome last focused — measured: the user's own — so parallel agents' tabs pile into one window and get closed, refocused and navigated by each other. A window of your own keeps your tabs together (links opened with `click --new-tab` land in it too) and `--close-window` cleans all of them up in one call. Never reuse a window or tab you did not open, and never call `tab new` — navigate inside your window instead.

**Always close it.** Run `--close-window` when you finish, including on failure — a leaked window is clutter the user has to clean up. `--close-window` only closes windows `--window` opened (tracked in `~/.chrome-wrapper/agent-windows`), so a wrong id cannot close the user's window.

**Why `--pin-tab`.** Without it, a session whose tab disappears silently falls back to another tab — someone else's — and keeps driving it. With it, the next command fails loudly with `tab_gone`.

**Why a unique `--session`.** `--cdp` attaches; it does not launch. A fresh session adopts the *first* page target in the list — measured: an old tab of the user's, not the focused one and not a new one. Every agent on the default session steers that same tab.

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
