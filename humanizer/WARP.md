# WARP.md

Guidance for WARP (warp.dev) when working in this repo.

## What this repo is
Claude Code skill implemented as Markdown. Runtime artifact is `SKILL.md` (YAML frontmatter + prompt). `README.md` is for humans.

## Key files
- `SKILL.md` — Skill definition. YAML frontmatter (`name`, `version`, `description`, `allowed-tools`) + canonical pattern list with examples. Source of truth.
- `README.md` — Install/usage instructions, summarized patterns table, version history. Keep consistent with SKILL.md.

## Commands
```bash
# Install (clone into skills dir)
mkdir -p ~/.claude/skills && git clone https://github.com/blader/humanizer.git ~/.claude/skills/humanizer

# Manual install
mkdir -p ~/.claude/skills/humanizer && cp SKILL.md ~/.claude/skills/humanizer/
```

## Usage
`/humanizer` then paste text.

## Making changes
- `version:` in SKILL.md frontmatter and README "Version History" must stay in sync.
- Preserve valid YAML frontmatter formatting.
- Keep pattern numbering stable (README table references same numbers).
- Non-obvious prompt fixes → add note to README version history explaining what/why.
