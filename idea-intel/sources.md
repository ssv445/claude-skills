# Idea intelligence sources

Numbers in brackets are the questions in SKILL.md each source answers.

## Ad libraries and ad tools — what's selling [2, 5]

An ad that runs 30+ days is very likely profitable; nobody keeps paying for a losing ad.

- **Meta Ad Library** (https://www.facebook.com/ads/library/): what anyone advertises, since when, in which countries. The web UI covers commercial ads in every country. The official API covers all ads only in the EU (with reach and age data) and only political/issue ads elsewhere. Outside the EU, stopped ads mostly drop out of view, so a daily archive builds history nobody else has.
- **Google Ads Transparency Center** (https://adstransparency.google.com): every advertiser's Search, YouTube, Display and Shopping ads, with regions and first/last-shown dates. Search by brand or domain. No official export; the YouTube filter covers ads since Sept 2023.
- **LinkedIn Ad Library** (https://www.linkedin.com/ad-library): public, no login, ads since June 2023, kept 1 year after their last impression. Search by advertiser, payer or keyword per country. Impressions and run dates only for EU-targeted ads. Best for B2B ideas.
- **TikTok Creative Center** (https://ads.tiktok.com/business/creativecenter; free TikTok for Business account, no spend): top ads by country/industry/objective, trending hashtags, Keyword Insights. The separate TikTok Ad Library covers mainly EU/UK ads. Country counts disagree across sources — check the live site.
- **X Ads Repository**: EU-served ads with advertiser, targeting, impressions and reach.
- **Reddit**: no real ad library, only a hand-picked Ads Inspiration Library with no spend data. Its organic posts are the value (see Communities).
- **Audience estimators** in every ad platform's campaign setup (Meta, Google, LinkedIn, TikTok, Reddit, X): audience size per targeting choice, free, no spend.
- **Affiliate networks** (PartnerStack, Impact) [4, 7]: the commission a company pays per customer shows its margins and how much it can spend to win one.
- **Newsletter and podcast sponsorships** (Paved, Sponsorgap) [7]: who pays to reach an audience and how much — hints at what a customer there is worth.

## Demand [3]

- **Google Ads → Keyword Planner** (the Ready Bytes account; "Discover new keywords" results only, never create a campaign): search volume bands, competition and top-of-page bids per keyword and location. High bids = advertisers find these buyers valuable.
- **Google Trends** (https://trends.google.com) [3, 6]: rising, flat or falling, per country, over 5 years. A relative 0–100 index, not volume — pair with Keyword Planner. Compare up to 5 terms; switch to "YouTube Search" for how-to demand. Report yearly averages, not peaks.
- **YouTube** [1, 3, 5]: view counts on "how to X" tutorials measure how-to demand better than search volume; comments are pain in viewers' words; channels reviewing tools in the niche are distribution partners; competitor channels' subscribers show who has an audience.
- **Glimpse, Exploding Topics**: trend discovery (paid tiers).

## Pain in people's own words [1]

- **Communities** [1, 7]: Reddit, Hacker News (Algolia API), Quora, Facebook Groups, Discord, Slack groups, X search. Also a ready audience to reach.
- **Review sites**: 1–3★ reviews of incumbents on G2, Capterra, Trustpilot.
- **GitHub**: issues and feature requests on popular repos. A free open-source version with many stars caps what a paid clone can charge (Dub at 24.9K stars sank a UTM-tool idea). Star growth and trending repos show rising categories.
- **npm, PyPI, Stack Overflow** (developer tools only): download trends show adoption; repeated questions show pain.

## Who pays for it [2]

- **Freelance marketplaces** [1, 2]: Upwork, Fiverr, Freelancer.com, PeoplePerHour (UK/EU), Malt (France/Germany/EU), Contra, Airtasker (Australia). A job post = someone paying a person by hand — the pain, its frequency and its price per job. Many posts for the same repeatable task = a product to automate it. Gig sellers with many reviews = proven demand and a price ceiling.
- **Job boards** [1, 2]: LinkedIn Jobs, Indeed, Seek (AU), StepStone (EU). A company hiring for a task has a budget for it — the salary is the ceiling a tool competes against. Job descriptions name the tools teams already use.
- **Zapier and Make app directories** [1, 2]: the most-used automations between two apps are workflows people glue together by hand — a popular one can become a product.

## App and product marketplaces [1, 2, 5]

Each shows every product in the niche with price, rating and 1–3★ reviews (unsolved pain). A popular product that's stale or badly reviewed is an opening. Each is also a distribution channel — buyers search inside it. Use the target markets' storefronts.

- **Shopify App Store** (https://apps.shopify.com): no install counts — review count is the traction proxy; prices public; "Built for Shopify" marks vetted apps.
- **WordPress.org plugins** (https://wordpress.org/plugins/): active-install bands, ratings, last-updated date, support forum (unresolved threads = pain). Pro versions sell off-site.
- **Chrome Web Store**: user counts and ratings (real usage). An extension with many users and no update in a year+ is an opening. Also a cheap distribution channel.
- **Apple App Store and Google Play**: top charts per country, ratings counts, in-app purchase prices (App Store lists them). Google Play shows install bands; the App Store doesn't — use ratings count.
- **ChatGPT app directory / GPT Store** (plugins were retired), **Claude connector directory**: what exists for the job. A popular free GPT doing the job weakens a paid product.
- **B2B marketplaces**: HubSpot, Salesforce AppExchange, Atlassian, Slack, Notion templates, Figma Community.
- **Amazon** [1–4]: Best Sellers Rank, review counts, "N+ bought in past month" (real monthly sales), price spread, "Movers & Shakers". 1–3★ reviews of top sellers = the improved version to build.
- **Etsy** [1–4]: shop sales counts, "in N baskets", Bestseller badges. Strong for digital products (templates, planners) — a cheap test of whether people pay for a format before building software.
- **AppSumo** (https://appsumo.com): lifetime deals; review count per deal ≈ buyers; detailed reviews of what's missing. Many deals in a category = tools that couldn't sell subscriptions. Buyers are deal-hunters.
- **Gumroad** (https://gumroad.com/discover): creators' digital products with ratings and often sales counts — what a niche audience pays for directly.
- **Envato Market** [2, 4, 5] — ThemeForest (site and admin templates, WordPress themes), CodeCanyon (plugins, scripts, app source code), VideoHive, AudioJungle, GraphicRiver. **Every item and author page shows public sales counts**, price and "member since" — sales × price is near-real revenue, the strongest evidence for digital assets. Sort a category by sales (`?sort=sales`) for the leaders; compare an author's total sales with their age. Envato takes a large cut and its traffic is falling, so check recent sales trend, not lifetime totals. (codedthemes: 2,280 sales since 2017 vs Metronic 120K — it showed the brand was small.)
- **Other template and asset marketplaces**: Creative Market, UI8 (UI kits), TemplateMonster, Framer and Webflow template marketplaces, Figma Community (paid files). Ratings, prices and, on some, sales counts — which formats and niches people buy.

## AI answers — AEO and Google AI Overviews [2, 5, 7]

Ask ChatGPT, Perplexity, Gemini and Claude the buyer's questions ("best tool for X", "how do I X"), and search the main keywords on Google for an AI Overview and its cited sites.
- If a chatbot does the job in one prompt, the product is dead.
- Brands AI keeps recommending own AI-search distribution; cited pages show what content wins.
- An AI Overview on a keyword means fewer clicks to websites, so SEO is weaker there.
For optimizing our own content to be cited, use the `ai-seo` skill.

## Revenue and value [4]

- **TrustMRR** (https://trustmrr.com/startup/<name>): MRR, subscriptions and all-time revenue verified through payment-provider API keys. The most reliable small-SaaS revenue source — check a competitor's page first.
- **Business-for-sale marketplaces** [2, 4, 5]: Acquire.com, Flippa, Empire Flippers, Microns.io. Revenue, profit, churn, customers, asking price, and often why the owner is leaving. Seller-claimed; prefer verified listings.
- **Indie Hackers** (https://www.indiehackers.com): revenue milestones, launch posts, post-mortems. Self-reported — cross-check on TrustMRR.

## Competitors and launches [5, 6]

- **Similarweb** (https://www.similarweb.com/website/<domain>/): estimated visits, growth, country split, traffic channels, similar sites. Rough; missing for very small sites. Paid-traffic share shows whether ads work in the niche.
- **Semrush/Ahrefs**: rankings; free DR via the `domain-rating` skill.
- **BuiltWith/Wappalyzer**: tech adoption — market size for add-ons.
- **Wayback Machine**: old pricing and feature pages — a free archive of how competitors changed.
- **Product Hunt**: every launch in the category with upvotes and comments — who tried, whether anyone cared, the objections. Many low-upvote launches = crowded and unexciting.
- **Show HN, BetaList, Kickstarter**: new launches.
- **Y Combinator** (https://www.ycombinator.com/companies, Requests for Startups): which problems top investors fund.
- **Crunchbase, Dealroom (EU)**: funding.
