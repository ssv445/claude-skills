first file---
name: ios-safari-quirks
version: 1.0.0
description: |
  iOS Safari JavaScript quirks reference. Use when building or debugging web apps
  that must work on iOS Safari (mobile). Covers 55+ documented differences from
  desktop Chrome/Safari including: touch events, viewport/keyboard, clipboard API,
  storage (ITP), WebSocket backgrounding, PWA limitations, date parsing, file input,
  rendering (emoji/WebGL/fonts), and user activation requirements.
  Invoke this skill when writing code that targets mobile Safari or when debugging
  iOS-specific issues.
allowed-tools:
  - Read
  - Grep
  - Glob
---

# iOS Safari JavaScript Quirks Reference

You are an expert consultant on iOS Safari web development quirks. When the user is writing code for mobile web, debugging iOS-specific issues, or asking about Safari differences, use this reference to provide accurate, battle-tested solutions.

## Critical Context

**All iOS browsers are WebKit.** Chrome, Firefox, Edge on iOS are thin shells over Safari's engine. UA strings lie. Feature-detect, never UA-sniff for engine.

**Reliable iOS detection:**
```ts
const IS_IOS = /iPad|iPhone|iPod/.test(navigator.userAgent)
  || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1); // iPadOS 13+
```

---

## 1. Touch & Gesture Events

### 1.1 `{ capture: true }` required to intercept events before libraries
Libraries like xterm.js call `stopPropagation()` on touch events. Bubble-phase listeners never fire.
```ts
element.addEventListener('touchstart', handler, { capture: true, passive: true });
```

### 1.2 `{ passive: false }` required for `preventDefault()` in touchmove
iOS 11.3+ makes root-level touch listeners passive by default. React's synthetic `onTouchMove` is always passive on iOS. Use native `addEventListener`:
```ts
element.addEventListener('touchmove', (e) => {
  e.preventDefault(); // Only works with passive: false
}, { passive: false });
```

### 1.3 Click events don't fire on non-interactive elements
`<div>` and `<span>` need `cursor: pointer` CSS or an `onclick` attribute to receive click events on iOS.

### 1.4 Long-press triggers native context menu
iOS's native text selection loupe fires before custom long-press handlers. Use a `MOVE_THRESHOLD` (~10px) to cancel long press if the finger moves, and manage selection mode explicitly.

### 1.5 One-finger swipe = scroll (not two-finger)
Two-finger scroll is macOS trackpad only. Mobile is one-finger. Track `touchstart`/`touchmove` delta accordingly.

---

## 2. Viewport & Layout

### 2.1 `100vh` is wrong when toolbar is visible
`vh` uses collapsed-toolbar height. Content overflows when the Safari toolbar is visible.
**Fix:** Use `100dvh` (dynamic viewport height, iOS 15.4+):
```css
height: 100dvh;
/* Fallback: */ height: 100vh;
@supports (height: 100dvh) { height: 100dvh; }
```

### 2.2 Virtual keyboard does NOT resize `window.innerHeight`
The keyboard overlaps the viewport. `innerHeight` stays the same.
**Fix:** Use `window.visualViewport`:
```ts
const vv = window.visualViewport!;
const keyboardHeight = Math.max(0, window.innerHeight - vv.height);
vv.addEventListener('resize', onResize);
```
Then translate content up by `keyboardHeight` (avoid layout reflow).

### 2.3 Safe area insets (notch, home indicator)
Requires `viewport-fit=cover` in meta tag, then use CSS `env()`:
```css
padding-bottom: env(safe-area-inset-bottom);
```
```html
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
```

### 2.4 `position: fixed` stutters during scroll momentum
Fixed elements jump during iOS rubber-band scroll. Use `position: sticky` where possible.
For body scroll lock: both `overflow: hidden` AND `position: fixed` on `<body>`.

### 2.5 `overscroll-behavior: none` not supported before Safari 16
Use `-webkit-overflow-scrolling: touch` on inner containers for older iOS.

---

## 3. Audio & Video

### 3.1 Autoplay blocked without user gesture
All audio (including Web Audio API) requires a user gesture (`touchend`, `click`). Muted video can autoplay. Unmuted video is blocked.
```ts
document.addEventListener('touchend', () => {
  new AudioContext().resume();
}, { once: true });
```

### 3.2 AudioContext becomes "interrupted" in background
Not "suspended" — a different state. Resume on `visibilitychange`:
```ts
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && ctx.state !== 'running') ctx.resume();
});
```

### 3.3 `playsinline` required for inline video on iPhone
Without it, video goes fullscreen. `<video playsinline muted autoplay>`.

---

## 4. Clipboard

### 4.1 `navigator.clipboard.readText()` ALWAYS throws on iOS Safari
No permission prompt — unconditionally `NotAllowedError`. Fall back to a visible `<textarea>` where the user can paste natively.

### 4.2 User activation expires across `await`
Clipboard access must be synchronous in the gesture handler. Any `await` before the clipboard call burns the activation.

### 4.3 `clipboard.write()` expects a Promise in ClipboardItem
```ts
new ClipboardItem({ 'image/png': fetch(url).then(r => r.blob()) }) // Promise, not Blob
```

---

## 5. Storage

### 5.1 ITP deletes storage after 7 days of inactivity
localStorage, IndexedDB, Service Worker registrations — all deleted after 7 days for tracker-classified domains, 30 days for others. Home Screen PWAs are exempt.

### 5.2 Private Browsing throws on localStorage write
`QuotaExceededError` immediately (quota is 0). Wrap in try/catch.

### 5.3 IndexedDB in Private Browsing is ephemeral
Available but cleared when session ends. Concurrent access bugs in PWA mode.

---

## 6. Network

### 6.1 WebSocket killed when app backgrounds
Socket object may appear OPEN but messages are silently dropped. Reconnect on `visibilitychange`:
```ts
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && ws.readyState !== WebSocket.OPEN) {
    reconnect();
  }
});
```
Use exponential backoff for reconnection.

### 6.2 `navigator.sendBeacon()` unreliable on page unload
Use `pagehide` (more reliable than `unload`) but even that isn't 100%.

---

## 7. Input & Keyboard

### 7.1 Keyboard only appears for sync `focus()` in user gesture
`focus()` inside `setTimeout`, after `await`, or in `rAF` shows no keyboard. Must be synchronous in the gesture handler. xterm.js's hidden textarea won't trigger the keyboard — use a real visible `<input>`.

### 7.2 Font size < 16px triggers auto-zoom on input focus
```css
input, textarea, select { font-size: 16px; }
```
Or use `maximum-scale=1` in viewport meta (disables pinch-zoom — accessibility concern).

### 7.3 Disable autocorrect/autocapitalize explicitly
iOS aggressively autocorrects. For code/terminal inputs:
```tsx
<input autoCapitalize="none" autoCorrect="off" autoComplete="off" spellCheck={false} />
```

### 7.4 `onKeyDown` unreliable during IME composition
During iOS autocorrect composition, `keydown` fires with `e.key === "Unidentified"`. Use `onInput` to capture actual text changes:
```ts
onInput={(e) => {
  const text = (e.target as HTMLInputElement).value;
  send(text);
  (e.target as HTMLInputElement).value = '';
}}
```

---

## 8. CSS Issues

### 8.1 `-webkit-overflow-scrolling: touch` for momentum scroll
Without it, scroll containers stop immediately on finger lift. Deprecated but still needed for older iOS.

### 8.2 `overflow: hidden` on body doesn't prevent iOS scroll
Need `position: fixed` on body too for full scroll lock.

---

## 9. PWA Specific

### 9.1 No Fullscreen API — use standalone PWA mode
`requestFullscreen()` is not implemented. Show "Add to Home Screen" hint instead.
Detect standalone: `window.matchMedia('(display-mode: standalone)').matches` or `navigator.standalone`.

### 9.2 Push notifications only in standalone mode (iOS 16.4+)
Web push doesn't work in regular Safari tabs. Must be Home Screen app + user gesture for `Notification.requestPermission()`.

### 9.3 External links break standalone mode
Navigation to different origin opens Safari, breaking the PWA. Intercept links and use `pushState` for in-app navigation.

### 9.4 `apple-touch-icon` required (manifest icons ignored)
iOS ignores Web App Manifest `icons`. Use `<link rel="apple-touch-icon">` in HTML.

### 9.5 Status bar controlled by meta tag
`apple-mobile-web-app-status-bar-style`: `default` (white), `black`, `black-translucent` (content under status bar).

---

## 10. Performance

### 10.1 rAF throttled to 30fps in Low Power Mode
Also throttled in cross-origin iframes. Don't rely on rAF for timing — use `performance.now()` deltas.

### 10.2 Background tab JS paused aggressively
More aggressive than Chrome. `setTimeout`/`setInterval` throttled to 1s minimum. Use `visibilitychange` to pause/resume.

---

## 11. Security & Permissions

### 11.1 `permissions.query()` doesn't support mic/camera
Throws or returns unhelpful value. Fall through to `getUserMedia()` to test permission.

### 11.2 Camera/mic permissions re-prompted on hash change (PWA bug)
WebKit bug #215884. Use path-based navigation, not hash-based, in PWAs.

### 11.3 `Notification.requestPermission()` requires user gesture
Silently ignored if called outside click/touchend handler.

### 11.4 `window.open()` blocked after `await`
Open window synchronously first, redirect later:
```ts
const win = window.open('about:blank', '_blank');
const url = await fetchUrl();
if (win) win.location.href = url;
```

---

## 12. Rendering

### 12.1 Unicode symbols render as color Apple emoji
Codepoints like U+23F4-U+23FA render as colorful emoji instead of monochrome text.
**Fix:** Append U+FE0E (Variation Selector 15) on iOS:
```ts
if (IS_IOS) text = text.replace(/[\u23F4-\u23FA\u2733\u276F]/g, '$&\uFE0E');
```

### 12.2 WebGL context lost when app backgrounds
iOS 16-17 regression. Listen for context loss and fall back to DOM renderer:
```ts
webglAddon.onContextLoss(() => webglAddon.dispose());
```

### 12.3 Font must load before canvas measurement
Canvas-based renderers measure character widths at `open()` time. Wait for font:
```ts
await document.fonts.load('14px "MyFont"');
// Now safe to open canvas-based renderer
```
Use `font-display: block` in `@font-face`.

---

## 13. Date & Intl

### 13.1 `new Date("2024-01-15 10:30:00")` returns Invalid Date
Safari requires ISO 8601 `T` separator. Chrome/Firefox accept spaces.
```ts
new Date(str.replace(' ', 'T'));
```

---

## 14. File & Blob

### 14.1 `<a download>` ignored for blob URLs
Use data URIs or `navigator.share({ files })` (iOS 12.2+).

### 14.2 `input.click()` blocked after `await`
File picker must be triggered synchronously in user gesture. No async before `.click()`.

### 14.3 File picker cancel fires no event
Use `window.focus` listener to detect picker dismissal (including cancel):
```ts
window.addEventListener('focus', () => {
  setTimeout(() => element.focus(), 300);
}, { once: true });
```

---

## 15. Fullscreen & Orientation

### 15.1 Fullscreen API not available
Not implemented on iOS. Only option is standalone PWA mode.

### 15.2 `screen.orientation.lock()` not supported
Orientation can only be controlled by native apps.

---

## 16. Speech Recognition

### 16.1 `webkitSpeechRecognition` differs from Chrome
- Returns single growing text result (not a list)
- May require manual `stop()` after timeout
- Chrome on iOS doesn't support Speech Recognition at all (Apple blocks it)

Track `finalizedLength` to avoid re-appending partial results.

---

## 17. User Activation (Cross-Cutting)

iOS Safari has the **strictest user activation model** of any browser. These APIs all require synchronous calls within a user gesture handler — any `await` burns the activation:

- `navigator.clipboard.readText()` / `.write()`
- `window.open()`
- `input[type=file].click()`
- `Notification.requestPermission()`
- `AudioContext.resume()`
- `element.requestFullscreen()` (not even available on iOS, but the pattern applies)

**Pattern:** Do the activation-dependent action FIRST (synchronously), then do async work after.

---

## Quick Reference: Severity Table

| Quirk | Severity | Category |
|---|---|---|
| `100vh` wrong with toolbar | HIGH | Viewport |
| Keyboard doesn't resize innerHeight | HIGH | Viewport |
| `clipboard.readText()` always throws | HIGH | Clipboard |
| User activation expires across await | HIGH | Activation |
| WebSocket killed in background | HIGH | Network |
| Keyboard needs sync focus() | HIGH | Input |
| Font must load before canvas | HIGH | Rendering |
| Date space separator = NaN | HIGH | Date |
| File input click() after await blocked | HIGH | File |
| `{ capture: true }` for touch | HIGH | Touch |
| `{ passive: false }` for preventDefault | HIGH | Touch |
| ITP 7-day storage deletion | MEDIUM | Storage |
| Auto-zoom below 16px | MEDIUM | Input |
| Emoji as color instead of text | MEDIUM | Rendering |
| WebGL context lost on background | MEDIUM | Rendering |
| Safe area insets | MEDIUM | Viewport |
| position: fixed stutters | MEDIUM | CSS |
| PWA push only in standalone | MEDIUM | PWA |
| blob download attribute ignored | MEDIUM | File |

---

## Where to Find More

These are the go-to resources for looking up specific iOS Safari compatibility details:

1. **[Can I Use](https://caniuse.com)** — Browser support tables for every web API. Filter by "Safari on iOS" to see exactly which version added support. The best first stop for "does iOS Safari support X?"

2. **[WebKit Bug Tracker (Bugzilla)](https://bugs.webkit.org)** — The official bug tracker for the WebKit engine. Search here when you hit a behavior that feels like a bug rather than a missing feature. Many iOS-specific issues are filed and tracked here.

3. **[MDN Web Docs — Browser Compatibility](https://developer.mozilla.org/en-US/docs/Web/API)** — Every API page on MDN has a "Browser compatibility" table at the bottom showing Safari/iOS Safari support with version numbers and known caveats.

4. **[WebKit Blog](https://webkit.org/blog/)** — Official blog from the WebKit team. Announces new Safari features, explains API restrictions (like ITP storage limits, autoplay policies, user activation requirements), and documents intentional behavior differences.

5. **[Apple Developer — Safari Resources](https://developer.apple.com/safari/resources/)** — Apple's official Safari documentation including release notes per iOS version, known issues, and Safari Web Extensions guides. Check here for "what changed in Safari 18" type questions.
