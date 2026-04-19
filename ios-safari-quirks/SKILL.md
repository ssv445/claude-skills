---
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

Expert consultant for iOS Safari web dev quirks. Use this reference for mobile Safari debugging and cross-browser issues.

## Critical Context

**All iOS browsers are WebKit.** Chrome/Firefox/Edge on iOS = thin shells over Safari engine. UA strings lie. Feature-detect, never UA-sniff.

```ts
const IS_IOS = /iPad|iPhone|iPod/.test(navigator.userAgent)
  || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1); // iPadOS 13+
```

---

## 1. Touch & Gesture Events

### 1.1 `{ capture: true }` required to intercept before libraries
Libraries like xterm.js call `stopPropagation()`. Bubble-phase listeners never fire.
```ts
element.addEventListener('touchstart', handler, { capture: true, passive: true });
```

### 1.2 `{ passive: false }` required for `preventDefault()` in touchmove
iOS 11.3+ makes root-level touch listeners passive by default. React synthetic `onTouchMove` always passive on iOS. Use native `addEventListener`:
```ts
element.addEventListener('touchmove', (e) => {
  e.preventDefault();
}, { passive: false });
```

### 1.3 Click events don't fire on non-interactive elements
`<div>`/`<span>` need `cursor: pointer` CSS or `onclick` attribute for click events.

### 1.4 Long-press triggers native context menu
iOS text selection loupe fires before custom long-press handlers. Use `MOVE_THRESHOLD` (~10px) to cancel long press on finger move.

### 1.5 One-finger swipe = scroll
Two-finger scroll is macOS trackpad only. Mobile = one finger. Track `touchstart`/`touchmove` delta.

---

## 2. Viewport & Layout

### 2.1 `100vh` wrong when toolbar visible
`vh` uses collapsed-toolbar height. Use `100dvh` (iOS 15.4+):
```css
height: 100dvh;
@supports not (height: 100dvh) { height: 100vh; }
```

### 2.2 Virtual keyboard does NOT resize `window.innerHeight`
Keyboard overlaps viewport. Use `window.visualViewport`:
```ts
const vv = window.visualViewport!;
const keyboardHeight = Math.max(0, window.innerHeight - vv.height);
vv.addEventListener('resize', onResize);
```
Translate content up by `keyboardHeight` (avoid layout reflow).

### 2.3 Safe area insets (notch, home indicator)
Requires `viewport-fit=cover` in meta tag:
```html
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
```
```css
padding-bottom: env(safe-area-inset-bottom);
```

### 2.4 `position: fixed` stutters during scroll momentum
Use `position: sticky` where possible. Body scroll lock needs both `overflow: hidden` AND `position: fixed` on `<body>`.

### 2.5 `overscroll-behavior: none` not supported before Safari 16
Use `-webkit-overflow-scrolling: touch` on inner containers for older iOS.

---

## 3. Audio & Video

### 3.1 Autoplay blocked without user gesture
All audio (including Web Audio API) requires user gesture. Muted video can autoplay. Unmuted blocked.
```ts
document.addEventListener('touchend', () => {
  new AudioContext().resume();
}, { once: true });
```

### 3.2 AudioContext "interrupted" in background
Not "suspended" — different state. Resume on `visibilitychange`:
```ts
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && ctx.state !== 'running') ctx.resume();
});
```

### 3.3 `playsinline` required for inline video on iPhone
Without it, video goes fullscreen. `<video playsinline muted autoplay>`.

---

## 4. Clipboard

### 4.1 `navigator.clipboard.readText()` ALWAYS throws
No permission prompt — unconditional `NotAllowedError`. Fall back to visible `<textarea>` for native paste.

### 4.2 User activation expires across `await`
Clipboard access must be synchronous in gesture handler. Any `await` burns activation.

### 4.3 `clipboard.write()` expects Promise in ClipboardItem
```ts
new ClipboardItem({ 'image/png': fetch(url).then(r => r.blob()) }) // Promise, not Blob
```

---

## 5. Storage

### 5.1 ITP deletes storage after 7 days inactivity
localStorage, IndexedDB, SW registrations — deleted after 7 days (tracker-classified) or 30 days (others). Home Screen PWAs exempt.

### 5.2 Private Browsing throws on localStorage write
`QuotaExceededError` immediately (quota=0). Wrap in try/catch.

### 5.3 IndexedDB in Private Browsing is ephemeral
Available but cleared on session end. Concurrent access bugs in PWA mode.

---

## 6. Network

### 6.1 WebSocket killed on background
Socket may appear OPEN but messages silently dropped. Reconnect on `visibilitychange`:
```ts
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && ws.readyState !== WebSocket.OPEN) reconnect();
});
```
Use exponential backoff.

### 6.2 `navigator.sendBeacon()` unreliable on page unload
Use `pagehide` (more reliable than `unload`) but even that isn't 100%.

---

## 7. Input & Keyboard

### 7.1 Keyboard only appears for sync `focus()` in user gesture
`focus()` inside `setTimeout`, after `await`, or in `rAF` = no keyboard. Must be synchronous. xterm.js hidden textarea won't trigger keyboard — use real visible `<input>`.

### 7.2 Font size < 16px triggers auto-zoom on input focus
```css
input, textarea, select { font-size: 16px; }
```
Or `maximum-scale=1` in viewport meta (disables pinch-zoom — accessibility concern).

### 7.3 Disable autocorrect/autocapitalize explicitly
For code/terminal inputs:
```tsx
<input autoCapitalize="none" autoCorrect="off" autoComplete="off" spellCheck={false} />
```

### 7.4 `onKeyDown` unreliable during IME composition
During autocorrect, `keydown` fires with `e.key === "Unidentified"`. Use `onInput`:
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
Without it, scroll stops immediately on finger lift. Deprecated but needed for older iOS.

### 8.2 `overflow: hidden` on body doesn't prevent iOS scroll
Need `position: fixed` on body too for full scroll lock.

---

## 9. PWA Specific

### 9.1 No Fullscreen API — use standalone PWA mode
`requestFullscreen()` not implemented. Detect standalone: `window.matchMedia('(display-mode: standalone)').matches` or `navigator.standalone`.

### 9.2 Push notifications only in standalone mode (iOS 16.4+)
Web push doesn't work in regular Safari tabs. Must be Home Screen app + user gesture for permission.

### 9.3 External links break standalone mode
Navigation to different origin opens Safari. Intercept links, use `pushState` for in-app nav.

### 9.4 `apple-touch-icon` required (manifest icons ignored)
iOS ignores Web App Manifest `icons`. Use `<link rel="apple-touch-icon">`.

### 9.5 Status bar via meta tag
`apple-mobile-web-app-status-bar-style`: `default` (white), `black`, `black-translucent` (content under status bar).

---

## 10. Performance

### 10.1 rAF throttled to 30fps in Low Power Mode
Also throttled in cross-origin iframes. Use `performance.now()` deltas, not rAF for timing.

### 10.2 Background tab JS paused aggressively
More aggressive than Chrome. `setTimeout`/`setInterval` throttled to 1s min. Use `visibilitychange` to pause/resume.

---

## 11. Security & Permissions

### 11.1 `permissions.query()` doesn't support mic/camera
Throws or returns unhelpful value. Fall through to `getUserMedia()`.

### 11.2 Camera/mic permissions re-prompted on hash change (PWA bug)
WebKit bug #215884. Use path-based navigation, not hash-based, in PWAs.

### 11.3 `Notification.requestPermission()` requires user gesture
Silently ignored outside click/touchend handler.

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
Codepoints like U+23F4-U+23FA render as colorful emoji instead of monochrome.
Fix: append U+FE0E (Variation Selector 15):
```ts
if (IS_IOS) text = text.replace(/[\u23F4-\u23FA\u2733\u276F]/g, '$&\uFE0E');
```

### 12.2 WebGL context lost on background
iOS 16-17 regression. Listen and fall back:
```ts
webglAddon.onContextLoss(() => webglAddon.dispose());
```

### 12.3 Font must load before canvas measurement
Canvas renderers measure char widths at `open()`. Wait:
```ts
await document.fonts.load('14px "MyFont"');
```
Use `font-display: block` in `@font-face`.

---

## 13. Date & Intl

### 13.1 `new Date("2024-01-15 10:30:00")` returns Invalid Date
Safari requires ISO 8601 `T` separator:
```ts
new Date(str.replace(' ', 'T'));
```

---

## 14. File & Blob

### 14.1 `<a download>` ignored for blob URLs
Use data URIs or `navigator.share({ files })` (iOS 12.2+).

### 14.2 `input.click()` blocked after `await`
File picker must be synchronous in user gesture.

### 14.3 File picker cancel fires no event
Use `window.focus` listener to detect dismissal:
```ts
window.addEventListener('focus', () => {
  setTimeout(() => element.focus(), 300);
}, { once: true });
```

---

## 15. Fullscreen & Orientation

### 15.1 Fullscreen API not available
Only standalone PWA mode.

### 15.2 `screen.orientation.lock()` not supported
Orientation control = native apps only.

---

## 16. Speech Recognition

### 16.1 `webkitSpeechRecognition` differs from Chrome
- Returns single growing text result (not list)
- May require manual `stop()` after timeout
- Chrome on iOS doesn't support it at all (Apple blocks it)

Track `finalizedLength` to avoid re-appending partial results.

---

## 17. User Activation (Cross-Cutting)

iOS Safari has **strictest user activation model** of any browser. These APIs require synchronous calls within user gesture handler — any `await` burns activation:

- `navigator.clipboard.readText()` / `.write()`
- `window.open()`
- `input[type=file].click()`
- `Notification.requestPermission()`
- `AudioContext.resume()`

**Pattern:** Do activation-dependent action FIRST (synchronously), async work after.

---

## Severity Table

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

## Resources

1. **[Can I Use](https://caniuse.com)** — Browser support tables. Filter "Safari on iOS".
2. **[WebKit Bug Tracker](https://bugs.webkit.org)** — Search when behavior feels like bug, not missing feature.
3. **[MDN Browser Compatibility](https://developer.mozilla.org/en-US/docs/Web/API)** — Every API page has Safari/iOS Safari support table.
4. **[WebKit Blog](https://webkit.org/blog/)** — New features, API restrictions (ITP, autoplay, activation).
5. **[Apple Safari Resources](https://developer.apple.com/safari/resources/)** — Release notes, known issues per iOS version.
