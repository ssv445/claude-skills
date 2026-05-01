---
name: nightshift
description: "Autonomous overnight GitHub issue processing pipeline. Multi-step TDD pipeline (7 steps) with 3-agent review gates, expert panels for dilemmas, and a thin orchestrator pattern. Two entry points: nightshift:run (process issues), nightshift:review (pre-flight check). Use --supervised for interactive checkpoints. Run it and go to sleep."
---

# Nightshift

Multi-file skill with two invocable entry points and a shared support library.

## Entry points

- **`/nightshift:run`** — main pipeline. Processes GitHub issues through 7 steps (UNDERSTAND → PLAN → TEST → CODE → VERIFY → QA → SHIP). Each step reviewed by 3 agents; 2/3 majority to proceed; expert panel resolves dilemmas. All work merges into a single `nightshift/<date>-<slug>` branch. See [run.md](./run.md).
- **`/nightshift:review`** — pre-flight review of GitHub issues *before* running the pipeline. Checks each issue has story references, acceptance criteria, dependencies, and UI descriptions. Auto-invokes brainstorming to fill gaps. See [review.md](./review.md).

## Support files

- `prompts/` — per-step prompts (one file per pipeline step)
- `sections/` — shared sub-modules (orchestrator pattern, safety rails, retry logic, gates, branch strategy, expert panel, rate limits, cardinal rules)
- `templates/` — output templates (e.g., morning-report)

## How to use

Run `/nightshift:review <issue-numbers>` first to validate issue quality. Then run `/nightshift:run <issue-numbers>` (or label issues `nightshift` and run `/nightshift:run` with no args) before going to bed. Wake up to a morning report.

This file exists so the [`skills`](https://github.com/vercel-labs/skills) CLI can discover and install the skill (it expects a top-level `SKILL.md` with frontmatter). The actual logic lives in `run.md` and `review.md`.
