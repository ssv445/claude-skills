#!/usr/bin/env python3
"""
run-worker.py — invoke `claude -p` with a prompt file, pipe its stream-json
output through format-stream.py, write a done marker on exit.

Usage: run-worker.py <prompt-file> <formatter-script>

Why Python instead of a shell pipeline: the prompt is arbitrary user text
that may contain quotes, backticks, $, newlines, etc. Python's subprocess
passes the prompt as a literal argv argument — no shell involved — so we
never have to escape anything. This is the fragile bit that kept breaking
when the spawn was a shell command embedded in a tmux `new-session` arg.
"""
import os
import subprocess
import sys


def main():
    if len(sys.argv) != 3:
        print("usage: run-worker.py <prompt-file> <formatter-script>", file=sys.stderr)
        sys.exit(2)

    prompt_file, formatter = sys.argv[1], sys.argv[2]

    try:
        with open(prompt_file, "r", encoding="utf-8") as f:
            prompt = f.read()
    except OSError as e:
        print(f"error: cannot read {prompt_file}: {e}", file=sys.stderr)
        sys.exit(2)

    if not prompt.strip():
        print("error: empty prompt", file=sys.stderr)
        sys.exit(2)

    # Pipe claude → formatter. The formatter's stdout is inherited from us,
    # which is the tmux pane tty, so its output streams straight to the pane.
    formatter_proc = subprocess.Popen(
        [sys.executable, formatter],
        stdin=subprocess.PIPE,
    )

    claude_cmd = [
        "claude",
        "-p",
        prompt,
        "--output-format", "stream-json",
        "--verbose",
        "--dangerously-skip-permissions",
    ]
    claude_proc = subprocess.Popen(
        claude_cmd,
        stdout=formatter_proc.stdin,
        stderr=subprocess.STDOUT,  # merge stderr so errors flow through formatter
    )

    # Close our copy of the pipe so the formatter sees EOF when claude exits.
    formatter_proc.stdin.close()

    claude_rc = claude_proc.wait()
    formatter_proc.wait()

    # Drop a done marker for the caller's poll loop. Relying on `tmux
    # has-session` alone is flaky — the pane's shell can linger (a stray
    # interactive process, a shell that didn't honor `; exit`, etc.) long
    # after claude itself has finished. A marker file written from the
    # worker process guarantees a crisp DONE signal.
    marker = os.environ.get("WORKER_DONE_MARKER")
    if marker:
        try:
            with open(marker, "w", encoding="utf-8") as f:
                f.write(f"{claude_rc}\n")
        except OSError:
            pass  # best-effort; the poll loop also has has-session as fallback

    sys.exit(claude_rc)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
