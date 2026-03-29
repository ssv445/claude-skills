# taste-extract

Mines your Claude Code history, memory files, and CLAUDE.md files to build a taste profile — your accumulated product judgment codified as reviewable principles.

## Usage

```
/taste-extract          # extract from all sources
/taste-extract --scope global   # only global CLAUDE.md + memory
/taste-extract --scope project  # only current project
/taste-extract --deep           # process ALL conversation history (slow)
```

## Output

Creates/updates files in `~/.claude/taste/`:
- `architecture.md` — system design, complexity, abstractions
- `product.md` — feature completeness, shipping decisions
- `ux.md` — user empathy, target audience, usability
- `code.md` — code style, error handling, patterns
- `process.md` — git workflow, PRs, deployment
- `communication.md` — error messages, UI copy, naming

## How it works

1. Reads feedback memory files (already curated taste)
2. Reads CLAUDE.md files (codified principles)
3. Mines conversation JSONL history for corrections, approvals, rejections
4. Clusters into dimensions, deduplicates, scores confidence
5. Writes structured taste files

## Integration

The `eval-criteria` skill reads taste files to generate taste-informed evaluation criteria. The `eval-verifier` agent checks implementations against taste principles.
