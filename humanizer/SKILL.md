---
name: humanizer
version: 2.1.1
description: |
  Remove signs of AI-generated writing from text. Use when editing or reviewing
  text to make it sound more natural and human-written. Based on Wikipedia's
  comprehensive "Signs of AI writing" guide. Detects and fixes patterns including:
  inflated symbolism, promotional language, superficial -ing analyses, vague
  attributions, em dash overuse, rule of three, AI vocabulary words, negative
  parallelisms, and excessive conjunctive phrases.
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# Humanizer: Remove AI Writing Patterns

Editor that identifies/removes AI-generated text patterns. Based on Wikipedia's "Signs of AI writing" (WikiProject AI Cleanup).

## Task

1. Scan for patterns below
2. Rewrite problematic sections
3. Preserve meaning + match intended tone
4. Add soul — don't just remove bad patterns, inject personality

---

## PERSONALITY AND SOUL

Avoiding AI patterns = half the job. Sterile voiceless writing equally obvious as slop.

### Soulless signals (even if "clean"):
- Same sentence length/structure throughout
- No opinions, just neutral reporting
- No uncertainty or mixed feelings
- No first-person when appropriate
- No humor, edge, personality
- Reads like Wikipedia or press release

### How to add voice:

**Have opinions.** React to facts. "I genuinely don't know how to feel about this" > neutrally listing pros/cons.

**Vary rhythm.** Short punchy. Then longer ones that take their time. Mix it up.

**Acknowledge complexity.** Humans have mixed feelings. "Impressive but unsettling" > "impressive."

**Use "I" when it fits.** "I keep coming back to..." signals real person thinking.

**Let mess in.** Perfect structure feels algorithmic. Tangents and half-formed thoughts are human.

**Be specific about feelings.** Not "concerning" but "something unsettling about agents churning at 3am while nobody's watching."

---

## CONTENT PATTERNS

### 1. Inflated Significance/Legacy

**Watch:** stands/serves as, testament/reminder, vital/significant/crucial/pivotal/key role/moment, underscores/highlights importance, reflects broader, symbolizing ongoing/enduring/lasting, contributing to, setting stage for, marking/shaping, represents/marks a shift, key turning point, evolving landscape, focal point, indelible mark, deeply rooted

**Problem:** Puffs up importance with statements about how arbitrary aspects represent broader topics.

**Before:**
> The Statistical Institute of Catalonia was officially established in 1989, marking a pivotal moment in the evolution of regional statistics in Spain. This initiative was part of a broader movement across Spain to decentralize administrative functions and enhance regional governance.

**After:**
> The Statistical Institute of Catalonia was established in 1989 to collect and publish regional statistics independently from Spain's national statistics office.

---

### 2. Undue Notability/Media Emphasis

**Watch:** independent coverage, local/regional/national media outlets, written by a leading expert, active social media presence

**Before:**
> Her views have been cited in The New York Times, BBC, Financial Times, and The Hindu. She maintains an active social media presence with over 500,000 followers.

**After:**
> In a 2024 New York Times interview, she argued that AI regulation should focus on outcomes rather than methods.

---

### 3. Superficial -ing Analyses

**Watch:** highlighting/underscoring/emphasizing..., ensuring..., reflecting/symbolizing..., contributing to..., cultivating/fostering..., encompassing..., showcasing...

**Problem:** Tacks present participle phrases onto sentences for fake depth.

**Before:**
> The temple's color palette of blue, green, and gold resonates with the region's natural beauty, symbolizing Texas bluebonnets, the Gulf of Mexico, and the diverse Texan landscapes, reflecting the community's deep connection to the land.

**After:**
> The temple uses blue, green, and gold colors. The architect said these were chosen to reference local bluebonnets and the Gulf coast.

---

### 4. Promotional Language

**Watch:** boasts a, vibrant, rich (figurative), profound, enhancing its, showcasing, exemplifies, commitment to, natural beauty, nestled, in the heart of, groundbreaking (figurative), renowned, breathtaking, must-visit, stunning

**Before:**
> Nestled within the breathtaking region of Gonder in Ethiopia, Alamata Raya Kobo stands as a vibrant town with a rich cultural heritage and stunning natural beauty.

**After:**
> Alamata Raya Kobo is a town in the Gonder region of Ethiopia, known for its weekly market and 18th-century church.

---

### 5. Vague Attributions / Weasel Words

**Watch:** Industry reports, Observers have cited, Experts argue, Some critics argue, several sources/publications (when few cited)

**Before:**
> Due to its unique characteristics, the Haolai River is of interest to researchers and conservationists. Experts believe it plays a crucial role in the regional ecosystem.

**After:**
> The Haolai River supports several endemic fish species, according to a 2019 survey by the Chinese Academy of Sciences.

---

### 6. Formulaic "Challenges and Future Prospects"

**Watch:** Despite its... faces several challenges..., Despite these challenges, Challenges and Legacy, Future Outlook

**Before:**
> Despite its industrial prosperity, Korattur faces challenges typical of urban areas, including traffic congestion and water scarcity. Despite these challenges, with its strategic location and ongoing initiatives, Korattur continues to thrive as an integral part of Chennai's growth.

**After:**
> Traffic congestion increased after 2015 when three new IT parks opened. The municipal corporation began a stormwater drainage project in 2022 to address recurring floods.

---

## LANGUAGE AND GRAMMAR PATTERNS

### 7. Overused AI Vocabulary

**Words:** Additionally, align with, crucial, delve, emphasizing, enduring, enhance, fostering, garner, highlight (verb), interplay, intricate/intricacies, key (adjective), landscape (abstract noun), pivotal, showcase, tapestry (abstract noun), testament, underscore (verb), valuable, vibrant

These appear far more frequently in post-2023 text and often co-occur.

**Before:**
> Additionally, a distinctive feature of Somali cuisine is the incorporation of camel meat. An enduring testament to Italian colonial influence is the widespread adoption of pasta in the local culinary landscape, showcasing how these dishes have integrated into the traditional diet.

**After:**
> Somali cuisine also includes camel meat, which is considered a delicacy. Pasta dishes, introduced during Italian colonization, remain common, especially in the south.

---

### 8. Copula Avoidance

**Watch:** serves as/stands as/marks/represents [a], boasts/features/offers [a]

Substitutes elaborate constructions for simple is/are/has.

**Before:**
> Gallery 825 serves as LAAA's exhibition space for contemporary art. The gallery features four separate spaces and boasts over 3,000 square feet.

**After:**
> Gallery 825 is LAAA's exhibition space for contemporary art. The gallery has four rooms totaling 3,000 square feet.

---

### 9. Negative Parallelisms

"Not only...but..." or "It's not just about..., it's..." — overused.

**Before:**
> It's not just about the beat riding under the vocals; it's part of the aggression and atmosphere. It's not merely a song, it's a statement.

**After:**
> The heavy beat adds to the aggressive tone.

---

### 10. Rule of Three

Forces ideas into groups of three.

**Before:**
> The event features keynote sessions, panel discussions, and networking opportunities. Attendees can expect innovation, inspiration, and industry insights.

**After:**
> The event includes talks and panels. There's also time for informal networking between sessions.

---

### 11. Elegant Variation (Synonym Cycling)

Repetition-penalty causes excessive synonym substitution.

**Before:**
> The protagonist faces many challenges. The main character must overcome obstacles. The central figure eventually triumphs. The hero returns home.

**After:**
> The protagonist faces many challenges but eventually triumphs and returns home.

---

### 12. False Ranges

"From X to Y" where X and Y aren't on meaningful scale.

**Before:**
> Our journey through the universe has taken us from the singularity of the Big Bang to the grand cosmic web, from the birth and death of stars to the enigmatic dance of dark matter.

**After:**
> The book covers the Big Bang, star formation, and current theories about dark matter.

---

## STYLE PATTERNS

### 13. Em Dash Overuse

LLMs use em dashes (—) more than humans. Replace most with commas or periods.

**Before:**
> The term is primarily promoted by Dutch institutions—not by the people themselves. You don't say "Netherlands, Europe" as an address—yet this mislabeling continues—even in official documents.

**After:**
> The term is primarily promoted by Dutch institutions, not by the people themselves. You don't say "Netherlands, Europe" as an address, yet this mislabeling continues in official documents.

---

### 14. Overuse of Boldface

Mechanically emphasizes phrases in bold.

**Before:**
> It blends **OKRs (Objectives and Key Results)**, **KPIs (Key Performance Indicators)**, and visual strategy tools such as the **Business Model Canvas (BMC)** and **Balanced Scorecard (BSC)**.

**After:**
> It blends OKRs, KPIs, and visual strategy tools like the Business Model Canvas and Balanced Scorecard.

---

### 15. Inline-Header Vertical Lists

Bolded headers + colons in list items.

**Before:**
> - **User Experience:** The user experience has been significantly improved with a new interface.
> - **Performance:** Performance has been enhanced through optimized algorithms.
> - **Security:** Security has been strengthened with end-to-end encryption.

**After:**
> The update improves the interface, speeds up load times through optimized algorithms, and adds end-to-end encryption.

---

### 16. Title Case in Headings

Capitalizes all main words.

`## Strategic Negotiations And Global Partnerships` → `## Strategic negotiations and global partnerships`

---

### 17. Emojis

Decorates headings/bullets with emojis. Strip them, convert to prose.

---

### 18. Curly Quotation Marks

ChatGPT uses curly quotes ("\u201c...\u201d") instead of straight quotes ("..."). Replace with straight.

---

## COMMUNICATION PATTERNS

### 19. Collaborative Artifacts

**Watch:** I hope this helps, Of course!, Certainly!, You're absolutely right!, Would you like..., let me know, here is a...

Chatbot correspondence pasted as content. Strip entirely.

---

### 20. Knowledge-Cutoff Disclaimers

**Watch:** as of [date], Up to my last training update, While specific details are limited/scarce..., based on available information...

Strip. Replace with concrete facts.

---

### 21. Sycophantic Tone

**Watch:** Great question!, You're absolutely right, That's an excellent point

Strip. State substance only.

---

## FILLER AND HEDGING

### 22. Filler Phrases

- "In order to achieve this goal" → "To achieve this"
- "Due to the fact that it was raining" → "Because it was raining"
- "At this point in time" → "Now"
- "In the event that you need help" → "If you need help"
- "The system has the ability to process" → "The system can process"
- "It is important to note that the data shows" → "The data shows"

---

### 23. Excessive Hedging

**Before:** It could potentially possibly be argued that the policy might have some effect on outcomes.
**After:** The policy may affect outcomes.

---

### 24. Generic Positive Conclusions

Vague upbeat endings. Replace with specifics.

**Before:**
> The future looks bright for the company. Exciting times lie ahead as they continue their journey toward excellence.

**After:**
> The company plans to open two more locations next year.

---

## Process

1. Read input text
2. Identify all pattern instances
3. Rewrite each problematic section
4. Verify: sounds natural aloud, varied structure, specific > vague, simple constructions (is/are/has) where appropriate
5. Present humanized version + optional change summary

---

## Reference

Based on [Wikipedia:Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) (WikiProject AI Cleanup).

Key insight: "LLMs use statistical algorithms to guess what should come next. The result tends toward the most statistically likely result that applies to the widest variety of cases."
