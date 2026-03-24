# Gates & Recovery

## Brainstorming Gate (for Ambiguous Issues)

When Step 1 (UNDERSTAND) reveals **ambiguous requirements** — unclear scope, multiple valid interpretations, or missing acceptance criteria — do NOT proceed to Step 2. Instead, invoke a brainstorming gate.

### When to trigger

The Step 1 worker flags ambiguity by including in `01-understand.md`:

```
## Ambiguity Flag
Status: AMBIGUOUS
Unclear areas:
- <area 1>
- <area 2>
Questions for clarification:
- <question 1>
- <question 2>
```

### Brainstorming gate flow

1. **Post questions as issue comment** — list the unclear areas and questions. Tag with `needs-clarification` label.
2. **Convene expert panel** — 3 experts discuss the ambiguity and propose approaches:
   - Each expert gets the issue + `01-understand.md` + the ambiguity flag
   - Each proposes an interpretation and approach
   - 2/3 majority → adopt that interpretation
   - 3-way split → post all 3 interpretations as issue comment, mark BLOCKED for human input
3. **If panel resolves it** — write the agreed interpretation to `01-understand.md` (append a "## Resolved Ambiguity" section), re-run Step 1 review gate
4. **If panel can't resolve** — mark issue BLOCKED with `"Ambiguous requirements — needs human clarification"` and move to next issue

### Skip conditions

Do NOT brainstorm if:
- Issue has clear acceptance criteria
- Step 1 worker says `Status: CLEAR`
- Issue is a `simple-bug` type (root cause is obvious)

---

## Interactive Checkpoint (Optional — Supervised Mode)

When nightshift is run with the `--supervised` flag (e.g., `/nightshift:run --supervised #50 #51`), pause after Step 2 (PLAN) for human feedback before proceeding to code.

### How it works

1. After Step 2 passes review → post the plan summary as an issue comment
2. Add label `awaiting-feedback` to the issue
3. **PAUSE** — do not proceed to Step 3
4. Post comment: `"**Nightshift PAUSED** — Plan ready for review. Approve by commenting 'lgtm' or 'proceed'. Provide feedback to adjust."`
5. **Poll for response** — check issue comments every 5 minutes (up to 1 hour):
   ```bash
   gh issue view <N> --comments --json comments --jq '.comments[-1].body'
   ```
6. On `lgtm` / `proceed` / `approved` → remove `awaiting-feedback` label, continue to Step 3
7. On feedback → feed the comment to a ralph retry of Step 2 (re-plan with feedback)
8. After 1 hour with no response → continue autonomously (log that timeout occurred)

### Default behavior (no flag)

Without `--supervised`, nightshift runs fully autonomous — no pauses, no polling. This is the default.

### State tracking

```json
"supervisedMode": true,
"checkpoint": { "step": 2, "waitingSince": "ISO timestamp", "resolved": false }
```

---

## Resume Detection & Recovery

On startup, check if `.claude/nightshift/state.json` exists.

### Fresh Run (no state.json)

Proceed with normal setup — create nightshift branch, initialize state.

### Resume Run (state.json exists)

Offload validation to a **subagent** (`model: "opus"`):

```
Read .claude/nightshift/state.json and validate resume state.
Check:
- Nightshift branch from state exists: `git branch --list <branch>` and `git ls-remote --heads origin <branch>`
- Each issue branch exists (for in_progress issues)
- Artifact files exist for completed steps (.claude/nightshift/issue-<N>/)

Return EXACTLY:
RESUME_PLAN:
- Issue #50: SKIP (completed)
- Issue #51: RESUME at step 4, attempt 2/7, lastResult=review_rejected
- Issue #52: START fresh
NIGHTSHIFT_BRANCH: nightshift/2026-03-03-user-avatar (exists: yes/no)
ORCHESTRATOR_SUMMARY: Resume validated — 1 skip, 1 resume at step 4, 1 fresh
```

### Resume Logic (orchestrator applies the plan)

For each issue in input:
- **"completed"** → skip, log "already done"
- **"blocked"** → skip, log "previously blocked"
- **"in_progress"** → resume from `currentStep` using `lastResult`:

| `lastResult` | Action |
|--------------|--------|
| `"passed"` | Skip to next step |
| `"worker_done_pending_review"` | Skip worker, run review gate only |
| `"review_rejected"` | Run ralph retry (preserve attempt count) |
| `null` | Run step from scratch |

### Branch Recovery

- State has branch + exists in git → `git checkout <branch>` and reuse
- State has branch + NOT in git → create fresh from latest default branch, warn via issue comment
- No state → create fresh (normal flow)

### Resume Comment

Post on the issue being resumed:
```bash
gh issue comment <N> --body "**Nightshift RESUMED** at step <X>, attempt <Y>/<Z>
Previous session state recovered. Continuing from: <lastResult>"
```

**Preserve attempt counts** — never reset retries on resume. The whole point is continuity.
