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
- **Default flags**: `--dangerously-skip-permissions --chrome --remote-control`, override via `CLAUDE_THREAD_ARGS`; binary via `CLAUDE_BIN`

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
