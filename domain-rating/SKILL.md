---
name: domain-rating
description: >
  Fetch Ahrefs Domain Rating (DR) for any domain via the free public API. Use when
  the user asks for DR, domain rating, domain authority (DR is Ahrefs' equivalent),
  backlink strength, SEO competitive lookup, or wants to compare domains. Triggers
  on phrases like "what's the DR of X", "domain rating for X", "how strong is X's
  backlinks", "DR check", "Ahrefs DR", "compare DR of A vs B".
---

# Domain Rating (Ahrefs) Free API

Ahrefs exposes a free public endpoint that returns Domain Rating — a 0–100 logarithmic score of a domain's backlink-profile strength relative to other sites in Ahrefs' index. **No API key required.** No auth. Rate-limit is unspecified; treat as low and cache results.

## Endpoint

```
GET https://api.ahrefs.com/v3/public/domain-rating-free?target=<domain>
```

- `target` (required) — domain or full URL. Strip protocol if unsure; the API accepts both.
- `output` (optional) — `json` (default) | `csv` | `xml` | `php`.

## Single lookup

```bash
curl -sG "https://api.ahrefs.com/v3/public/domain-rating-free" \
  --data-urlencode "target=example.com" \
  -H "Accept: application/json" | jq '.domain_rating.domain_rating'
```

Returns a number like `92.5`.

## Batch lookup

```bash
for d in ahrefs.com semrush.com moz.com; do
  dr=$(curl -sG "https://api.ahrefs.com/v3/public/domain-rating-free" \
    --data-urlencode "target=$d" -H "Accept: application/json" \
    | jq -r '.domain_rating.domain_rating')
  printf "%-20s %s\n" "$d" "$dr"
  sleep 1   # be polite — rate limit unspecified
done
```

## Response shape

```json
{
  "domain_rating": {
    "domain_rating": 92.5,
    "license": "https://ahrefs.com/..."
  }
}
```

## Error codes

| code | meaning | action |
|------|---------|--------|
| 400 | bad target | check the domain string, no spaces, no path needed |
| 401 / 403 | shouldn't happen on free endpoint | re-read URL, you may have hit a paid endpoint |
| 429 | rate limited | back off, add `sleep`, batch with delay |
| 500 | Ahrefs side | retry with backoff, max 3 |

Error body is `{ "error": "<message>" }` — surface verbatim.

## Caching

DR doesn't change daily. When fetching repeatedly, cache by `domain → (dr, fetched_date)` and reuse for ~7 days unless the user asks for fresh data.

## Attribution

If displaying DR publicly (UI, report, blog), Ahrefs requires the credit line: **"Domain Rating by [Ahrefs](https://ahrefs.com/)"** near the number. For private CLI/notebook use, no attribution needed.

## When NOT to use this

- User wants **referring domains**, **backlink list**, **keyword data** — those are paid Ahrefs endpoints, not this one. Tell the user and stop.
- User wants **Moz DA** (Domain Authority) — different metric, different vendor; this skill doesn't cover it.
