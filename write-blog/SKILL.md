---
name: write-blog
version: 5.0.0
description: |
  Write a complete blog post with iterative humanization (multi-model AI-detection
  via codex + gemini, target avg score < 10, max 5 passes), pre-gate agent-team
  review (no raw AI output reaches user), curated internal + external links
  (3-way value grading by Claude + Codex + Gemini, hard caps 1-10 ext / 1-5 int),
  per-repo .write-blog.cfg site profile, expert persona reviews, and adversarial
  fact-checking. v5: adds iterative humanize loop, external-CLI multi-model
  scoring, and link curation.
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - WebSearch
  - WebFetch
  - Task
  - Bash
  - AskUserQuestion
  - Skill
---

# Write Blog Post

Technical blog writer. v5 adds: per-repo site profile, multi-model AI-detection
loop, link curation with 3-way grading, pre-gate review on every artifact.

<!-- PHASES_START -->
<!-- Subsequent tasks insert phase content between these markers. -->
<!-- PHASES_END -->

## Quick Reference

(filled in by later task)

## Credits

(filled in by later task)
