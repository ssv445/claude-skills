# Write Blog Skill

A Claude Code skill for writing complete, well-researched, human-sounding technical blog posts with **audience-first approach**, **persuasion frameworks**, and **mandatory humanization**.

## Core Principles

1. **Audience is REQUIRED** - Generic content helps no one
2. **Persuasion through structure** - APP formula + Cialdini's principles
3. **ALWAYS humanize** - Never ship without humanization pass
4. **Human imagery only** - No sci-fi, no abstract AI art

## Frameworks Used

### APP Formula (Introductions)
From Brian Dean / Neil Patel:
- **Agree** - Acknowledge reader's pain/situation
- **Promise** - Clear benefit from reading
- **Preview** - Brief roadmap of what's coming

### Cialdini's 6 Principles (woven throughout)
- **Reciprocity** - Give value first (free tips, templates)
- **Authority** - Share experience, cite experts
- **Social Proof** - "Others have seen..."
- **Liking** - Be relatable, share struggles
- **Scarcity** - Timely info, recent data
- **Consistency** - Build on reader's beliefs

## Usage

```
/write-blog <topic> --audience <who> [--codebase <path>]
```

### Examples

```bash
/write-blog "Docker dev containers" --audience "backend devs new to containers"
/write-blog "Migrating from WordPress" --audience "agency devs with client sites" --codebase ~/www/project
```

## Workflow

```
Audience ──► Research ──► Outline ──► [APPROVAL 1] ──►
Draft ──► [APPROVAL 2] ──► HUMANIZE (mandatory) ──► Save
```

### Two Approval Gates
1. **Outline Approval** - Validate APP hook and structure
2. **Draft Approval** - Ensure content is right before humanizing

### Mandatory Humanization
Humanization is **NOT OPTIONAL**. Every post runs through humanizer before saving.

## Structure Tips (Neil Patel)

- **Subheadings** - Make content skimmable
- **Short paragraphs** - 5-6 lines max
- **End with question** - Drives engagement
- **Link out** - Cite sources, build authority
- **Give first** - Value before any ask

## Image Prompts

**REQUIRED: Human, realistic imagery**

```
✅ Developer at desk in natural lighting
✅ Hands on keyboard, real environment
✅ Team discussing around whiteboard
```

**BANNED: Sci-fi and abstract**

```
❌ Futuristic/cyber aesthetics
❌ Abstract geometric shapes
❌ Glowing/neon effects
❌ Robots or AI imagery
❌ Isometric illustrations
```

## Quality Controls

### Mandatory Humanization
Every post runs `/humanizer` or equivalent pass.

### Banned AI Words
delve, crucial, enhance, foster, landscape, tapestry, underscore, pivotal, showcase, vibrant, revolutionary, game-changing, seamless, leverage, synergy

### Banned Patterns
- Bold headers in lists
- "It's not just X, it's Y"
- Excessive em dashes
- "Additionally/Furthermore/Moreover"
- Generic positive conclusions

## Credits

- **[Joe Karlsson](https://www.joekarlsson.com/2025/10/building-a-claude-code-blog-skill-what-i-learned-systematizing-content-creation/)** - Approval gates, encode standards
- **[Neil Patel](https://neilpatel.com/blog/how-to-write-blog-post/)** - APP formula, structure tips
- **[Robert Cialdini](https://www.influenceatwork.com/)** - 6 Principles of Persuasion
