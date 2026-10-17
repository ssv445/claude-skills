# Adding

## US-AD-01: Add two numbers

**Story:** As someone adding, I can add two numbers so that I see their sum.
**Test cases:**
1. **Given** 1 and 2 **When** I add them **Then** I see 3.
**Covered by:** `tests/stories/area.test.sh` "adds two numbers" and "adds zero"; the click sound is manual only.

## US-AD-02: Feel the click

**Story:** As someone adding, I feel a click on each key so that I know it registered.
**Covered by:** manual only (haptics cannot be checked in simulators).

## US-AD-03: A long test name, cut short

**Story:** As someone adding, I can add long lists.
**Covered by:** `tests/stories/area.test.sh` — "a very long test name that ..."; a `count` value in a name is no file: "adds zero".

## US-AD-04: Curly quotes

**Story:** As someone adding, I can add zero.
- **Covered by:** `tests/stories/area.test.sh` “adds zero”

## US-AD-05: A link beside the tests

**Covered by:** `tests/stories/area.test.sh` "adds zero"; see https://example.com/spec.html and `https://example.com/a/b.html`

## US-AD-07: A bare test path (matches TEST_GLOBS)

**Covered by:** tests/stories/area.test.sh "adds two numbers"; notes in docs/spec/adding.md

## US-AD-06: Old devices

**Covered by:** manual only (needs a v1.2/v1.3 device; see src/old/device.md)
