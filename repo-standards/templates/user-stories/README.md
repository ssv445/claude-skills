# User stories

These are the user stories this product supports today. Each story says what a person can do and how it behaves, and has test cases a tester can run by hand. Where automated tests cover a story, the story names them under "Covered by". A story with "manual only" there has no automated check. Some things tools cannot check (sound, haptics, how an animation feels); say so in the story instead of claiming them.

## Story ids

An id looks like `US-CH-04`. `US` means user story, the two letters name the file (area), and the number is the story's place in that file. An id never changes once used, and a removed story's number is never reused, so a link to an id stays valid. A spec's acceptance criteria cite the id they change, or the new id they add.

## The parts of a story

- **Story:** one sentence, "As someone ..., I can ... so that ...".
- **Notes:** exact behaviour, with limits and numbers.
- **Test cases:** numbered Given / When / Then steps.
- **Coverage:** a "Covered by" line naming the automated tests that check it — each test file in backticks, then each test name in double quotes — or saying "manual only". On every push `.standards/checks/stories.sh` checks that each file exists and holds each quoted name. A long name may be cut short with `...`, at the end or in the middle; each part between the dots must match. Quote only test names, never other text.

Example (a code block, so the check skips it):

```
## US-CH-04: See how far through the round I am

**Story:** As someone chanting, I can see my place as "N / 108" so that I know how far I am from a full round.
**Notes:** The position is the all-time count modulo 108, so an unfinished round carries over between days.
**Test cases:**
1. **Given** count 0 **When** I tap once **Then** the label shows "1 / 108".
2. **Given** count 107 **When** I tap once **Then** the label shows "0 / 108" and "1 round".
**Covered by:** `tests/round.test.ts` "position resets at 108"; the label's look is manual only.
```

## Keep them current

Update the story in the same PR that changes the behaviour it describes. Add a story for a new behaviour, edit the notes and test cases when a rule changes, and remove a story when the feature goes. If you rename or move a test, fix its "Covered by" line in the same PR; the push fails until you do.

## Files

| File | Area | Stories |
|---|---|---|
| | | |
