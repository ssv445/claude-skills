# bin — helper scripts (not skills)

Plain scripts, symlink into `~/.local/bin`. Not Claude Code skills.

- **`claude-thread`** — session picker/resume wrapper (below)
- **`statusline.sh`** — Claude Code statusline hook (bottom)

---

## claude-thread

Bash wrapper around `claude` that adds the session management the terminal hosts lack:
menu to resume/archive/delete sessions per project, auto-resume on terminal recreation,
one state file tracking which session runs where.

## What it does

- **Source of truth**: claude's own `~/.claude/projects/<encoded-cwd>/*.jsonl` — no duplicate DB
- **Picker menu**: `Enter`=new, `<n>`=resume, `a<n>`=archive, `d<n>`=delete, `l`=archived/restore, `m`=show all, `q`=shell
- **Auto-resume**: recreated terminal claims the most recent free session for that cwd (2s countdown, any key = menu). PID-tracked in `~/.claude-thread/state.json` (flock'd) so parallel terminals never grab the same session
- **New sessions** get a pre-generated UUID via `claude --session-id` — tracked from birth
- **Filters**: hides `claude -p`/SDK sessions (entrypoint `sdk-cli`), empty sessions; previews skip caveat/slash-command noise; list capped at 15 (`m` = all)
- **Terminal title** = `<worktree>:<branch>` (understands Zed's `<base>/<name>/<repo>` worktree layout)
- **Archive** = move jsonl to `~/.claude-thread/archived/<encoded-cwd>/` — hidden from claude, restorable
- **Default flags**: `--dangerously-skip-permissions`, plus `--remote-control` on the main account only; extra flags via `CLAUDE_THREAD_ARGS`; binary via `CLAUDE_BIN`

## Accounts (profiles)

Run some work on another Claude subscription while keeping one setup. A profile is a
`CLAUDE_CONFIG_DIR` at `~/.claude-profiles/<name>`: it owns its login and per-process state,
and symlinks everything else (`CLAUDE.md`, settings, skills, plugins, memory, `projects/`)
to `~/.claude`. That is the layout Maestro documents for multi-account Claude Code.
Transcripts from every account still land in `~/.claude/projects`.

```bash
cld profile new shyam-dev
cld profile login shyam-dev                       # browser: sign in with THAT account
cld profile map shyam-dev '~/www/worktrees/*'     # folder or glob; longest route wins
cld profile list                                  # profiles, login state, routes
cld main                                          # force the main account here
cld @sun                                          # that account here (any unique start of its name)
cld @                                             # pick the account from a list
cld @sun --bg -n worker "<task>"                  # background agent on that account
cld @sun agents | attach <id> | logs <id> | stop <id>   # that account's background agents
cld ask "where is the Q3 pricing artifact?"       # read-only answer from main
cld quota                                         # each account's 7-day usage + next reset
                                                  #   (probes an account with no reading; --no-probe)
cld @"$(cld quota --pick)" --bg -n job "<task>"   # run on the account with headroom
cld spawn reviewer --brief .tmp/briefs/reviewer.md     # queue a long-lived agent here
cld @sun spawn reviewer --brief …                 # …on another account
cld spawn                                         # what's waiting (--cancel <name>)
```

**Spawned agents.** `cld spawn` queues a named agent for the current folder, with the
brief copied in. The next terminal thread you open in that folder (`cmd-n`) starts it
as a normal `cld` tab, so it has no idle limit, Zed restores it, and other agents reach
it by name through `ListAgents`/`SendMessage`. cld can't open the tab itself: Zed has no
command, link or extension API that starts a terminal thread.

- **New sessions** take the profile their folder maps to. **Resumed sessions** keep the
  account they started on, recorded in `state.json`. A remap never moves old sessions.
  `cld main`, `cld @<name>` or `CLAUDE_PROFILE=<name|main>` overrides both.
- **Quota.** No CLI reports claude.ai usage, so `statusline.sh` caches the 7-day
  `rate_limits` window Claude Code hands it into `<config dir>/usage.json` (percentage and
  reset time only; the 5-hour limit is gone, so it's ignored). A reading is as fresh as
  that account's last status-line render (background agents likely have none, so they may
  not refresh it). `--pick` prints the logged-in profile with the most headroom (under
  90%, `CLAUDE_QUOTA_LIMIT` to change), else `main`, else `none`. A logged-in account with
  no reading, or a reading older than its window's `resets_at`, gets **probed**:
  one Haiku message with no tools (`-p --output-format stream-json`), whose
  `rate_limit_event` carries the 7-day utilization — about $0.01, or $0 when the account is
  already at its limit. `--no-probe` skips it. If the probe fails, a missing reading
  stays `?` and a reset window counts as 0% (both treated as usable). Transcripts never record rate limits, so these two are the only sources. A
  usage-limit error is still the backstop.
- **Remote Control stays on main.** Profile launches drop `--remote-control` and pass
  `remoteControlAtStartup: false` through `--settings`, because the shared `settings.json` turns it on.
- **MCP servers come from main.** Each launch passes main's user servers, plus main's
  servers for that folder, through `--mcp-config`. Add a server once, on main.
- **Agents talk across accounts.** `sessions/` (the local peer registry) is shared, so
  `ListAgents` and `SendMessage` reach agents on every profile over local sockets.
  `claude agents` and background-agent control stay per account.
- Not shared, per profile: `.claude.json` (login), `daemon/`, `jobs/`, `teams/`,
  `history.jsonl`, caches. Claude.ai-side things are per account: artifacts, connectors,
  Remote Control and the "Help improve Claude" setting. Turn that setting off in each account.
- A logged-out profile refuses to launch and names the command that fixes it.

## Install

Symlink so this repo copy stays the single source of truth (edits go live everywhere, git tracks real content):

```bash
ln -sf "$(pwd)/claude-thread" ~/.local/bin/claude-thread   # run from this dir
```

Or a standalone copy if you don't want the repo dependency:

```bash
cp claude-thread ~/.local/bin/claude-thread && chmod +x ~/.local/bin/claude-thread
```

## Host integrations

**Zed Terminal Threads** (`~/.config/zed/settings.json`):
```json
{ "agent": { "terminal_init_command": "$HOME/.local/bin/claude-thread" } }
```
Runs in every new terminal thread AND when Zed recreates saved threads on project reopen — that's the resume path.

**super.engineering** (`~/.superconductor/settings.json` → `tools.claude.command`):
```json
"/Users/<you>/.local/bin/claude-thread"
```
sc's wrapper override dispatch execs claude-thread with sc's args; PATH resolves `claude` back through sc's own wrapper so sc hook injection stays intact. sc-aware behavior: `--session-id`/`--resume <id>` pass through (tracked); bare `--resume` (sc forgot the tab) auto-resumes from state. NOTE: sc flushes settings.json on quit — edit the file only while sc is NOT running (see `~/.claude-thread/patch-sc-setting.sh` pattern: detached watcher patches after quit).

**Any terminal**: just run `claude-thread` in a project dir.

## statusline.sh (bonus)

Standalone Claude Code statusline hook (two lines: model / project / worktree / git, then context bar / cost / duration / diff). Self-contained, no tmux, requires `jq`. Modernized from claude-wormhole.

```bash
ln -sf "$(pwd)/statusline.sh" ~/.local/bin/statusline
```
```json
// ~/.claude/settings.json
{ "statusLine": { "type": "command", "command": "/Users/<you>/.local/bin/statusline" } }
```
