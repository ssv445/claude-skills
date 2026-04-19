# Step 1: UNDERSTAND — Read Issue & Analyze Codebase

**Max retries: 2**

## Worker agent (subagent_type: `general-purpose`)

```
Prompt: Read GitHub issue #<N>: `gh issue view <N>`
Read ALL existing comments: `gh issue view <N> --comments`
(Previous runs or humans may have left context.)

Understand requirements fully. Explore codebase for:
- Relevant files
- Existing patterns/conventions
- Related tests
- Dependencies/constraints

If BUG issue:
- DO NOT assume root cause from description
- Reproduce: run code, hit endpoint, check DB
- Investigate multiple angles (code, data, config, logs, schema)
- 2+ paths converge → state root cause
- Inconclusive → list possible causes with evidence for/against

Write to: .claude/nightshift/issue-<N>/01-understand.md

Structure:
## Issue Summary
<what needs done, own words>

## Relevant Files
<files with brief role description>

## Existing Patterns
<conventions from existing code>

## Investigation (for bugs)
### Reproduction
<exact commands, responses, errors>
### Root Cause Analysis
<findings from which angles, with evidence>
<multiple converge → high confidence>
<inconclusive → hypotheses with evidence>

## Constraints & Risks
<what could go wrong>

## Issue Classification (REQUIRED)
Type: <simple-bug | feature | complex-investigation | config-change>
Recommended pipeline: <step numbers, e.g. "1 → 4 → 5 → 6">
Reason: <1 sentence>

Pipeline rules:
- feature: 1 → 2 → 3 → 4 → 5 → 6
- complex-investigation: 1 → 2 → 3 → 4 → 5 → 6
- simple-bug: 1 → 4 → 5 → 6
- config-change: 1 → 2 → 5 → 6
- When in doubt → full pipeline

## UI Impact (REQUIRED)
Has UI changes: <yes | no>
Affected pages: <local URLs, e.g. http://ecomitram.localhost:1355/feed>
Mobile-critical: <yes | no>
Reason: <what visual changes need verification>

## Suggested Approach (high-level)
<1-2 sentence direction, NOT full plan>

At the very end of your response, output:
ORCHESTRATOR_SUMMARY: <1 sentence, max 20 words, describing outcome>
```

**After worker finishes, offload issue commenting to subagent (Rule 3).**

## Review gate — 3 agents in parallel (`model: "opus"`)

| Reviewer | subagent_type | Focus |
|----------|--------------|-------|
| Feasibility | `architecture` | Understanding correct? All files found? Missing constraints? |
| Scope | `code-standards` | Scope appropriate? Conventions correct? |
| Risk | `security` | Security implications? Data model concerns? |

Each reads `.claude/nightshift/issue-<N>/01-understand.md` + original issue.

**For bugs, reviewers MUST check:**
- Bug actually reproduced with evidence? (not assumed)
- Root cause has multi-angle investigation?
- Alternative explanations considered?
- REJECT if single investigation path without confirmation

Each outputs `VERDICT` line (see Agent Output Formats).

**2/3 approve → proceed, but ALL critical issues from ANY reviewer addressed (see Review Gate Protocol in run.md).** Rejected → ralph retry. **Offload review comment to subagent.**
