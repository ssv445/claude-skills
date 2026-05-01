---
name: commit
description: Commit staged changes only (if available). Reviews the diff, matches the repo's commit-message style from recent log, and writes a concise message — never adds untracked files, never amends.
---

# Commit Staged Changes

## Steps

1. `git diff --cached --stat` — if nothing staged, tell user & stop
2. `git diff --cached` + `git log -5 --oneline` — review changes & match style
3. Draft commit msg: 1-2 sentences, "why" > "what", match repo style
4. Commit:
   ```bash
   git commit -m "$(cat <<'EOF'
   Your commit message here.
   EOF
   )"
   ```
5. Verify: `git log -1` + `git status`

## Rules

- NEVER `git add` — only commit what's already staged
- NEVER push to remote
- NEVER `--no-verify` or `--amend` unless user asks
