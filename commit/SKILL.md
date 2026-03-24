---
description: Commit staged changes only (if available)
---

# Commit Staged Changes

You are tasked with committing ONLY staged changes in the git repository.

## Instructions

1. **Check for staged changes**:
   - Run `git diff --cached --stat` to see if there are any staged changes
   - If there are NO staged changes, inform the user and do NOT proceed with commit

2. **Review staged changes**:
   - Run `git diff --cached` to see the actual staged changes
   - Run `git log -5 --oneline` to see recent commit message style

3. **Create commit message**:
   - Analyze the staged changes
   - Draft a concise, descriptive commit message that follows the repository's style
   - Focus on "why" not just "what"
   - Keep it 1-2 sentences

4. **Commit the staged changes**:
   - Use the commit message format:

   ```bash
   git commit -m "$(cat <<'EOF'
   Your commit message here.
   EOF
   )"
   ```

5. **Verify the commit**:
   - Run `git log -1` to show the created commit
   - Run `git status` to confirm clean state

## Important Rules

- **NEVER stage new files** - only commit what is already staged
- **NEVER add files** with `git add` - work with existing staged changes only
- **NEVER push** to remote repository
- **DO NOT create commit if no staged changes exist**
- **DO NOT use git hooks flags** like `--no-verify` unless explicitly requested
- **DO NOT amend commits** unless explicitly requested

## Example Flow

If staged changes exist:
1. Show what's staged
2. Draft commit message
3. Create commit with attribution
4. Confirm success

If no staged changes:
- Simply inform: "No staged changes found. Nothing to commit."
