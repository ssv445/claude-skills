# Accessibility

**Principle:** fixing the usability problems that confuse everyone is the biggest accessibility win. After that, a short list of fixes covers most of the rest. It is the right thing to do, and it makes the site better for every user.

| ID | Check | How to check |
|---|---|---|
| A1 | Every meaningful image has alt text | Decorative images have empty `alt=""`. Image-only buttons and CAPTCHAs have a text alternative |
| A2 | Every form field has a real label | A `<label>` tied to the input. Not a placeholder alone |
| A3 | Headings use real heading tags, in order | One `h1`, then `h2`, `h3`. Not styled `div`s. No skipped levels |
| A4 | Everything works by keyboard | Tab through the page. Every control is reachable and usable, in a sensible order |
| A5 | Keyboard focus is visible | The focused element has a clear outline |
| A6 | Text contrast is sufficient | 4.5 to 1 for body text, 3 to 1 for large text. Check the real colour pairs |
| A7 | Colour is not the only signal | Errors, required fields and status also use text or an icon |
| A8 | There is a "skip to main content" link | First item in tab order on pages with long navigation |
| A9 | Controls are real elements with names | Links are `<a href>`, buttons are `<button>`. Icon buttons have an accessible name |
| A10 | Text can be resized | Zoom to 200%. Nothing is cut off or overlaps. Zoom is not disabled |
| A11 | The page declares its language and has a specific title | `<html lang>`, and a `<title>` that names the page as well as the site |
| A12 | Nothing moves or flashes without user control | Carousels, autoplay video and animation can be paused |
| A13 | Error messages are announced | The message is tied to its field and focus moves to the first error |

This list covers the common failures. It is not a full WCAG audit. Say so in the report when the user needs compliance.
