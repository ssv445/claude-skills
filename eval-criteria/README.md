# eval-criteria

Generates task-specific evaluation criteria from implementation plans. Instead of generic review checklists, produces criteria derived from what the plan actually builds — functional pass/fail checks, code quality scores scoped to the tech involved, UX/craft scores when UI work is present, completeness checks across personas, and taste-informed quality criteria from your codified product judgment.

## When to Use

- After `writing-plans` skill completes (recommended integration point)
- Manually on any plan file: `/eval-criteria docs/superpowers/plans/2026-03-25-feature.md`
- Before handing off to implementation agents (sprint contract pattern)

## Example

```
/eval-criteria docs/superpowers/plans/2026-03-25-widget-api.md
```

Produces: `docs/superpowers/evals/2026-03-25-widget-api-eval.md`

## Output Dimensions

| Dimension | Scoring | When Included |
|-----------|---------|---------------|
| Functional | Pass/fail | Always — one per plan requirement |
| Code Quality | 1-5 scored | Always — auto-selected by tech stack |
| UX/Craft | 1-5 scored | Only when UI work detected |
| Completeness | Pass/fail | Always — per affected persona |
| Taste | 1-5 scored | When relevant taste principles exist |

Complexity auto-scales: Light (5-8 criteria), Standard (10-18), Heavy (20-30).

## Taste Integration

Reads `~/.claude/taste/` files to generate taste-informed criteria. HIGH confidence principles are applied automatically; MEDIUM are advisory. Run `/taste-extract` to update taste from conversation history.

## Integration

After implementation, dispatch the `eval-verifier` agent to verify against the eval file. It runs functional checks, dispatches review subagents with targeted criteria, and produces a scored verdict: Ready | Needs Work | Major Issues.
