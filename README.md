# Claude Code Skills

Custom skills for [Claude Code](https://claude.ai/code).

## Skills

| Skill | Description |
|-------|-------------|
| [humanizer](./humanizer/) | Remove AI-generated writing patterns from text. Based on Wikipedia's "Signs of AI writing" guide. |
| [write-blog](./write-blog/) | Blog post creation with audience-first approach, APP formula, Cialdini's persuasion principles, and mandatory humanization. |
| [xterm-js](./xterm-js/) | Best practices for building terminal apps with xterm.js, React, and WebSockets. |
| [ios-safari-quirks](./ios-safari-quirks/) | 55+ documented iOS Safari JavaScript quirks with fixes. |
| [plan-exit-review](./plan-exit-review/) | Thorough plan review before implementation with scope challenge and interactive walkthrough. |
| [gh-discussion](./gh-discussion/) | Create and manage GitHub Discussions via GraphQL API. |
| [portless](./portless/) | Named local dev server URLs (e.g. `http://myapp.localhost` instead of `http://localhost:3000`). |
| [test-stories](./test-stories/) | AI-driven user story testing with browser automation subagents. |
| [daily-operator](./daily-operator/) | Automated daily pipeline for site operations: GSC analysis, content, affiliates, SEO. |

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
