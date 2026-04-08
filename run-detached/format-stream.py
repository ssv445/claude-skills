#!/usr/bin/env python3
"""
Format `claude -p --output-format stream-json` as human-readable live output.

Reads newline-delimited JSON events from stdin, writes ANSI-colored text to
stdout. Used by the run-detached skill to give live progress in a tmux pane
instead of the silent-until-done default `text` output mode.

Stdout is flushed after every write so output appears immediately in the
attached tmux pane (and wormhole).
"""
import json
import sys


# ANSI color helpers — keep output self-contained, no deps.
DIM = "\033[90m"
CYAN = "\033[36m"
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
BOLD = "\033[1m"
RESET = "\033[0m"


def flush_print(*args, **kwargs):
    kwargs.setdefault("flush", True)
    print(*args, **kwargs)


def short(value, limit=120):
    """Collapse whitespace and clip for compact tool-call preview."""
    if not isinstance(value, str):
        value = json.dumps(value, ensure_ascii=False, default=str)
    value = " ".join(value.split())
    return value if len(value) <= limit else value[: limit - 1] + "…"


def render_tool_input(name, inp):
    """Show the most useful field for each tool; fall back to compact JSON."""
    if not isinstance(inp, dict):
        return short(inp)
    preferred = {
        "Bash": ("command", "description"),
        "Read": ("file_path",),
        "Write": ("file_path",),
        "Edit": ("file_path",),
        "Glob": ("pattern",),
        "Grep": ("pattern", "path"),
        "WebFetch": ("url",),
        "Skill": ("skill", "args"),
        "Task": ("description",),
    }
    for key in preferred.get(name, ()):
        if key in inp and inp[key]:
            return short(inp[key])
    return short(inp)


def handle_assistant(msg):
    for block in msg.get("content", []) or []:
        btype = block.get("type")
        if btype == "text":
            text = (block.get("text") or "").rstrip()
            if text:
                flush_print(text)
        elif btype == "tool_use":
            name = block.get("name", "?")
            preview = render_tool_input(name, block.get("input"))
            flush_print(f"{CYAN}▸ {name}{RESET} {DIM}{preview}{RESET}")


def handle_user(msg):
    for block in msg.get("content", []) or []:
        if block.get("type") != "tool_result":
            continue
        content = block.get("content", "")
        if isinstance(content, list):
            content = " ".join(
                c.get("text", "") for c in content if isinstance(c, dict)
            )
        preview = short(str(content), limit=200)
        if block.get("is_error"):
            flush_print(f"  {RED}✗{RESET} {DIM}{preview}{RESET}")
        else:
            flush_print(f"  {GREEN}✓{RESET} {DIM}{preview}{RESET}")


def handle_stream_event(event):
    """Partial-message deltas — token-level streaming of assistant text."""
    inner = event.get("event") or {}
    if inner.get("type") != "content_block_delta":
        return
    delta = inner.get("delta") or {}
    if delta.get("type") == "text_delta":
        sys.stdout.write(delta.get("text", ""))
        sys.stdout.flush()


def handle_result(ev):
    subtype = ev.get("subtype", "")
    turns = ev.get("num_turns", "?")
    cost = ev.get("total_cost_usd", 0) or 0
    duration_s = (ev.get("duration_ms") or 0) / 1000
    color = GREEN if subtype == "success" else RED
    flush_print(
        f"\n{color}─── {subtype or 'done'} • {turns} turns • "
        f"{duration_s:.1f}s • ${cost:.4f}{RESET}"
    )
    # Also print the final result text so readers without partial-message
    # streaming still see the answer.
    result_text = ev.get("result")
    if result_text:
        flush_print(f"{BOLD}{result_text}{RESET}")


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            # Not JSON — maybe a startup banner or error. Pass through.
            flush_print(line)
            continue

        t = ev.get("type")

        if t == "system" and ev.get("subtype") == "init":
            model = ev.get("model", "?")
            session_id = (ev.get("session_id") or "")[:8]
            cwd = ev.get("cwd", "")
            flush_print(
                f"{DIM}▶ session {session_id} • model {model} • cwd {cwd}{RESET}"
            )
        elif t == "assistant":
            handle_assistant(ev.get("message") or {})
        elif t == "user":
            handle_user(ev.get("message") or {})
        elif t == "stream_event":
            handle_stream_event(ev)
        elif t == "result":
            handle_result(ev)
        # Unknown event types are ignored silently to keep the pane clean.


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
