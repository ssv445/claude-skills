# Nightshift Branch Strategy

All issues merge into a single parent branch per night run. Main is NEVER touched.

## Setup (once per nightshift run)

```bash
DATE=$(date +%Y-%m-%d)
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')

# Derive a slug from the first issue title for a descriptive branch name
FIRST_ISSUE=$(echo "$ISSUES" | head -1)
SLUG=$(gh issue view $FIRST_ISSUE --json title --jq '.title' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | head -c 30 | sed 's/-$//')

# Branch name: nightshift/{date}-{slug}
NIGHTSHIFT_BRANCH="nightshift/${DATE}-${SLUG}"

# Create the nightshift parent branch from latest main
git checkout $DEFAULT_BRANCH && git pull
git checkout -b $NIGHTSHIFT_BRANCH
git push -u origin $NIGHTSHIFT_BRANCH
```

**Examples:**
- Single issue #50 "User Avatar Upload": `nightshift/2026-03-03-user-avatar-upload`
- Multiple issues starting with #50: `nightshift/2026-03-03-user-avatar-upload` (uses first issue's title)

## Per-issue flow

```
nightshift/2026-03-03-user-avatar-upload   <- parent branch (human merges to main)
  |-- feat/50-user-avatar                  <- issue branch, PR targets parent
  |-- feat/51-feed-pagination              <- issue branch, PR targets parent
  +-- feat/52-hashtag-filter               <- issue branch, PR targets parent
```

Each issue branch:
1. Created FROM `$NIGHTSHIFT_BRANCH` (not from main)
2. PR targets `$NIGHTSHIFT_BRANCH` (not main)
3. After PR is created and all checks pass, **merge the PR** using:
   ```bash
   gh pr merge <PR_NUMBER> --squash --delete-branch
   ```
4. Before starting next issue, pull latest nightshift branch:
   ```bash
   git checkout $NIGHTSHIFT_BRANCH && git pull
   ```

This way each subsequent issue builds on top of previous issues' code.

## End of nightshift

Create one final PR: `$NIGHTSHIFT_BRANCH` -> `main` with the morning report as the body. Human reviews and merges this single PR.

```bash
gh pr create \
  --base $DEFAULT_BRANCH \
  --head $NIGHTSHIFT_BRANCH \
  --title "nightshift: $(date +%Y-%m-%d) — <N> issues shipped" \
  --body "$(cat .claude/nightshift/morning-report.md)"
```
