# Claude Code Skills

Custom skills for [Claude Code](https://claude.ai/code).

## Skills

| Skill | Description |
|-------|-------------|
| [humanizer](./humanizer/) | Remove AI-generated writing patterns from text. Based on [blader/humanizer](https://github.com/blader/humanizer) by Siqi Chen. |
| [write-blog](./write-blog/) | Blog post creation with audience-first approach, APP formula, Cialdini's persuasion principles, and mandatory humanization. |
| [xterm-js](./xterm-js/) | Best practices for building terminal apps with xterm.js, React, and WebSockets. |
| [ios-safari-quirks](./ios-safari-quirks/) | 55+ documented iOS Safari JavaScript quirks with fixes. |
| [plan-exit-review](./plan-exit-review/) | Thorough plan review before implementation. Based on [garrytan/gstack](https://github.com/garrytan/gstack) by Garry Tan. |
| [gh-discussion](./gh-discussion/) | Create and manage GitHub Discussions via GraphQL API. |
| [portless](./portless/) | Named local dev server URLs. Based on [vercel-labs/portless](https://github.com/vercel-labs/portless) by Vercel Labs. |
| [test-stories](./test-stories/) | AI-driven user story testing with browser automation subagents. |
| [nightshift](./nightshift/) | Autonomous overnight GitHub issue processing. 7-step TDD pipeline with review gates, expert panels, and thin orchestrator pattern. |
| [commit](./commit/) | Commit staged changes following repo conventions. Simple and focused. |
| [brainstorm](./brainstorm/) | One-question-at-a-time ideation to build detailed specs. Inspired by [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent. |
| [ship](./ship/) | Ship a task end-to-end: GitHub issue, branch, implement, test, PR. |
| [handoff](./handoff/) | Save/resume context across `/clear` boundaries. Compresses conversation to `.tmp/handoff/`, symlinks latest, and auto-starts next items on resume. |
| [caveman-distillate](./caveman-distillate/) | Ultra-compressed communication mode (~65% fewer tokens). Based on [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) by Julius Brussee. |
| [run-detached](./run-detached/) | Run any slash command or prompt in a fresh `claude -p` subprocess inside a detached tmux session with a live stream-json formatter. Escapes nested-subagent limits; sessions (`detached-run-claude-<id>`) show up in `tmux ls` and claude-wormhole. |
| [usage-check](./usage-check/) | Check Claude.ai usage limits (session/weekly) via Chrome in a subagent so main context stays clean. Optional threshold arg warns when any limit exceeds %. |
| [karpathy-guidelines](./karpathy-guidelines/) | Behavioral guidelines to reduce common LLM coding mistakes: think before coding, simplicity first, surgical changes, goal-driven execution. Based on [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills). |
| [subagent-first](./subagent-first/) | Decision tree + red flags to keep main-agent context clean by routing exploration, long-running commands, MCP calls, reviews, and research to specialized subagents. Reference from your global CLAUDE.md. |
| [ack](./ack/) | Force agent to acknowledge intent before acting: parse request, rephrase in 1-3 bullets, ask permission, wait for explicit `y`, then execute. Tool whitelist, scope-drift rule, rationalization table. |
| [devloop](./devloop/) | Tight polish loop after a feature ships. Takes test-stories IDs, runs tests, fixes prioritized issues with a unanimous 3-seat expert panel (adversarial + root-cause + convention) and browser screenshot check, re-runs, repeats until clean. Fire-and-forget. |

## Installation

Clone a single skill into your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills
cp -r <skill-folder> ~/.claude/skills/
```

Or clone the entire repo:

```bash
git clone https://github.com/ssv445/claude-skills.git ~/.claude/skills
```

## Usage

Invoke any skill in Claude Code:

```
/<skill-name>
```

For example: `/humanizer`, `/write-blog`, `/plan-exit-review`
