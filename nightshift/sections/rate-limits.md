# Rate Limit Management

## Between Issues

Offload to **subagent** (`model: "opus"`):

```
Check API usage limits via Chrome browser automation:
1. Navigate to https://claude.ai/settings/usage
2. Read page content using browser_snapshot or read_page
3. Find usage indicator
4. Return EXACTLY: USAGE: <number>%
ORCHESTRATOR_SUMMARY: Usage at <number>%
```

**Thresholds:**

| Usage | Action |
|-------|--------|
| < 70% | Proceed |
| 70-85% | Wait 5 min, post cooldown comment |
| 85-95% | Wait 15 min, post cooldown comment |
| > 95% | Wait 30 min, re-check. Still >95% → graceful stop |

## Between Heavy Steps (3, 4, 5)

Skip mid-issue checks by default. Only check if last between-issues check >85%. If so, quick check — only pause if >90%.

## Graceful Stop

When rate limits force stop:
1. Update state.json — current issue stays `in_progress` with accurate `currentStep` and `lastResult`
2. Write partial morning report
3. Post on remaining issues: `"Nightshift paused — rate limits reached. Resume: /nightshift:run <issues>"`
4. Post on current issue: `"Nightshift paused mid-issue at step <X> — rate limits. State saved for resume."`
