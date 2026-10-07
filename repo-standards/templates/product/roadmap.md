# Roadmap

Planned as a graph, executed in a line. Each item names what it **requires** (other items `R-n`, or capabilities `cap:<name>`) and what it **provides**. An item is **ready** when everything it requires is shipped; the next work is the highest-priority ready item, and it becomes a GitHub issue only then.

Statuses: `planned` (waiting on prerequisites or priority) · `ready` · `in-progress` (has an issue) · `shipped` · `dropped` (with reason).
Pre-push checks this file: every item serves a goal, every reference resolves, no cycles, nothing is ready or in progress on an unshipped prerequisite.

## Inbox
Captured ideas, not yet evaluated against the goals. Each is evaluated and confirmed by the owner one at a time, then moved below, merged, or rejected to `ideas-rejected.md`.

- <YYYY-MM-DD> <idea, in the owner's words>

## Items

### R-1 <title>
- goal: G-1
- status: planned
- priority: 1
- requires: -
- provides: cap:<capability>
- assumptions: -
- issue: -
- notes: <scope, what "done" means>
