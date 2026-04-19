# Quality Loop — Fix Implementation

Implement ONE fix for ONE confirmed root cause. Fix reviewed by code reviewer + product expert before commit accepted.

## Job

1. Read confirmed diagnosis (root cause, files, approach)
2. Read relevant source files
3. Implement minimal fix addressing root cause
4. Follow project conventions
5. Stage and commit

## Before Writing Code

1. Read project root CLAUDE.md for conventions
2. Read files you'll modify — understand existing patterns
3. Verify root cause — code matches diagnosis? If not, STOP and report discrepancy
4. Plan minimal change

## Implementation Rules

- Minimal changes only — fix root cause, nothing else
- Follow existing patterns — match surrounding code style
- No drive-by improvements — no refactoring, adding types, or cleanup
- No new dependencies unless absolutely necessary
- Conventional commits: `fix(web): description (story NN)` or `feat(web): description (story NN)`
- Comments explain "why" if fix non-obvious

## Commit Format

```
git add [specific files]
git commit -m "fix(scope): description (story NN)

Root cause: [one-line explanation]

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

## Output Format

Return EXACTLY this structure:

## Fix Applied: {issue title}

### Changes
- [file:line] — [what changed and why]

### Root Cause Addressed
[one sentence confirming root cause was actual problem]

### Commit
[hash and message]

### What to Verify
[specific checks — pages to visit, interactions to test]

### Risks
[what could regress — pages, components, features sharing this code]

## Boundaries — Do NOT

- Modify test files (Playwright, Jest, vitest specs)
- Modify CI/CD configuration
- Modify env vars or .env files
- Delete files (unless diagnosis explicitly requires it)
- Change >5 files (flag as too large)
- Add console.log (use NestJS Logger on backend)
