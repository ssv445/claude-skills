---
issue: <number>
owner-approval: not-required   # required if: architecture, schema/data model, new 3rd-party dep or paid service, auth/security, pricing or user-facing promise
---

# <Title>

## Story
As a <user>, I want <capability>, so that <outcome>.

## Acceptance criteria
- [ ] AC1: <observable behaviour>
- [ ] AC2: ...

## Expectations
Tag every line `[sourced: <where>]` or `[inferred]`. A field that does not apply: `N/A — reason`.

- **User:** who (link `docs/product/icp.md` persona), technical skill, device, language, how often.
- **Interaction:** entry points; step-by-step journey.
- **Inputs:** each input — shape, range, size, required/optional, default; examples of bad input.
- **Error cases:** what breaks → what the user sees → how they recover.
- **Scale & performance:** volume now and in 12 months; p95 latency budget; known traps (N+1, unbounded lists, fan-out).
- **Accuracy:** where approximate is fine vs where it must be exact.
- **Freshness / caching:** what may be stale, for how long, what invalidates it.
- **Non-goals:** what this explicitly does not handle.

## Plan
Layer checklist — `included` or `N/A — reason`:
- Data / schema:
- API:
- UI:
- Shared types:
- Seeds (edge cases from Expectations):
- Docs (from `docs/doc-map.txt`):
- Unit tests:
- Integration tests:
- E2E tests:
- Perf check (budget from Expectations):
- Deploy / migration:
- ADR: <link or N/A — reason>

Steps:
1. ...
