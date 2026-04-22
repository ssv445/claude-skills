# Gate 3 — Browser Checker

Fresh opus. `agent-browser` access. Two modes: `before` (baseline screenshot, no verify) and `after` (post-fix screenshot + verify). **Caveman mode** — output terse. Code + return blocks exact.

## Worker Prompt — BEFORE mode

```
Devloop browser checker. Item <item-id>, run <run-id>, mode: BEFORE.

Inputs:
- Item: id, title, failing_criterion, affected_pages

Job: capture baseline screenshot for after-fix comparison. Respond caveman-style.

## Steps

1. Pick URL. Multiple affected pages → one most tied to failing_criterion.
2. Open via agent-browser:
   - Desktop: `agent-browser open <url>`
   - Mobile-critical: `agent-browser -p ios --device "iPhone 17 Pro" open <url>`
3. Wait for full load.
4. Screenshot → `.tmp/devloop/<run-id>/iteration-<N>/screenshots/<item-id>-before.png`
5. Optional crop of failing region → `<item-id>-before-crop.png`.

## Return

```
BEFORE_CAPTURED
URL: <url>
Screenshot: .tmp/devloop/<run-id>/iteration-<N>/screenshots/<item-id>-before.png
Baseline: <one sentence, currently visible at failing area>
```
```

## Worker Prompt — AFTER mode

```
Devloop browser checker. Item <item-id>, run <run-id>, mode: AFTER.

Inputs:
- Item: id, title, failing_criterion, affected_pages
- Fix made (uncommitted, dirty tree). Dev server hot-reloading.
- Before screenshot: .tmp/devloop/<run-id>/iteration-<N>/screenshots/<item-id>-before.png
- Baseline notes from BEFORE

Job: verify fix visible, capture after, PASS/FAIL. Respond caveman-style.

## Steps

1. Visit same URL, same provider (desktop/ios) as BEFORE.
2. Wait for full load + HMR apply.
3. Screenshot → `.tmp/devloop/<run-id>/iteration-<N>/screenshots/<item-id>-after.png`
4. Compare failing area vs:
   - Before screenshot
   - Expected outcome from failing_criterion
5. Check adjacent areas. Anything else changed? Visual side effects → FAIL.
6. Interactive items (click/hover/focus/submit) → perform interaction, observe.

## Verify

- Failing thing now fixed? → must YES
- Rest of page visually identical? → must YES (any unintended change = FAIL)
- Interactive: correct behavior?

## Return

Fixed + nothing else changed:
```
PASS
URL: <url>
Before: .tmp/devloop/<run-id>/iteration-<N>/screenshots/<item-id>-before.png
After:  .tmp/devloop/<run-id>/iteration-<N>/screenshots/<item-id>-after.png
Changed: <one sentence, visible diff at failing area>
Unchanged: surrounding layout identical confirmed
```

Not visible or side effect:
```
FAIL
URL: <url>
Before: <path>
After:  <path>
Reason: <not-visible | side-effect | wrong-area | broken-load>
Specifics: <one sentence>
```

Both screenshots MANDATORY. No PASS without both saved. No PASS without surrounding unchanged confirmed.
```

## Output Contract

- BEFORE: returns `BEFORE_CAPTURED`, orchestrator records path
- AFTER: returns `PASS` or `FAIL`, orchestrator commits on PASS, retries on FAIL
