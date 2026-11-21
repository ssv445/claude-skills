---
name: usability-checklist
description: "Use when reviewing, auditing or fixing the usability of a website, web page, app screen or flow: a page feels confusing, users get lost or drop off, a signup, checkout or form needs a UX pass, navigation or a home page needs checking, or a design is about to ship. Triggers: usability audit, UX review, usability checklist, don't make me think, Krug, is this page clear, why do users get stuck, trunk test."
---

# Usability Checklist

Checklists built from the principles in Steve Krug's *Don't Make Me Think*. One file per area. Pick the areas that fit what is under review, check every item in them against evidence, and report pass or fail per item.

**Core principle:** every moment a user spends working out what something is or how to use it is a defect. Find those moments.

## 1. Pick the areas

Read the request and look at the target once. Then pick **2 to 4 areas** from this table. Pick all of them only when the user asks for a full audit.

| Area | Pick when | File |
|---|---|---|
| Clarity | Any first-time-visitor page; "confusing", "people don't get it" | `checklists/clarity.md` |
| Scanning | Dense or long pages; dashboards; content pages; "cluttered" | `checklists/scanning.md` |
| Clickability | Low click-through; custom-styled controls; users miss the main action | `checklists/clickability.md` |
| Choices and forms | Signup, checkout, settings, wizards, any form; drop-off mid-flow | `checklists/choices-and-forms.md` |
| Words | Text-heavy pages; marketing copy; long instructions | `checklists/words.md` |
| Navigation | Multi-page site or multi-screen app; "users get lost", "where do I go next"; deep pages; visitors arriving from search | `checklists/navigation.md` |
| Home page | The home page, a landing page, or whichever page most visitors see first; "what does this site do?" | `checklists/home-page.md` |
| Goodwill | Pricing, checkout, support, errors, signup walls; "users leave annoyed" | `checklists/goodwill.md` |
| Mobile | Phone traffic matters; responsive layout; native app screens | `checklists/mobile.md` |
| Accessibility | Public-facing pages; forms; before any launch | `checklists/accessibility.md` |
| User testing | The team has never watched a real user; after fixes, to confirm them | `checklists/user-testing.md` |

Common picks:

| Target | Areas |
|---|---|
| Home or landing page | Home page, Clarity, Scanning |
| Signup, login, checkout | Choices and forms, Goodwill, Accessibility |
| Deep content or product page | Navigation, Scanning, Words |
| App screen | Clarity, Clickability, Mobile |
| "Users get lost" | Navigation, Clarity |

The user's stated complaint decides first: pick the areas whose "Pick when" matches it. With no complaint, start from the common picks for the target.

Read only the files for the areas you picked.

## 2. Check each item

Go through every item in each picked file. Give each one a verdict:

- **FAIL**: with evidence (the element, text, selector or screenshot region) and the smallest fix.
- **PASS**: no comment needed.
- **N/A**: the item does not apply to this target.
- **UNCHECKED**: the evidence you have cannot settle it. Say what would (a rendered page, a phone, a real user).

Each item gets exactly one verdict. Write the verdicts down as a list per area (`F1 PASS, F2 FAIL, ...`) before writing the report, and build the report from that list.

Evidence sources, best first: the live page in a browser, screenshots, the source code. Use the browser tooling the environment prescribes. Working from source alone is fine, but items about what the eye sees first (prominence, 5-second clarity, contrast) are UNCHECKED unless the CSS makes the answer certain.

## 3. Report

The report has these parts, in this order:

1. **Verdict**: one or two sentences. The worst problem and what it costs the user.
2. **Areas checked**: the picked areas, each with a one-line reason.
3. **Failures**: a table, worst damage first.

   | Item | Problem (with evidence) | Fix |
   |---|---|---|
   | F4 | Phone field rejects spaces: `pattern="\d{3}-\d{3}-\d{4}"` | Accept any format, normalise in code |

   One row per problem. When one problem fails items in two areas, list every ID in that row (`F4, G2`); each ID still counts as a fail in its own area's score.

4. **Score per area**: one line each, counted from the verdict list. The four numbers add up to the number of items in the file.

   `Choices and forms (12 items): 5 pass, 4 fail, 1 unchecked, 2 n/a`

5. **Unchecked items**: only the items with the UNCHECKED verdict, each with what would settle it.
6. **Areas not checked**: the areas you skipped, so the user can ask for them.
7. **Next step**: the top 3 fixes, then one line recommending a 3-user test (`checklists/user-testing.md`) unless the user has said they already run them. State nothing about the team's habits that the user did not tell you.

Problems that belong to an area you did not pick, or to no checklist (a broken submit handler, a security hole), go in a short **Also noticed** list after the failures table. Do not file them under an item ID from a picked area.

## 4. Fixing

When the user asked for fixes, not only a review: fix the failed items worst first, with the smallest change that makes the item pass. Re-check each fixed item against the checklist wording and report the new verdict. A redesign is a separate decision for the user.

## Common mistakes

| Mistake | Instead |
|---|---|
| Running all 11 areas on one small page | Pick 2 to 4. A report with 60 rows gets ignored |
| Reporting a failure with no evidence | Quote the text or name the element |
| Marking PASS from source when the item is visual | Mark UNCHECKED and say what would settle it |
| Proposing a redesign for each failure | Smallest change that passes the item |
| Treating the checklist as a substitute for watching users | It finds the obvious problems; a real user finds the rest |
