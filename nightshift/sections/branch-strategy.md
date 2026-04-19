# Nightshift Branch Strategy

All issues merge into single parent branch per night. Main NEVER touched.

## Setup (once per run)

```bash
DATE=$(date +%Y-%m-%d)
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')

FIRST_ISSUE=$(echo "$ISSUES" | head -1)
SLUG=$(gh issue view $FIRST_ISSUE --json title --jq '.title' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | head -c 30 | sed 's/-$//')

NIGHTSHIFT_BRANCH="nightshift/${DATE}-${SLUG}"

git checkout $DEFAULT_BRANCH && git pull
git checkout -b $NIGHTSHIFT_BRANCH
git push -u origin $NIGHTSHIFT_BRANCH
```

## Per-issue flow

```
nightshift/2026-03-03-user-avatar-upload   <- parent (human merges to main)
  |-- feat/50-user-avatar                  <- issue branch, PR targets parent
  |-- feat/51-feed-pagination
  +-- feat/52-hashtag-filter
```

Each issue branch:
1. Created FROM `$NIGHTSHIFT_BRANCH`
2. PR targets `$NIGHTSHIFT_BRANCH`
3. Merge after checks pass:
   ```bash
   gh pr merge <PR_NUMBER> --squash --delete-branch
   ```
4. Before next issue:
   ```bash
   git checkout $NIGHTSHIFT_BRANCH && git pull
   ```

## End of nightshift

Final PR: `$NIGHTSHIFT_BRANCH` → `main` with morning report as body.

```bash
gh pr create \
  --base $DEFAULT_BRANCH \
  --head $NIGHTSHIFT_BRANCH \
  --title "nightshift: $(date +%Y-%m-%d) — <N> issues shipped" \
  --body "$(cat .claude/nightshift/morning-report.md)"
```
