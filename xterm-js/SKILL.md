---
name: xterm-js
version: 1.0.0
description: |
  Comprehensive best practices for building terminal applications with xterm.js,
  React, and WebSockets. Captures critical patterns from debugging production
  terminal implementations including state management, WebSocket communication,
  React hooks integration, and terminal lifecycle management.
  Use this skill when building or debugging xterm.js terminals, integrating with
  React hooks, implementing WebSocket-based terminal I/O, or managing tmux backends.
allowed-tools:
  - Read
  - Grep
  - Glob
---

# xterm.js Best Practices

Production-tested patterns for xterm.js + React + WebSocket terminals.

## 1. Refs and State Management

**Clear refs when state changes.** Refs persist across state changes — clearing state without clearing refs causes stale-ref bugs.

```ts
// CORRECT
if (terminal.agentId) clearProcessedAgentId(terminal.agentId) // Clear ref
updateTerminal(id, { agentId: undefined }) // Clear state
```

- State (Zustand/Redux) = what terminal is
- Refs (useRef) = what we've processed
- Common failure: detach/reattach where same agentId returns but ref says "already processed"

## 2. WebSocket Message Types

**Know your destructive operations.** Similar-looking message types often have very different semantics:

- `type: 'disconnect'` — graceful disconnect, keeps session alive
- `type: 'close'` — **FORCE CLOSE and KILL session** (destructive!)

```ts
// WRONG - kills tmux session!
wsRef.current.send(JSON.stringify({ type: 'close', terminalId: terminal.agentId }))

// CORRECT - for detach, use API endpoint only
await fetch(`/api/tmux/detach/${sessionName}`, { method: 'POST' })
// Don't send WS message - let PTY disconnect naturally
```

Read backend code to understand each message type.

## 3. React Hooks — Shared Refs

**Identify shared refs before extracting hooks.** Hook creating its own ref when parent already has one = two refs, broken state.

```ts
// WRONG - creates NEW ref
export function useWebSocketManager(...) {
  const wsRef = useRef<WebSocket | null>(null)
}

// RIGHT - uses shared ref from parent
export function useWebSocketManager(
  wsRef: React.MutableRefObject<WebSocket | null>,
  ...
) {}
```

Before extracting hooks:
- Map all refs — which components use which
- Shared ref → pass as parameter, don't create internally
- Test with real usage immediately after extraction
- Extract one hook at a time, test, commit

## 4. Terminal Initialization

**xterm.js requires non-zero container dimensions.** Use visibility-based hiding, not `display: none`.

```tsx
// WRONG - prevents xterm init
<div style={{ display: isActive ? 'block' : 'none' }}><Terminal /></div>

// CORRECT - all terminals get dimensions
<div style={{
  position: 'absolute', top: 0, left: 0, right: 0, bottom: 0,
  visibility: isActive ? 'visible' : 'hidden',
  zIndex: isActive ? 1 : 0,
}}><Terminal /></div>
```

Tab-based UIs: all terminals stacked via absolute positioning, `visibility` toggles active.

## 5. useEffect Dependencies for Initialization

**Early returns need corresponding dependencies.** If useEffect checks ref and returns early, include `ref.current` in deps so it re-runs when available.

```ts
// WRONG - runs once, may return early forever
useEffect(() => {
  if (!terminalRef.current) return
}, [])

// CORRECT - re-runs when ref changes
useEffect(() => {
  if (!terminalRef.current) return
}, [terminalRef.current])
```

Wait for ALL refs before setup:
```ts
useEffect(() => {
  if (!terminalRef.current?.parentElement || !xtermRef.current || !fitAddonRef.current) return
}, [terminalRef.current, xtermRef.current, fitAddonRef.current])
```

## 6. Session Naming & Reconnection

**Use existing `sessionName` for reconnection.** Don't generate new one.

```ts
// CORRECT
const config = { sessionName: terminal.sessionName, resumable: true, useTmux: true }

// WRONG
const config = { sessionName: generateNewSessionName() }
```

Tmux sessions have stable names — use as source of truth.

## 7. Multi-Window Terminal Management

**Backend output routing must use ownership tracking.** Never broadcast terminal output to all clients.

```ts
// Backend: track ownership
const terminalOwners = new Map() // terminalId -> Set<WebSocket>

terminalRegistry.on('output', (terminalId, data) => {
  const owners = terminalOwners.get(terminalId)
  owners.forEach(client => client.send(message))
})
```

Broadcasting causes escape sequence corruption (DSR sequences) in wrong windows.

Frontend: filter terminals by `windowId` before adding to agents.

## 8. Testing After Refactoring

TypeScript compilation != working code. After refactoring:

```bash
npm run build           # TypeScript
# Then manually test:
# Spawn terminal, type in it (WS), resize window (ResizeObserver),
# spawn TUI (complex ANSI), check browser console + backend logs
npm test
```

Don't batch multiple hook extractions. Extract one → test → commit.

## 9. Debugging — Log Before Fix

Add diagnostic logging before attempting fixes:

```ts
console.log('[useWebSocketManager] Received terminal-spawned:', {
  agentId: message.data.id, requestId: message.requestId,
  sessionName: message.data.sessionName, pendingSpawnsSize: pendingSpawns.current.size
})
```

Shows which code path executes, reveals data mismatches.

## 10. Multi-Step State Changes

When state change affects multiple systems, update all:

- Zustand state (terminal properties)
- Refs (processedAgentIds, pending spawns)
- WebSocket (if needed)
- Event listeners
- localStorage (if using persist)

**Detach example:**
```ts
await fetch(`/api/tmux/detach/${sessionName}`, { method: 'POST' }) // 1. API
if (terminal.agentId) clearProcessedAgentId(terminal.agentId)       // 2. Clear ref
updateTerminal(id, { status: 'detached', agentId: undefined })      // 3. Update state
```

## 11. Tmux Split Terminals & EOL Conversion

**Disable EOL conversion for tmux sessions.** Multiple xterm instances sharing tmux session with `convertEol: true` = output corruption.

Problem: each xterm converts `\n` → `\r\n` independently on same tmux output → text bleeding, misaligned splits.

```ts
const isTmuxSession = !!agent.sessionName || shouldUseTmux;

const xtermOptions = {
  convertEol: !isTmuxSession, // Only convert for regular shells
  scrollback: isTmuxSession ? 0 : 10000,
  windowsMode: false,
};
```

Tmux manages its own terminal protocol. Multiple xterm instances must handle output identically.

## 12. Resize & Output Coordination

### Don't resize during active output
Resizing (especially tmux) sends SIGWINCH → full screen redraw. During streaming = "redraw storms."

```ts
const lastOutputTimeRef = useRef(0)
const OUTPUT_QUIET_PERIOD = 500

const handleOutput = (data: string) => {
  lastOutputTimeRef.current = Date.now()
  xterm.write(data)
}

const safeToResize = () => Date.now() - lastOutputTimeRef.current >= OUTPUT_QUIET_PERIOD
```

### Two-step resize trick for tmux
Tmux sometimes won't rewrap text after dimension changes. Force full redraw:

```ts
const triggerResizeTrick = (force = false) => {
  if (!xtermRef.current || !fitAddonRef.current) return
  const { cols, rows } = xtermRef.current

  if (!force && !safeToResize()) {
    setTimeout(() => triggerResizeTrick(), OUTPUT_QUIET_PERIOD)
    return
  }

  // Step 1: shrink by 1 col (SIGWINCH)
  xtermRef.current.resize(cols - 1, rows)
  sendResize(cols - 1, rows)

  // Step 2: restore (another SIGWINCH)
  setTimeout(() => {
    xtermRef.current.resize(cols, rows)
    sendResize(cols, rows)
  }, 100)
}
```

### Clear write queue after resize trick
Two-step resize causes two tmux redraws. Clear queue instead of flushing — flushing writes duplicate content:

```ts
// After resize trick completes:
writeQueueRef.current = [] // DON'T flush — clear!
```

### Output guard on reconnection
Reconnecting to active tmux session (e.g., page refresh during streaming) — buffer initial output to prevent escape sequence corruption:

```ts
const isOutputGuardedRef = useRef(true)
const outputGuardBufferRef = useRef<string[]>([])

const handleOutput = (data: string) => {
  if (isOutputGuardedRef.current) {
    outputGuardBufferRef.current.push(data)
    return
  }
  xterm.write(data)
}

// Lift guard after 1000ms, flush buffer, force resize trick
useEffect(() => {
  const timer = setTimeout(() => {
    isOutputGuardedRef.current = false
    if (outputGuardBufferRef.current.length > 0) {
      xtermRef.current?.write(outputGuardBufferRef.current.join(''))
      outputGuardBufferRef.current = []
    }
    setTimeout(() => triggerResizeTrick(true), 100)
  }, 1000)
  return () => clearTimeout(timer)
}, [])
```

### Cancel deferred operations on new resize
Multiple resize events in quick succession create orphaned timeouts:

```ts
const deferredResizeTrickRef = useRef<NodeJS.Timeout | null>(null)
const deferredFitTerminalRef = useRef<NodeJS.Timeout | null>(null)

const handleResize = () => {
  if (deferredResizeTrickRef.current) clearTimeout(deferredResizeTrickRef.current)
  if (deferredFitTerminalRef.current) clearTimeout(deferredFitTerminalRef.current)
  deferredFitTerminalRef.current = setTimeout(() => {
    deferredFitTerminalRef.current = null
    fitTerminal()
  }, 150)
}
```

## 13. Tmux-Specific Resize Strategy

**Skip ResizeObserver for tmux sessions.** Tmux manages own pane dimensions. ResizeObserver on container changes (focus, clicks) causes unnecessary SIGWINCH.

```ts
useEffect(() => {
  if (useTmux) return // Don't set up observer
  const resizeObserver = new ResizeObserver((entries) => { /* handle */ })
  resizeObserver.observe(containerRef.current)
  return () => resizeObserver.disconnect()
}, [useTmux])
```

**Why tmux is different:**
- Regular shells: each xterm owns its PTY, resize freely
- Tmux: single PTY, tmux manages internal panes, SIGWINCH redraws ALL panes

**For tmux:**
- DO resize: initial connection, actual browser window resize
- DON'T resize: focus, tab switch, container changes

## Resources

- **Unicode11 Addon** — Fix emoji/Unicode width issues
- **Mouse Coordinate Transformation** — Handle CSS zoom/transform on terminal containers
- **Tmux EOL Fix Gist** — https://gist.github.com/GGPrompts/7d40ea1070a45de120261db00f1d7e3a
