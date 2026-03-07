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

Create and manage GitHub Discussions via the GraphQL API.

## Prerequisites

- `gh` CLI must be authenticated (`gh auth status`)
- Repository must have Discussions enabled

## How to Create a Discussion

### Step 1: Determine the repo

Use the current git remote, or ask the user if not in a git repo.

```bash
REPO_OWNER=$(gh repo view --json owner -q '.owner.login')
REPO_NAME=$(gh repo view --json name -q '.name')
```

### Step 2: Get the repository ID

```bash
REPO_ID=$(gh api graphql -f query='{ repository(owner:"OWNER", name:"NAME") { id } }' -q '.data.repository.id')
```

### Step 3: List available discussion categories

```bash
gh api graphql -f query='{ repository(owner:"OWNER", name:"NAME") { discussionCategories(first:10) { nodes { id name } } } }'
```

Ask the user which category to use if not specified. Common categories: Announcements, General, Ideas, Q&A, Show and tell.

### Step 4: Write the body to a temp file

Always write the discussion body to a temp file first (`/tmp/gh-discussion-body.md`). This avoids shell quoting issues with long markdown content.

### Step 5: Create the discussion via GraphQL

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

**IMPORTANT**: Use `--raw-field body="$(cat /tmp/gh-discussion-body.md)"` to pass the body from file. This handles all special characters, newlines, and markdown formatting correctly.

### Step 6: Report the URL

Print the discussion URL for the user.

## How to Add a Comment to a Discussion

### Get the discussion node ID

```bash
DISCUSSION_ID=$(gh api graphql -f query='{ repository(owner:"OWNER", name:"NAME") { discussion(number: NUMBER) { id } } }' -q '.data.repository.discussion.id')
```

### Add the comment

Write comment body to `/tmp/gh-discussion-comment.md`, then:

```bash
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

## How to List Discussions

```bash
gh api graphql -f query='{ repository(owner:"OWNER", name:"NAME") { discussions(first:10, orderBy:{field:CREATED_AT, direction:DESC}) { nodes { number title url category { name } createdAt } } } }'
```

## How to Close a Discussion

```bash
DISCUSSION_ID=$(gh api graphql -f query='{ repository(owner:"OWNER", name:"NAME") { discussion(number: NUMBER) { id } } }' -q '.data.repository.discussion.id')

gh api graphql -f query='mutation($id: ID!) { closeDiscussion(input: { discussionId: $id, reason: RESOLVED }) { discussion { url } } }' -f id="$DISCUSSION_ID"
```

## Rules

- Always confirm with the user before posting (this is a public action)
- Write body to a temp file — never inline long markdown in shell commands
- Use `--raw-field` (not `-f`) for the body parameter to preserve formatting
- Return the discussion URL when done
- If `$ARGUMENTS` is provided, use it as the discussion topic/content
- Clean up temp files after posting
