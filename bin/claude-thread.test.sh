#!/bin/bash
# Tests for claude-thread's session bookkeeping. Runs against an isolated HOME,
# never touches ~/.claude-thread. Usage: bin/claude-thread.test.sh [wrapper-path]
#
# Every case here failed at least once for real: A and D are the restart bug
# (the session you were working in loses to an idle one), C/E-H are the Zed
# thread binding and the parking that keeps restored tabs from launching claude.
set -u
WRAPPER="${1:-$(dirname "$0")/claude-thread}"
# absolute: the account tests run the wrapper from inside other folders
WRAPPER="$(cd "$(dirname "$WRAPPER")" && pwd)/$(basename "$WRAPPER")"
# run from a profile session these would leak in (and the profile tests would
# create profiles in the real folder) — the suite must not depend on its caller
unset CLAUDE_PROFILES_ROOT CLAUDE_CONFIG_DIR CLAUDE_THREAD_ARGS CLAUDE_PROFILE CLAUDE_BIN
# project_list deliberately skips temp paths, and mktemp -d hands out
# /var/folders on macOS — so that one sandbox has to live under the real HOME
ORIG_HOME="$HOME"
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

  # a session moved to a different tab must not stay claimed by the old one,
  # or both tabs park on it after a restart
  reset
  python3 - "$B" <<'EOF'
import json, os, sys, time
p = os.path.expanduser("~/.claude-thread/state.json")
st = json.load(open(p))
st.setdefault("threads", {})["term-old"] = {
    "session": sys.argv[1], "cwd": "/tmp/proj", "updated": time.time()}
json.dump(st, open(p, "w"), indent=2)
EOF
  state start "$B" /tmp/proj term-new >/dev/null   # same session, different tab
  check "M: rebinding a session drops the previous tab's claim" \
        "" "$(state bound term-old "$PROJ")"
  local n; n=$(python3 -c "
import json, os
th = json.load(open(os.path.expanduser('~/.claude-thread/state.json')))['threads']
print(sum(1 for v in th.values() if v['session'] == '$B'))")
  check "N: exactly one tab holds that session" "1" "$n"
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

# ── project picker (project_list / project_menu) ───────────────────────────
project_tests() {
  local SB; SB=$(mktemp -d "$ORIG_HOME/.ct-test.XXXXXX"); export HOME="$SB/home"
  mkdir -p "$HOME/.claude/projects" "$HOME/.claude-thread" "$SB/realproj"
  mk() { # <dirname> <cwd-recorded-in-transcript> <age_sec>
    local d="$HOME/.claude/projects/$1"
    mkdir -p "$d"
    printf '{"type":"user","cwd":"%s","message":{"content":"hello there"}}\n' "$2" \
      > "$d/dead0000-0000-0000-0000-00000000000$3.jsonl"
    python3 - "$d/dead0000-0000-0000-0000-00000000000$3.jsonl" "$3" <<'EOF'
import os, sys, time
t = time.time() - float(sys.argv[2]) * 3600
os.utime(sys.argv[1], (t, t))
EOF
  }
  mk real "$SB/realproj" 1                       # exists -> keep
  mk scratch /private/tmp/claude-501/sub 2       # subagent scratch -> drop
  mk gone "$SB/deleted-long-ago" 3               # folder removed -> drop

  awk '/^# ── sc-managed launches/{exit} {print}' "$WRAPPER" > "$SB/lib.sh"
  # shellcheck disable=SC1090
  . "$SB/lib.sh"

  local out; out=$(project_list)
  local n; n=$(printf '%s\n' "$out" | grep -c . )
  check "O: lists only usable projects (1 of 3)" "1" "$n"
  if grep -q "realproj" <<<"$out"; then
    echo "  PASS  P: keeps a project whose folder still exists"; pass=$((pass+1))
  else echo "  FAIL  P: dropped the live project"; fail=$((fail+1)); fi
  if grep -q "/private/tmp" <<<"$out"; then
    echo "  FAIL  Q: subagent scratch dir leaked into the list"; fail=$((fail+1))
  else echo "  PASS  Q: skips subagent scratch dirs"; pass=$((pass+1)); fi
  if grep -q "deleted-long-ago" <<<"$out"; then
    echo "  FAIL  R: offered a project whose folder is gone"; fail=$((fail+1))
  else echo "  PASS  R: skips projects whose folder is gone"; pass=$((pass+1)); fi

  # picking a project must switch the tab to it and show ITS sessions
  local menu; menu=$( (printf '1\nq\n' | project_menu) 2>&1 )
  if grep -q "claude sessions: $SB/realproj" <<<"$menu"; then
    echo "  PASS  S: picking a project opens that project's session menu"; pass=$((pass+1))
  else
    echo "  FAIL  S: did not hand off to the project's menu"; fail=$((fail+1))
    printf '%s\n' "$menu" | sed 's/^/          /' | head -6
  fi
  rm -rf "$SB"
}

# ── accounts (profiles) ────────────────────────────────────────────────────
profile_tests() {
  local SB; SB=$(mktemp -d "$ORIG_HOME/.ct-test.XXXXXX"); export HOME="$SB/home"
  mkdir -p "$HOME/.claude/projects" "$HOME/.claude/skills" "$HOME/.claude/sessions" \
           "$HOME/.claude-thread" "$SB/bin" "$SB/www/acme/sub" "$SB/www/acme2" \
           "$SB/www/worktrees/acme-x" "$SB/www/worktrees/other"
  : > "$HOME/.claude/CLAUDE.md"
  printf '%s\n' '{"mcpServers":{"gsc":{"type":"http","url":"http://x/gsc"}},
    "projects":{"'"$SB/www/acme"'":{"mcpServers":{"pw":{"command":"pw"}}}}}' > "$HOME/.claude.json"
  # fake claude: `auth status` reports a login when the profile has a marker
  # file; any other call prints which config dir and args it got
  cat > "$SB/bin/claude" <<'EOF'
#!/bin/bash
if [ "$1" = auth ] && [ "$2" = status ]; then
  if [ -z "${CLAUDE_CONFIG_DIR:-}" ] || [ -e "$CLAUDE_CONFIG_DIR/.loggedin" ]; then
    echo '{"loggedIn": true}'; else echo '{"loggedIn": false}'; fi
  exit 0
fi
echo "CFG=${CLAUDE_CONFIG_DIR:-main}"
printf 'ARG=%s\n' "$@"
prev=""
for a in "$@"; do
  [ "$prev" = --mcp-config ] && echo "MCPFILE=$a" && echo "MCP=$(tr -d '\n ' < "$a")"
  prev="$a"
done
EOF
  chmod +x "$SB/bin/claude"
  awk '/^# ── account commands/{exit} {print}' "$WRAPPER" > "$SB/lib.sh"
  # shellcheck disable=SC1090
  . "$SB/lib.sh"
  CLAUDE_BIN="$SB/bin/claude"; TERMINAL_ID=""; unset CLAUDE_PROFILE

  profile_cmd new dev >/dev/null
  profile_cmd new acme >/dev/null
  : > "$PROFILES_ROOT/dev/.loggedin"; : > "$PROFILES_ROOT/acme/.loggedin"
  check "T1: new links what you author" "$HOME/.claude/CLAUDE.md" "$(readlink "$PROFILES_ROOT/dev/CLAUDE.md")"
  check "T2: new links transcripts, so worklog still sees them" \
        "$HOME/.claude/projects" "$(readlink "$PROFILES_ROOT/dev/projects")"
  check "T3: never shares the live session registry" "no" \
        "$([ -e "$PROFILES_ROOT/dev/sessions" ] && echo yes || echo no)"
  check "T4: 'main' is refused as a profile name" "1" \
        "$(profile_cmd new main >/dev/null; echo $?)"

  profile_cmd map dev "$SB/www/worktrees/*" >/dev/null
  profile_cmd map acme "$SB/www/acme" >/dev/null
  profile_cmd map acme "$SB/www/worktrees/acme-*" >/dev/null
  check "U1: a mapped folder routes to its profile" "acme" "$(profile_which "$SB/www/acme")"
  check "U2: and so does anything below it" "acme" "$(profile_which "$SB/www/acme/sub")"
  check "U3: a sibling sharing the prefix does not" "" "$(profile_which "$SB/www/acme2")"
  check "U4: a glob route matches" "dev" "$(profile_which "$SB/www/worktrees/other")"
  check "U5: the longer route wins" "acme" "$(profile_which "$SB/www/worktrees/acme-x")"
  check "U6: an unmapped folder is main" "" "$(profile_which "$SB")"
  profile_cmd map acme "$SB/www/acme" >/dev/null
  check "U7: re-mapping does not duplicate a route" "1" \
        "$(grep -c "^$SB/www/acme	" "$PROFILE_MAP")"

  local out
  out=$(cd "$SB" && claude_cmd "" --resume x)
  check "V1: main launches on ~/.claude" "CFG=main" "$(head -1 <<<"$out")"
  if grep -qx "ARG=--remote-control" <<<"$out"; then
    echo "  PASS  V2: main keeps Remote Control"; pass=$((pass+1))
  else echo "  FAIL  V2: main lost --remote-control"; fail=$((fail+1)); fi
  out=$(cd "$SB/www/acme" && claude_cmd acme --resume x)
  check "V3: a profile launches on its own folder" "CFG=$PROFILES_ROOT/acme" "$(head -1 <<<"$out")"
  if grep -qx "ARG=--remote-control" <<<"$out"; then
    echo "  FAIL  V4: a profile got --remote-control"; fail=$((fail+1))
  else echo "  PASS  V4: a profile gets no --remote-control flag"; pass=$((pass+1)); fi
  check "V5: and its settings turn Remote Control off at startup" "False" \
        "$(python3 -c "import json;print(json.load(open('$PROFILES_ROOT/acme/launch-settings.json'))['remoteControlAtStartup'])")"
  check "V6: it gets main's MCP servers plus main's for that folder" "gsc,pw" \
        "$(sed -n 's/^MCP=//p' <<<"$out" | python3 -c "import json,sys;print(','.join(sorted(json.load(sys.stdin)['mcpServers'])))")"
  local mf; mf=$(sed -n 's/^MCPFILE=//p' <<<"$out")
  check "V6b: each launch gets its own MCP file, removed after exit" "gone" \
        "$([ -n "$mf" ] && [ ! -e "$mf" ] && echo gone || echo "left:$mf")"
  out=$(cd "$SB" && CLAUDE_CONFIG_DIR="$PROFILES_ROOT/acme" claude_cmd "" x)
  check "V6c: main ignores a CLAUDE_CONFIG_DIR inherited from a profile shell" \
        "CFG=main" "$(head -1 <<<"$out")"
  mkdir "$HOME/.claude/plans"
  (cd "$SB/www/acme" && claude_cmd acme x >/dev/null)
  check "V6d: a shared folder created after 'profile new' is linked at launch" \
        "$HOME/.claude/plans" "$(readlink "$PROFILES_ROOT/acme/plans")"
  rm "$PROFILES_ROOT/acme/.loggedin"
  out=$(cd "$SB/www/acme" && claude_cmd acme --resume x); local rc=$?
  check "V7: a logged-out profile is refused, not launched" "3" "$rc"
  if grep -q "^CFG=" <<<"$out"; then
    echo "  FAIL  V8: claude ran on a logged-out profile"; fail=$((fail+1))
  else echo "  PASS  V8: and says how to log in"; pass=$((pass+1)); fi
  : > "$PROFILES_ROOT/acme/.loggedin"

  # a session keeps the account it started on
  local S1=11111111-0000-0000-0000-000000000001 S2=22222222-0000-0000-0000-000000000002
  state start "$S1" "$SB/www/acme" "" dev >/dev/null; state end "$S1" >/dev/null
  check "W1: a resume keeps its recorded profile over the folder's" "dev" \
        "$(cd "$SB/www/acme" && resolve_profile "$S1")"
  check "W2: a new session takes the folder's profile" "acme" \
        "$(cd "$SB/www/acme" && resolve_profile "$S2")"
  check "W3: cld main overrides both" "" \
        "$(cd "$SB/www/acme" && CLAUDE_PROFILE=main resolve_profile "$S1")"
  state start "$S2" "$SB/www/acme" "" main >/dev/null; state end "$S2" >/dev/null
  check "W4: a session recorded on main stays on main in a mapped folder" "" \
        "$(cd "$SB/www/acme" && resolve_profile "$S2")"
  check "W5: the picker can tag profile sessions (main untagged)" "$S1	dev" "$(state profiles)"

  # a session from before profiles: transcript exists, nothing recorded
  local OLD=33333333-0000-0000-0000-000000000003 ACME_PROJ
  ACME_PROJ="$HOME/.claude/projects/$(cd "$SB/www/acme" && pwd | sed 's/[^a-zA-Z0-9]/-/g')"
  mkdir -p "$ACME_PROJ"
  printf '%s\n' '{"type":"user","message":{"content":"old work"}}' > "$ACME_PROJ/$OLD.jsonl"
  check "W6: an older session with no record resumes on main, not the route" "" \
        "$(cd "$SB/www/acme" && PROJ_DIR="$ACME_PROJ" resolve_profile "$OLD")"

  # the launch paths themselves, not just the resolver
  out=$(cd "$SB/www/acme" && PROJ_DIR="$ACME_PROJ" run_claude "$S1" --resume "$S1" 2>&1)
  check "X1: run_claude resumes on the recorded profile" "1" \
        "$(grep -c "CFG=$PROFILES_ROOT/dev$" <<<"$out")"
  local S4=44444444-0000-0000-0000-000000000004
  (cd "$SB/www/acme" && PROJ_DIR="$ACME_PROJ" run_claude "$S4" --session-id "$S4" >/dev/null 2>&1)
  check "X2: run_claude records a new session's account" "acme" "$(state profile "$S4")"

  # whole-script passthrough: --continue follows the newest session's account,
  # a bare --resume opens our picker instead of claude's account-blind one
  state start "$OLD" "$SB/www/acme" "" dev >/dev/null; state end "$OLD" >/dev/null
  out=$(cd "$SB/www/acme" && CLAUDE_BIN="$SB/bin/claude" bash "$WRAPPER" --continue </dev/null 2>&1)
  check "X3: --continue runs on the newest session's account" "1" \
        "$(grep -c "CFG=$PROFILES_ROOT/dev$" <<<"$out")"
  # sc's bare --resume with a session to recover: Enter resumes it on its account
  out=$( (cd "$SB/www/acme" && printf '\n' | CLAUDE_BIN="$SB/bin/claude" bash "$WRAPPER" --resume) 2>&1)
  check "X4: a recovered bare --resume runs on the session's account" "1" \
        "$(grep -c "CFG=$PROFILES_ROOT/dev$" <<<"$out")"
  # nothing to recover: our picker, never claude's account-blind one
  rm "$HOME/.claude-thread/state.json"
  out=$( (cd "$SB/www/acme" && echo q | CLAUDE_BIN="$SB/bin/claude" bash "$WRAPPER" --resume) 2>&1)
  if grep -q "claude sessions:" <<<"$out" && ! grep -q "CFG=" <<<"$out"; then
    echo "  PASS  X5: a bare --resume with nothing to recover opens our picker"; pass=$((pass+1))
  else echo "  FAIL  X5: bare --resume launched claude directly"; fail=$((fail+1))
    printf '%s\n' "$out" | head -8 | sed 's/^/          /'; fi
  rm -rf "$SB"
}

echo "── $WRAPPER ──"
state_tests
lazy_tests
project_tests
profile_tests
echo "  → $pass passed, $fail failed"
exit $((fail > 0))
