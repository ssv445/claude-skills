# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A collection of custom Claude Code skills — prompt-based tools invoked via `/<skill-name>` in Claude Code. Each skill is a standalone directory containing a `SKILL.md` (or equivalent `.md` entry point) with YAML frontmatter and instructions.

## Repo Structure

Each top-level directory is a skill. The entry point is always a markdown file:
- **Simple skills**: Single `SKILL.md` (e.g., `commit/`, `brainstorm/`, `humanizer/`)
- **Complex skills**: Main entry `.md` + supporting files in `sections/`, `prompts/`, `templates/` subdirs (e.g., `nightshift/run.md` with `sections/*.md` and `prompts/*.md`)
- **Multi-agent skills**: Include `AGENT-*.md` files for subagent definitions (e.g., `quality-loop/AGENT-TRIAGE.md`, `AGENT-FIX.md`)

## Skill File Format

Every skill entry point uses this structure:
```markdown
---
name: skill-name           # optional
description: "..."         # required — tells Claude Code when to invoke
version: x.y.z             # optional
allowed-tools:             # optional — restricts tool access
  - Read
  - Write
  - Bash
---

# Skill Title

Instructions follow...
```

- `$ARGUMENTS` in skill body = placeholder for user input after the slash command
- `@path/to/file.md` references are relative includes (e.g., `@sections/gates.md`)
- `description` field is what Claude Code matches against to decide skill relevance

## Key Skills

| Skill | Type | Purpose |
|-------|------|---------|
| `nightshift` | Multi-step pipeline | Autonomous overnight issue processing (7 TDD steps, 3-agent review gates) |
| `quality-loop` | Multi-agent loop | Continuous quality improvement with triage/diagnose/fix/gate agents |
| `ship` | End-to-end workflow | Issue → branch → implement → test → PR |
| `humanizer` | Text transform | Remove AI writing patterns |
| `write-blog` | Content creation | Research → outline → draft → humanize → publish |
| `commit` | Git operation | Commit staged changes following repo conventions |
| `brainstorm` | Interactive | One-question-at-a-time spec building |
| `test-stories` | Testing | AI-driven user story acceptance testing |

## Conventions

- Skills reference each other via `@` paths (e.g., `@sections/orchestrator.md`) — these are relative to the skill's directory
- Agent definitions (`AGENT-*.md`) define subagent prompts used by orchestrator skills
- No build system, no dependencies, no tests — this is a pure markdown/prompt repo
- Install by copying skill directories to `~/.claude/skills/`
