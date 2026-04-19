---
name: gh-discussion
version: 1.0.0
description: |
  Create or manage GitHub Discussions. Use when the user says "create a discussion",
  "post to discussion", "gh discussion", or asks to put something on a GitHub discussion.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# GitHub Discussion Manager

Prereqs: `gh` CLI authenticated, repo has Discussions enabled.

## Create Discussion

1. Get repo info:
   ```bash
   REPO_OWNER=$(gh repo view --json owner -q '.owner.login')
   REPO_NAME=$(gh repo view --json name -q '.name')
   ```

2. Get repo ID:
   ```bash
   REPO_ID=$(gh api graphql -f query='{ repository(owner:"OWNER", name:"NAME") { id } }' -q '.data.repository.id')
   ```

3. List categories — ask user which one if not specified:
   ```bash
   gh api graphql -f query='{ repository(owner:"OWNER", name:"NAME") { discussionCategories(first:10) { nodes { id name } } } }'
   ```

4. Write body to `/tmp/gh-discussion-body.md` — never inline long markdown in shell.

5. Create via GraphQL. Use `--raw-field` (not `-f`) for body to preserve formatting:
   ```bash
   gh api graphql \
     -f query='mutation($repoId: ID!, $catId: ID!, $title: String!, $body: String!) {
       createDiscussion(input: {
         repositoryId: $repoId,
         categoryId: $catId,
         title: $title,
         body: $body
       }) {
         discussion {
           url
           number
         }
       }
     }' \
     -f repoId="$REPO_ID" \
     -f catId="$CATEGORY_ID" \
     -f title="Discussion Title" \
     --raw-field body="$(cat /tmp/gh-discussion-body.md)"
   ```

6. Print discussion URL. Clean up temp files.

## Add Comment

Get discussion node ID, write comment to `/tmp/gh-discussion-comment.md`:

```bash
DISCUSSION_ID=$(gh api graphql -f query='{ repository(owner:"OWNER", name:"NAME") { discussion(number: NUMBER) { id } } }' -q '.data.repository.discussion.id')

gh api graphql \
  -f query='mutation($discussionId: ID!, $body: String!) {
    addDiscussionComment(input: {
      discussionId: $discussionId,
      body: $body
    }) {
      comment {
        url
      }
    }
  }' \
  -f discussionId="$DISCUSSION_ID" \
  --raw-field body="$(cat /tmp/gh-discussion-comment.md)"
```

## List Discussions

```bash
gh api graphql -f query='{ repository(owner:"OWNER", name:"NAME") { discussions(first:10, orderBy:{field:CREATED_AT, direction:DESC}) { nodes { number title url category { name } createdAt } } } }'
```

## Close Discussion

```bash
DISCUSSION_ID=$(gh api graphql -f query='{ repository(owner:"OWNER", name:"NAME") { discussion(number: NUMBER) { id } } }' -q '.data.repository.discussion.id')

gh api graphql -f query='mutation($id: ID!) { closeDiscussion(input: { discussionId: $id, reason: RESOLVED }) { discussion { url } } }' -f id="$DISCUSSION_ID"
```

## Rules

- Confirm w/ user before posting (public action)
- Always use `--raw-field` for body param
- If `$ARGUMENTS` provided, use as topic/content
- Return discussion URL when done
