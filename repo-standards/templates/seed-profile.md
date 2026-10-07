# Seed profile

Production's *shape*, not its data. Refreshed only by aggregate queries (counts, percentiles, null rates) — no row leaves production. The seed generator reads this to build `dev` and `perf` datasets.

- Last refreshed: <YYYY-MM-DD>, by <query file / script>
- `perf` scale: <1:1 | 1:N — reason>

## Entities

### <entity / table>
- Rows: <prod count>  → dev: <n>, perf: <n>
- Per parent: <p50 / p95 / max children per parent>
- Fields:
  - `<field>`: <type>, null rate <x%>, length/range p50 <..> p95 <..> max <..>, distribution <uniform | skewed: top-10 share x%>
- Edge cases seeded (from specs' Expectations): <unicode names, empty strings, max length, the 10k-item user, ...>

<!-- TODO(owner): fields only production knowledge can answer -->
