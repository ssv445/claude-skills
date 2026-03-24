# Rate Limit Management

## Between Issues (after complete/block, before next)

Offload to a **subagent** (`model: "opus"`):

```
Check API usage limits. Use Chrome browser automation:
1. Navigate to https://claude.ai/settings/usage
2. Read the page content using browser_snapshot or read_page
3. Find the usage indicator (percentage, bar, or remaining messages)
4. Return EXACTLY: USAGE: <number>% (or USAGE: UNKNOWN if can't determine)
ORCHESTRATOR_SUMMARY: Usage at <number>%
```

**Decision thresholds (orchestrator logic):**

| Usage | Action |
|-------|--------|
| < 70% | Proceed to next issue |
| 70-85% | Wait 5 min, post cooldown comment on next issue |
| 85-95% | Wait 15 min, post cooldown comment |
| > 95% | Wait 30 min, re-check. Still >95% → graceful stop |

## Between Heavy Steps (after steps 3, 4, 5)

Skip mid-issue rate checks by default — they waste tokens and leave work half-done. Only check if the previous between-issues check returned >85%. If so, quick check with same subagent, only pause if >90%.

## Graceful Stop

When rate limits force a stop:
1. Update `.claude/nightshift/state.json` — current issue stays `in_progress` with accurate `currentStep` and `lastResult`
2. Write partial morning report with what was completed so far
3. Post on remaining unstarted issues: `"Nightshift paused — rate limits reached. Resume: /nightshift:run <issues>"`
4. Post on current issue: `"Nightshift paused mid-issue at step <X> — rate limits. State saved for resume."`
