# Claude Code Skills

Custom skills for [Claude Code](https://claude.ai/code) (and other agents — Cursor, Codex, Cline, Gemini CLI, etc.).

Browse online: **[skills.sh/ssv445/claude-skills](https://skills.sh/ssv445/claude-skills)**

## Skills

| Skill | Description |
|-------|-------------|
| [write-blog](./write-blog/) | Blog post creation with audience-first approach, APP formula, Cialdini's persuasion principles, and mandatory humanization. |
| [xterm-js](./xterm-js/) | Best practices for building terminal apps with xterm.js, React, and WebSockets. |
| [ios-safari-quirks](./ios-safari-quirks/) | 55+ documented iOS Safari JavaScript quirks with fixes. |
| [gh-discussion](./gh-discussion/) | Create and manage GitHub Discussions via GraphQL API. |
| [test-stories](./test-stories/) | AI-driven user story testing with browser automation subagents. |
| [nightshift](./nightshift/) | Autonomous overnight GitHub issue processing. 7-step TDD pipeline with review gates, expert panels, and thin orchestrator pattern. |
| [commit](./commit/) | Commit staged changes following repo conventions. Simple and focused. |
| [brainstorm](./brainstorm/) | One-question-at-a-time ideation to build detailed specs. Inspired by [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent. |
| [ship](./ship/) | Ship a task end-to-end: GitHub issue, branch, implement, test, PR. |
| [handoff](./handoff/) | Save/resume context across `/clear` boundaries. Compresses conversation to `.tmp/handoff/`, symlinks latest, and auto-starts next items on resume. |
| [caveman-distillate](./caveman-distillate/) | Ultra-compressed communication mode (~65% fewer tokens). Based on [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) by Julius Brussee. |
| [run-detached](./run-detached/) | Run any slash command or prompt in a fresh `claude -p` subprocess inside a detached tmux session with a live stream-json formatter. Escapes nested-subagent limits; sessions (`detached-run-claude-<id>`) show up in `tmux ls` and claude-wormhole. |
| [usage-check](./usage-check/) | Check Claude.ai usage limits (session/weekly) via Chrome in a subagent so main context stays clean. Optional threshold arg warns when any limit exceeds %. |
| [subagent-first](./subagent-first/) | Decision tree + red flags to keep main-agent context clean by routing exploration, long-running commands, MCP calls, reviews, and research to specialized subagents. Reference from your global CLAUDE.md. |
| [ack](./ack/) | Force agent to acknowledge intent before acting: parse request, rephrase in 1-3 bullets, ask permission, wait for explicit `y`, then execute. Tool whitelist, scope-drift rule, rationalization table. |
| [devloop](./devloop/) | Tight polish loop after a feature ships. Takes test-stories IDs, runs tests, fixes prioritized issues with a unanimous 3-seat expert panel (adversarial + root-cause + convention) and browser screenshot check, re-runs, repeats until clean. Fire-and-forget. |
| [rca](./rca/) | Root cause analysis in 5 fresh-subagent rounds. Fixed themes (Surface → Mechanism → Challenge → Alternatives → Synthesize). Adversarial review mandatory each round. Accumulates to `.tmp/rca/rca-<ts>.md`. Ends with 2-3 ranked theories + verification tests. Domain-agnostic (code bugs, traffic drops, churn, funnel leaks). |
| [domain-rating](./domain-rating/) | Fetch Ahrefs Domain Rating (DR) for any domain via the free public API. No key. Single + batch lookup, caching, error codes, attribution rules. |
| [theteam](./theteam/) | Spawn a panel of agents in parallel (Claude / Codex / Gemini CLIs) to review, critique, or decide. Three modes: `review` (balanced), `critic` (adversarial), `decide` (advocate-per-option or axis evaluation). Real-call CLI pre-flight, prompt-injection fencing, confidence labels lead synthesis, binary confirm. |

## Scripts (`bin/`)

Plain executables, not skills — symlink them onto your `PATH` (`ln -s "$PWD/bin/<name>" ~/.local/bin/<name>`).

| Script | Description |
|--------|-------------|
| [shyambot-chrome](./bin/shyambot-chrome) | **The** browser entry point for agents. Starts/focuses one shared, logged-in Chrome profile and prints its CDP port. Idempotent, works headless under `claude -p`, keeps logins across restarts, never touches your daily Chrome. |
| [agent-chrome](./bin/agent-chrome) | Manages those profiles: `start`/`stop`/`list`/`port`/`url`/`clone`. Each profile gets its own `user-data-dir` + CDP port, launched with flags so there's no "Allow remote debugging?" prompt. |
| [claude-thread](./bin/claude-thread) | Keeps a Claude session per worktree and restores it. Sessions are keyed by cwd, so each worktree gets its own thread back — reopen it (or let the terminal be recreated) and you resume where you left off instead of starting cold. Tracks running/ended state in `~/.claude-thread/`, archives sessions you want hidden, and titles the terminal `<worktree-dir>:<branch>`. Wired in as Zed's `agent.terminal_init_command`, but the session logic isn't Zed-specific. |
| [statusline.sh](./bin/statusline.sh) | Claude Code status line command. |

### Why `shyambot-chrome` exists

Claude Code's Chrome extension is an **interactive-session pairing, not an MCP server**. Under
`claude -p` (cron, dispatchers, headless agents) the `mcp__claude-in-chrome__*` tools are simply
absent, so any routine built on them silently degrades — ours fell back to API-only totals for 25
days without failing loudly. Driving a dedicated CDP profile instead works identically in both
modes.

```bash
shyambot-chrome                      # launch or focus; prints CDP port
shyambot-chrome https://example.com  # launch and navigate
agent-browser --cdp $(shyambot-chrome --port) eval "document.title"
shyambot-chrome --stop
```

Logins persist in `~/.agent-browsers/<profile>/` — sign in once by hand, and every agent inherits
the session. Never hand credentials to an agent.

`agent-chrome clone <name>` additionally builds `~/Applications/<name>-chrome.app`: an APFS
block-clone of Chrome (≈no extra disk) with its own `CFBundleIdentifier`, name, and icon, so the
profile is a **separate app in Cmd+Tab** rather than another anonymous "Google Chrome" window.
Editing `Info.plist` invalidates Chrome's signature, so the script runs `xattr -cr` then re-signs
ad-hoc — skip either step and macOS kills the app at launch with no error. Re-run after Chrome
auto-updates; the clone does not update itself.

macOS only (Chrome paths, `codesign`, `PlistBuddy`).

## Companion skills (install upstream)

These skills aren't kept in this repo because the upstream repos already publish them in a `skills`-CLI-compatible format. Install directly from upstream:

| Skill | Upstream install | Author |
|---|---|---|
| `humanizer` | `npx skills add blader/humanizer -g` | Siqi Chen ([blader/humanizer](https://github.com/blader/humanizer)) |
| `gstack` (≈ plan-exit-review) | `npx skills add garrytan/gstack -g` | Garry Tan ([garrytan/gstack](https://github.com/garrytan/gstack)) |
| `karpathy-guidelines` | `npx skills add forrestchang/andrej-karpathy-skills -g` | [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) (after Andrej Karpathy) |
| `portless` | `npx skills add vercel-labs/portless -g` | Vercel Labs ([vercel-labs/portless](https://github.com/vercel-labs/portless)) |

Install them once and they update via `npx skills update`.

## Installation

**Recommended** — via the [`skills`](https://github.com/vercel-labs/skills) CLI by Vercel Labs (default behavior is symlink, so `git pull` updates everything; pass `--copy` for portable install):

```bash
# Install one skill globally (user-level, all detected agents)
npx skills add ssv445/claude-skills -s write-blog -g

# Install all skills from this repo
npx skills add ssv445/claude-skills --all -g

# List available skills without installing
npx skills add ssv445/claude-skills -l

# Update installed skills
npx skills update

# Remove
npx skills remove write-blog -g
```

Or browse + install from the web index at [skills.sh/ssv445/claude-skills](https://skills.sh/ssv445/claude-skills).

**Manual install** — clone the repo and copy or symlink any skill dir:

```bash
git clone https://github.com/ssv445/claude-skills.git ~/code/claude-skills
ln -s ~/code/claude-skills/<skill-folder> ~/.claude/skills/<skill-folder>
# or: cp -r ~/code/claude-skills/<skill-folder> ~/.claude/skills/
```

## Usage

Invoke any skill in Claude Code:

```
/<skill-name>
```

For example: `/write-blog`, `/commit`, `/handoff`, `/rca`
