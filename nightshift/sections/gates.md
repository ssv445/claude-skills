# Gates & Recovery

## Brainstorming Gate (Ambiguous Issues)

When Step 1 reveals **ambiguous requirements** — unclear scope, multiple interpretations, missing ACs — do NOT proceed. Invoke brainstorming gate.

### Trigger

Step 1 worker flags in `01-understand.md`:
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

### Flow

1. **Post questions as issue comment** — tag with `needs-clarification` label
2. **Convene expert panel** — 3 experts get issue + `01-understand.md` + ambiguity flag
   - Each proposes interpretation and approach
   - 2/3 majority → adopt that interpretation
   - 3-way split → post all 3 as comment, mark BLOCKED for human input
3. **Panel resolves** → append "## Resolved Ambiguity" to `01-understand.md`, re-run Step 1 review gate
4. **Panel can't resolve** → BLOCKED: "Ambiguous requirements — needs human clarification", move to next issue

### Skip conditions

Skip if: clear acceptance criteria, worker says `Status: CLEAR`, `simple-bug` with obvious root cause.

---

## Interactive Checkpoint (--supervised)

When run with `--supervised`, pause after Step 2 (PLAN) for human feedback.

### Flow

1. Step 2 passes review → post plan summary as issue comment
2. Add label `awaiting-feedback`
3. **PAUSE** — do not proceed
4. Post: `"**Nightshift PAUSED** — Plan ready for review. Comment 'lgtm' or 'proceed' to approve. Provide feedback to adjust."`
5. **Poll** every 5 min (up to 1 hour):
   ```bash
   gh issue view <N> --comments --json comments --jq '.comments[-1].body'
   ```
6. `lgtm`/`proceed`/`approved` → remove label, continue to Step 3
7. Feedback → ralph retry Step 2 with feedback
8. 1 hour no response → continue autonomously (log timeout)

**Default (no flag):** fully autonomous, no pauses.

### State tracking
```json
"supervisedMode": true,
"checkpoint": { "step": 2, "waitingSince": "ISO timestamp", "resolved": false }
```

---

## Resume Detection & Recovery

On startup, check `.claude/nightshift/state.json`.

### Fresh Run (no state.json)
Normal setup — create branch, initialize state.

### Resume Run (state.json exists)

Offload validation to **subagent** (`model: "opus"`):
```
Read .claude/nightshift/state.json and validate resume state.
Check:
- Nightshift branch exists: `git branch --list <branch>` and `git ls-remote --heads origin <branch>`
- Issue branches exist (for in_progress issues)
- Artifact files exist for completed steps

Return EXACTLY:
RESUME_PLAN:
- Issue #50: SKIP (completed)
- Issue #51: RESUME at step 4, attempt 2/7, lastResult=review_rejected
- Issue #52: START fresh
NIGHTSHIFT_BRANCH: nightshift/2026-03-03-user-avatar (exists: yes/no)
ORCHESTRATOR_SUMMARY: Resume validated — 1 skip, 1 resume at step 4, 1 fresh
```

### Resume Logic

| `lastResult` | Action |
|--------------|--------|
| `"passed"` | Skip to next step |
| `"worker_done_pending_review"` | Skip worker, run review gate only |
| `"review_rejected"` | Ralph retry (preserve attempt count) |
| `null` | Run step from scratch |

- **"completed"** → skip
- **"blocked"** → skip

### Branch Recovery

- State has branch + exists → checkout and reuse
- State has branch + NOT in git → create fresh from default, warn via comment
- No state → create fresh

### Resume Comment
```bash
gh issue comment <N> --body "**Nightshift RESUMED** at step <X>, attempt <Y>/<Z>
Previous session state recovered. Continuing from: <lastResult>"
```

**Preserve attempt counts** — never reset retries on resume.
