# Safety Rails

| Risk | Protection |
|------|-----------|
| Overkill pipeline for simple issues | Adaptive pipeline — classify after Step 1, skip unnecessary steps |
| Ambiguous requirements | Brainstorming gate — expert panel resolves or marks BLOCKED for human |
| Wrong plan for complex features | Interactive checkpoint (--supervised) — human reviews plan before coding |
| Infinite retry | Variable max per step (2/3/5/7/5/1) |
| Confusion/guessing | Expert panel convened, majority rules |
| Assumed bugs | Multi-angle investigation required, evidence-based root cause |
| False completion | Hard evidence required — output, screenshots, curl responses |
| Knowledge loss | Every iteration comments on GitHub issue |
| Session death | Issue comments + state file enable resume |
| Bad code on main | nightshift branch is a buffer — human merges |
| Breaking nightshift | Post-merge health check with full output |
| Runaway scope | Reviewers check scope at step 1 |
| Secrets in code | Security reviewer at steps 1, 2, 4 |
| Looping fixes | Anti-loop → expert panel → BLOCKED |
| Symptom-fixing | Reviewers reject workarounds, demand root cause fixes |
| Browser test flakiness | Screenshots as evidence, manual Chrome fallback |
| Merge conflicts | Sequential merge, next issue starts from latest nightshift |
| Rate limit hit | Check usage between issues + after heavy steps, graceful stop + state save |
| Context bloat | Thin orchestrator reads only summary lines, never full outputs |
| Resume corruption | Sonnet subagent validates state + branches before resuming |
| Stale resume | lastResult field tracks exact phase, never re-runs completed work |
| UI regression shipped | Visual review phase (D2) in Step 5 — mobile screenshots + accessibility checks + interaction testing. Reviewers reject if visual evidence is missing for UI issues |
