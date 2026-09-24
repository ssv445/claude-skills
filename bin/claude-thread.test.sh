#!/bin/bash
# Tests for claude-thread's session bookkeeping. Runs against an isolated HOME,
# never touches ~/.claude-thread. Usage: bin/claude-thread.test.sh [wrapper-path]
#
# Every case here failed at least once for real: A and D are the restart bug
# (the session you were working in loses to an idle one), C/E-H are the Zed
# thread binding and the parking that keeps restored tabs from launching claude.
set -u
WRAPPER="${1:-$(dirname "$0")/claude-thread}"
A=aaaaaaaa-0000-0000-0000-000000000001
B=bbbbbbbb-0000-0000-0000-000000000002

pass=0; fail=0
check() { # <name> <expected> <got>
  if [ "$2" = "$3" ]; then echo "  PASS  $1"; pass=$((pass+1))
  else echo "  FAIL  $1 — expected '$2', got '$3'"; fail=$((fail+1)); fi
}

# ── session bookkeeping (state()) ──────────────────────────────────────────
state_tests() {
  local SB; SB=$(mktemp -d); export HOME="$SB/home"
  local PROJ="$HOME/.claude/projects/-tmp-proj"
  mkdir -p "$PROJ" "$HOME/.claude-thread"
  awk '/^state\(\) \{$/,/^\}$/' "$WRAPPER" > "$SB/state.sh"
  # shellcheck disable=SC1090
  . "$SB/state.sh"

  seed() { # <uuid> <last_used_age_sec> <mtime_age_sec>
    : > "$PROJ/$1.jsonl"
    python3 - "$PROJ/$1.jsonl" "$3" <<'EOF'
import os, sys, time
t = time.time() - float(sys.argv[2])
os.utime(sys.argv[1], (t, t))
EOF
    python3 - "$1" "$2" <<'EOF'
import json, os, sys, time
p = os.path.expanduser("~/.claude-thread/state.json")
st = json.load(open(p)) if os.path.exists(p) else {}
st.setdefault("sessions", {})[sys.argv[1]] = {
    "cwd": "/tmp/proj", "status": "ended", "pid": 999999,
    "last_used": time.time() - float(sys.argv[2]), "started": 0}
json.dump(st, open(p, "w"), indent=2)
EOF
  }
  # claim() mutates last_used, so restore a baseline between cases — otherwise
  # they contaminate each other and the later ones prove nothing
  baseline() { cp "$HOME/.claude-thread/state.json" "$SB/baseline.json"; }
  reset()    { cp "$SB/baseline.json" "$HOME/.claude-thread/state.json"; }
  claim()    { state claim /tmp/proj "$PROJ" "$1"; }

  # the restart case: the session you were in was hard-killed, so `state end`
  # never ran and its last_used is frozen at session start (11 days ago); the
  # idle one was closed cleanly a minute ago
  seed "$A" 950000 30
  seed "$B" 60     864000
  baseline
  check "A: resumes the session you were actually working in" "$A" "$(claim '')"

  reset
  local g1 g2; g1=$(claim ""); g2=$(claim "")
  if [ -n "$g1" ] && [ -n "$g2" ] && [ "$g1" != "$g2" ]; then
    echo "  PASS  B: parallel tabs get distinct sessions"; pass=$((pass+1))
  else
    echo "  FAIL  B: got '$g1' and '$g2'"; fail=$((fail+1))
  fi

  reset
  python3 - "$B" <<'EOF'
import json, os, sys, time
p = os.path.expanduser("~/.claude-thread/state.json")
st = json.load(open(p))
st.setdefault("threads", {})["term-xyz"] = {
    "session": sys.argv[1], "cwd": "/tmp/proj", "updated": time.time()}
json.dump(st, open(p, "w"), indent=2)
EOF
  check "C: bound tab returns to its own session, not the freshest" "$B" "$(claim 'term-xyz')"

  reset
  check "D: unknown thread id falls back to most-active" "$A" "$(claim 'term-never-seen')"

  reset
  python3 - "$A" "$B" <<'EOF'
import json, os, sys, time
p = os.path.expanduser("~/.claude-thread/state.json")
st = json.load(open(p))
th = st.setdefault("threads", {})
th["term-xyz"] = {"session": sys.argv[2], "cwd": "/tmp/proj", "updated": time.time()}
th["term-abc"] = {"session": sys.argv[1], "cwd": "/tmp/proj", "updated": time.time()}
json.dump(st, open(p, "w"), indent=2)
EOF
  check "E: restored tab is told what it holds, without claiming it" \
        "$B" "$(state bound term-xyz "$PROJ")"

  state hold "$A" term-abc >/dev/null
  check "F: a parked session is not claimable by another tab" "$B" "$(claim '')"
  check "G: a parked session is not offered to a second tab either" \
        "" "$(state bound term-abc "$PROJ")"

  python3 - "$A" <<'EOF'
import json, os, sys
p = os.path.expanduser("~/.claude-thread/state.json")
st = json.load(open(p))
st["sessions"][sys.argv[1]]["pid"] = 999999   # the parked shell died
json.dump(st, open(p, "w"), indent=2)
EOF
  check "H: closing a parked tab releases its session" \
        "$A" "$(state bound term-abc "$PROJ")"
  rm -rf "$SB"
}

# ── the parked prompt itself (lazy_resume()) ───────────────────────────────
lazy_tests() {
  local SB; SB=$(mktemp -d); export HOME="$SB/home"
  local U="cafe1234-0000-0000-0000-00000000beef"
  local PROJ="$HOME/.claude/projects/-tmp-proj"
  mkdir -p "$PROJ" "$HOME/.claude-thread"
  printf '%s\n' '{"type":"user","message":{"content":"how do I make the sidebar lazy"}}' \
    > "$PROJ/$U.jsonl"
  python3 - "$U" <<'EOF'
import json, os, sys, time
p = os.path.expanduser("~/.claude-thread/state.json")
json.dump({"sessions": {sys.argv[1]: {"cwd": "/tmp/proj", "status": "ended",
           "pid": 999999, "last_used": time.time()-500, "started": 0}},
           "threads": {"term-t1": {"session": sys.argv[1], "cwd": "/tmp/proj"}}},
          open(p, "w"), indent=2)
EOF
  # everything above the sc dispatch is the function library, no entry code
  awk '/^# ── sc-managed launches/{exit} {print}' "$WRAPPER" > "$SB/lib.sh"
  # shellcheck disable=SC1090
  . "$SB/lib.sh"
  PROJ_DIR="$PROJ"; ARCHIVE_DIR="$HOME/.claude-thread/archived"; TERMINAL_ID="term-t1"

  echo "q" | lazy_resume "$U" > "$SB/out.txt" 2>&1
  local out; out=$(cat "$SB/out.txt")
  if grep -q "how do I make the sidebar lazy" <<<"$out"; then
    echo "  PASS  I: parked tab shows the conversation, not a uuid"; pass=$((pass+1))
  else echo "  FAIL  I: no preview in parked prompt"; fail=$((fail+1)); fi
  if grep -q "Enter=resume" <<<"$out"; then
    echo "  PASS  J: parked tab offers resume"; pass=$((pass+1))
  else echo "  FAIL  J: no resume prompt"; fail=$((fail+1)); fi
  if pgrep -f "claude --resume $U" >/dev/null; then
    echo "  FAIL  K: claude was launched by a parked tab"; fail=$((fail+1))
  else echo "  PASS  K: parked tab launched no claude process"; pass=$((pass+1)); fi
  # escape sequences must be interpreted, not printed literally
  if grep -qE '\\x[0-9a-f]{2}' <<<"$out"; then
    echo "  FAIL  L: raw byte escapes leaked into the prompt"; fail=$((fail+1))
  else echo "  PASS  L: prompt renders its glyphs"; pass=$((pass+1)); fi
  rm -rf "$SB"
}

echo "── $WRAPPER ──"
state_tests
lazy_tests
echo "  → $pass passed, $fail failed"
exit $((fail > 0))
