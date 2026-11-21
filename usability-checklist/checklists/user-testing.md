# User testing

**Principle:** testing with one user is far better than testing with none, and testing early beats testing late. A checklist finds the obvious problems. Watching a real person finds the ones nobody on the team can see any more.

An agent cannot run this test. Use this file to check whether the team does it, and to hand the team a plan.

## Is the team doing it?

| ID | Check | How to check |
|---|---|---|
| T1 | Someone has watched a real user use this in the last month | Ask. "We look at analytics" does not count |
| T2 | Tests happen on a fixed schedule | For example one morning a month, whatever is in progress gets tested |
| T3 | Three users per round | Three find most of the serious problems. More rounds beat more users per round |
| T4 | Almost anyone is accepted as a tester | Do not wait for the perfect target user. Recruit loosely |
| T5 | The team watches | Developers, designers and the owner watch live or the same day |
| T6 | Testing starts early | Sketches, prototypes and competitors' sites are tested before the build is finished |
| T7 | The worst problems are fixed before the next round | A short list gets fixed. A long report does not |

## The plan to hand over

1. **Pick 3 to 5 tasks** a real user would come to do. Write each as a scenario with no hints: "You want to send 50 invoices this month. Find out what it will cost."
2. **Recruit 3 people.** About an hour each. Record the screen and voice.
3. **Start with the home page.** Ask what they think this is and what they could do here, before they click anything.
4. **Give one task at a time. Ask them to think aloud.** Stay neutral. Do not help, do not explain, do not defend. When they go quiet, ask "what are you thinking?"
5. **Debrief the same day.** Each observer lists the three worst problems they saw. Merge the lists and pick the top few.
6. **Fix with the smallest change** that removes the problem. Tweak before redesigning. Removing something often beats adding something.
7. **Test again next month.**

## Triage rules

- Fix the most serious problems first, even when easier ones are tempting.
- Ignore problems where the user went astray briefly and recovered alone.
- Treat feature requests from testers with caution. Ask what they were trying to do.
