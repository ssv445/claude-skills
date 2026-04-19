# Safety Rails

| Risk | Protection |
|------|-----------|
| Overkill pipeline | Adaptive pipeline — classify after Step 1, skip unnecessary steps |
| Ambiguous requirements | Brainstorming gate — expert panel resolves or BLOCKED for human |
| Wrong plan | Interactive checkpoint (--supervised) — human reviews before coding |
| Infinite retry | Variable max per step (2/3/5/7/5/1) |
| Confusion/guessing | Expert panel, majority rules |
| Assumed bugs | Multi-angle investigation, evidence-based root cause |
| False completion | Hard evidence — output, screenshots, curl responses |
| Knowledge loss | Every iteration comments on issue |
| Session death | Issue comments + state file enable resume |
| Bad code on main | Nightshift branch buffer — human merges |
| Breaking nightshift | Post-merge health check with full output |
| Runaway scope | Reviewers check scope at step 1 |
| Secrets in code | Security reviewer at steps 1, 2, 4 |
| Looping fixes | Anti-loop → expert panel → BLOCKED |
| Symptom-fixing | Reviewers reject workarounds, demand root cause |
| Browser test flakiness | Screenshots as evidence, manual Chrome fallback |
| Merge conflicts | Sequential merge, next issue starts from latest nightshift |
| Rate limit hit | Check between issues + after heavy steps, graceful stop + state save |
| Context bloat | Thin orchestrator reads only summary lines |
| Resume corruption | Subagent validates state + branches before resuming |
| Stale resume | lastResult tracks exact phase, never re-runs completed work |
| UI regression shipped | Visual review in Step 5 — mobile screenshots + accessibility + interaction. Reject if visual evidence missing for UI issues |
