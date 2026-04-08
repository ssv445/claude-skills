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
| [daily-operator](./daily-operator/) | Automated daily pipeline for site operations: GSC analysis, content, affiliates, SEO. |
| [nightshift](./nightshift/) | Autonomous overnight GitHub issue processing. 7-step TDD pipeline with review gates, expert panels, and thin orchestrator pattern. |
| [quality-loop](./quality-loop/) | Continuous quality improvement with competing dual-perspective investigators, 5 review gates, and anti-loop detection. |
| [commit](./commit/) | Commit staged changes following repo conventions. Simple and focused. |
| [brainstorm](./brainstorm/) | One-question-at-a-time ideation to build detailed specs. Inspired by [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent. |
| [ship](./ship/) | Ship a task end-to-end: GitHub issue, branch, implement, test, PR. |
| [handoff-context](./handoff-context/) | Compress conversation state to `./.tmp/context-<timestamp>.md` in caveman format and copy a kickoff line to clipboard, so work resumes cleanly after `/clear`. |
| [caveman-distillate](./caveman-distillate/) | Ultra-compressed communication mode (~65% fewer tokens). Based on [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) by Julius Brussee. |
| [run-detached](./run-detached/) | Run any slash command in a fresh `claude -p` subprocess inside a detached tmux session. Escapes nested-subagent limits; sessions appear in `tmux ls` and claude-wormhole. |

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
