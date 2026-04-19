---
name: daily-operator
description: Automated daily pipeline for SwadeshiApps.com — GSC analysis, content expansion, affiliate research, SEO optimization, and deployment. Run once daily.
---

# Daily Operator Pipeline

## Pre-flight

1. Read last log from `logs/daily-operator/` — what was done yesterday
2. Determine today's day for rotation schedule

## Daily Rotation

| Day | Primary Action | Secondary Action |
|-----|---------------|-----------------|
| Mon | New app entry | SEO optimization |
| Tue | New alternatives page | Affiliate research |
| Wed | Blog post (research + outline) | SEO optimization |
| Thu | Blog post (write + publish) | New app entry |
| Fri | New app entry | Affiliate link updates |
| Sat | SEO optimization (batch) | Review weekly metrics |
| Sun | Weekly summary report | Plan next week's targets |

## Stage 1: GSC Analysis

1. `mcp__gsc__enhanced_search_analytics` — last 7 days for `sc-domain:swadeshiapps.com`
2. Pull by `query` dimension (top 50) + `page` dimension (top 50)
3. Identify:
   - **Quick wins**: 100+ impressions, position 4-15, CTR < 3%
   - **Content gaps**: high-impression queries w/ no dedicated page
   - **Trending**: new queries not in previous logs

## Stage 2: Content Expansion (per rotation)

### New app entry day:
1. Pick highest-impact content gap from Stage 1
2. WebSearch — official site (company, pricing, features), app store reviews (rating, pros, cons), Reddit/Twitter/forums (complaints)
3. Create `data/categories/[category]/[slug].json`:
   ```json
   {
     "name": "App Name",
     "slug": "app-name",
     "description": "20-500 char description",
     "website": "https://...",
     "category": "category-slug",
     "alternatives": ["International Tool 1"],
     "pricing": "Free|Freemium|Paid|Open Source",
     "company": "Company Name",
     "location": "City, State",
     "pros": ["Strength 1", "Strength 2"],
     "cons": ["Weakness 1", "Weakness 2"],
     "userComplaints": ["Real complaint from reviews"],
     "rating": 4.0,
     "ratingSource": "Google Play Store",
     "lastVerified": "YYYY-MM-DD"
   }
   ```
4. `pnpm validate` — must pass

### New alternatives page day:
- Auto-generated from `alternatives` field in app JSONs
- Ensure ≥1 app lists international tool in `alternatives` array

### Blog post day (Wed = research, Thu = write):
- **Wed**: WebSearch target topic, gather data, save outline to daily log
- **Thu**: Write full post as `content/blog/[slug].md`
- Honest pros/cons, user complaints, "watch out for" sections
- Interlink existing app + alternatives pages
- Practical, unbiased tone

## Stage 3: Affiliate Research (Tue/Fri)

1. Pick 3-5 apps without affiliate entries
2. WebSearch "[app name] affiliate program" / "partner program"
3. If found, add to `data/affiliates.json`:
   ```json
   {
     "app-slug": {
       "affiliateUrl": "https://...",
       "program": "Program Name",
       "commission": "description of commission",
       "status": "active",
       "addedDate": "YYYY-MM-DD"
     }
   }
   ```
4. No program found → note in daily log to avoid re-checking

## Stage 4: SEO Optimization

For quick-win pages from Stage 1:
1. Read app JSON
2. Improve `description` to match high-impression queries
3. Ensure `alternatives` array covers all relevant international tools
4. Update `lastVerified`

## Stage 5: Ship It

1. `pnpm validate` — 0 errors
2. `pnpm build` — must succeed
3. Commit w/ descriptive message
4. Push to main
5. If validate/build fails → fix before proceeding

## Stage 6: Write Daily Log

Create `logs/daily-operator/YYYY-MM-DD.md`:

```markdown
# Daily Operator — YYYY-MM-DD (Day)

## GSC Summary (last 7 days)
- Total Impressions: X | Total Clicks: X | Avg Position: X
- Top growing queries: ...
- Quick wins identified: ...

## Actions Taken
- [list each action with file paths]

## Content Gaps Found (for future days)
- [query] — X impressions, no page exists

## Affiliate Research
- [app]: [found/not found] — [details]

## Notes
- [any observations or issues]
```

## Guard Rails

- NEVER delete existing content — only add or improve
- NEVER modify files outside project directory
- Max 2 new app entries/day, max 1 blog post/week
- Unsure about content decision → note in log, skip
