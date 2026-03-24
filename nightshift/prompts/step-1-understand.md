# Step 1: UNDERSTAND — Read Issue & Analyze Codebase

**Max retries: 2**

## Worker agent (subagent_type: `general-purpose`)

```
Prompt: Read GitHub issue #<N> using `gh issue view <N>`.
Also read ALL existing comments on the issue: `gh issue view <N> --comments`
(Previous nightshift runs or humans may have left context.)

Understand the requirements fully.
Then explore the codebase to find:
- Which files are relevant to this issue
- Existing patterns and conventions in those files
- Related tests that already exist
- Any dependencies or constraints

If this is a BUG issue:
- DO NOT assume the root cause from the issue description
- Reproduce the bug: run the relevant code, hit the endpoint, check the DB
- Investigate from multiple angles (code, data, config, logs, schema)
- Only when 2+ investigation paths converge on the same cause → state the root cause
- If investigation is inconclusive → say so clearly, list possible causes with evidence for/against each

Write your findings to: .claude/nightshift/issue-<N>/01-understand.md

Structure:
## Issue Summary
<what needs to be done, in your own words>

## Relevant Files
<list of files with brief description of their role>

## Existing Patterns
<conventions to follow based on existing code>

## Investigation (for bugs)
### Reproduction
<how you reproduced the bug — exact commands, responses, errors>
### Root Cause Analysis
<what you found, from which angles, with evidence>
<if multiple angles converge → high confidence root cause>
<if inconclusive → list hypotheses with evidence for/against>

## Constraints & Risks
<anything that could go wrong or needs careful handling>

## Issue Classification (REQUIRED — determines which pipeline steps run)
Type: <simple-bug | feature | complex-investigation | config-change>
Recommended pipeline: <list step numbers, e.g. "1 → 4 → 5 → 6" for simple-bug>
Reason: <1 sentence justification>

Pipeline rules:
- feature: 1 → 2 → 3 → 4 → 5 → 6 (full pipeline)
- complex-investigation: 1 → 2 → 3 → 4 → 5 → 6 (full pipeline)
- simple-bug: 1 → 4 → 5 → 6 (skip PLAN and TEST)
- config-change: 1 → 2 → 5 → 6 (skip TEST and CODE)
- When in doubt → full pipeline

## UI Impact (REQUIRED — determines whether browser testing runs in Step 5)
Has UI changes: <yes | no>
Affected pages: <list of local URLs to visually verify, e.g. http://ecomitram.localhost:1355/feed>
Mobile-critical: <yes | no>
Reason: <what visual changes need verification>

## Suggested Approach (high-level)
<1-2 sentence direction, NOT a full plan>

At the very end of your response, output:
ORCHESTRATOR_SUMMARY: <1 sentence, max 20 words, describing outcome>
```

**After the worker finishes, offload issue commenting to a subagent (Rule 3).**

## Review gate — 3 agents in parallel (`model: "opus"`)

| Reviewer | subagent_type | Focus |
|----------|--------------|-------|
| Feasibility | `architecture` | Is the understanding correct? All relevant files identified? Missing constraints? |
| Scope | `code-standards` | Is the scope appropriate? Conventions correctly identified? |
| Risk | `security` | Security implications missed? Data model concerns? |

Each reads `.claude/nightshift/issue-<N>/01-understand.md` and the original issue.
Each outputs a `VERDICT` line (see Agent Output Formats).

**For bug issues, reviewers MUST also check:**
- Was the bug actually reproduced with evidence? (not assumed)
- Does the root cause analysis have multi-angle investigation?
- Are there alternative explanations that weren't considered?
- REJECT if the analysis relies on a single investigation path without confirmation

Each outputs a `VERDICT` line (see Agent Output Formats).

**2/3 approve → proceed, but ALL critical issues from ANY reviewer must be addressed (see Review Gate Protocol in run.md).** Rejected → ralph retry with feedback. **Offload review comment to subagent.**
