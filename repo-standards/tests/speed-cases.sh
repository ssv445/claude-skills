# speed-cases.sh: sourced by tests/run.sh at its end (its expect, srm, review, $T, $SKILL, $ok and
# the fake gh in $T/fakebin are used here). The speed-up, same gates: the parallel runner
# (scripts/lib/parallel.sh), the machine-wide gate locks, pre-push's lanes, and bin/ship's e2e +
# perf step with verdict reuse (scripts/lib/ship-checks.sh), on a throwaway repo whose checks are
# all copies of tests/parallel-fixtures/fake.sh. Every case runs under /bin/bash (3.2).
SPF="$SKILL/tests/parallel-fixtures"
GS="$SPF/gate.sh"
SL="$T/speed-locks"      # this suite's lock dir, never the machine's real one
out="$T/speed.out"; flog="$T/speed-calls.log"; glog="$T/speed-gates.log"
code=0

# Assertions over $out, $code and the fake's call log.
all_of() { # <command> , <command> , ...: every comma-separated command succeeds
  local args=()
  while [ $# -gt 0 ]; do
    if [ "$1" = , ]; then "${args[@]}" || return 1; args=(); else args+=("$1"); fi
    shift
  done
  [ ${#args[@]} -eq 0 ] || "${args[@]}"
}
said() { local s; for s in "$@"; do grep -qF -- "$s" "$out" || return 1; done; }
unsaid() { local s; for s in "$@"; do grep -qF -- "$s" "$out" && return 1; done; return 0; }
code_is() { [ "$code" -eq "$1" ]; }
line_of() { local n; n="$(grep -nF -- "$1" "$out" | head -1 | cut -d: -f1)"; echo "${n:-0}"; }
before() { local a b; a="$(line_of "$1")"; b="$(line_of "$2")"; [ "$a" -gt 0 ] && [ "$b" -gt 0 ] && [ "$a" -lt "$b" ]; }
called() { local c; for c in "$@"; do grep -qxF -- "$c" "$flog.calls" || return 1; done; }
not_called() { local c; for c in "$@"; do grep -qxF -- "$c" "$flog.calls" && return 1; done; return 0; }
nothing_called() { [ ! -s "$flog.calls" ]; }
at() { awk -v w="$1" -v c="$2" '$1 == w && substr($0, length($1 " " $2 " ") + 1) == c { print $2; exit }' "$flog"; }
overlapped() { [ "$(at start "$2")" -lt "$(at end "$1")" ] && [ "$(at start "$1")" -lt "$(at end "$2")" ]; }
after_both() { [ "$(at start "$1")" -ge "$(at end "$2")" ] && [ "$(at start "$1")" -ge "$(at end "$3")" ]; }
ran() { local l; for l in "$@"; do [ -e "$T/marks/$l" ] || return 1; done; }
gone() { ! kill -0 "$1" 2> /dev/null; }
wall_under() { local s; s="$(sed -n 's/.* verdict: ran [0-9]* check(s) in \([0-9]*\)s$/\1/p' "$out")"; [ -n "$s" ] && [ "$s" -lt "$1" ]; }
since_ge() { [ $(($(date +%s) - s0)) -ge "$1" ]; }
since_lt() { [ $(($(date +%s) - s0)) -lt "$1" ]; }

# sp [VAR=value ...] <command...>: runs in the speed repo $P with this suite's lock dir, marks
# and logs; output in $out, exit code in $code. The outer environment's gate settings are dropped.
sp() {
  : > "$flog"; : > "$flog.calls"
  (cd "$P" && env -u STANDARDS_GATE_BUSY -u STANDARDS_RERUN -u PAR_LOG_DIR -u STANDARDS_LIB \
    STANDARDS_LOCK_DIR="$SL" PAR_MARKS="$T/marks" FAKE_LOG="$flog" GATE_LOG="$glog" "$@") < /dev/null > "$out" 2>&1
  code=$?
}
marks() { srm "$T/marks"; mkdir -p "$T/marks"; }
fresh_locks() { srm "$SL"; mkdir -p "$SL"; }
hold() { sleep "$1" & holder=$!; }   # hold <seconds>: a live process a lock can name; pid in $holder
lock_by() { mkdir -p "$SL/$1.lock" && printf '%s\n' "$2" > "$SL/$1.lock/pid"; }   # lock_by <name> <pid>
gp() { git -C "$P" "$@"; }
bump() { printf '%s\n' "$RANDOM" >> "$P/$1" && gp add -- "$1" && gp commit -qm "change $1"; }   # bump <path>
head_of() { gp rev-parse HEAD; }

# speed_repo <dir> <scripts dir>: a clone of a bare origin with .standards/ from <scripts dir>, the
# fakes as every check (config-speed.sh appended), bin/ship, and branch feat/7-x changing notes.txt
# with its decisions.md (spec and plan gates PASS).
speed_repo() {
  local d="$1" s="$2"
  git init -q --bare -b main "$d.git" && git clone -q "$d.git" "$d" 2> /dev/null || return 1
  (
    cd "$d" || exit 1
    git config user.email t@example.invalid; git config user.name test
    mkdir -p .standards bin scripts src docs/work/7-x
    cp -R "$s/." .standards/ && cp "$s/bin/ship" bin/ship
    cat "$SPF/config-speed.sh" >> .standards/config.sh
    for f in lint typecheck unit site-unit diff-cover e2e perf; do cp "$SPF/fake.sh" "scripts/$f.sh"; done
    cp "$SPF/version.sh" scripts/version.sh
    chmod +x bin/ship scripts/*.sh .standards/hooks/* .standards/checks/* .standards/bin/*
    : > docs/doc-map.txt; printf 'a\n' > src/a.txt
    git add -A . && git commit -qm base && git push -q origin main
    git checkout -q -b feat/7-x
    sed 's/Verdict: PENDING/Verdict: PASS/' "$SKILL/templates/decisions.md" > docs/work/7-x/decisions.md
    printf 'n\n' > notes.txt
    git add notes.txt docs && git commit -qm "notes, decision log"
  )
}

# --- The runner -------------------------------------------------------------------------------
# runner_cases: par_run's rules, through gate.sh (STANDARDS_LIB picks the runner under test).
runner_cases() {
  marks; sp "$@" "$GS" job=a:one:true job=a:two:true job=b:three:true run
  expect pass "runner: all pass → exit 0, a PASS line per check and a final PASS" \
    all_of code_is 0 , said "PASS one" "PASS two" "PASS three" "PASS set: all 3 check(s) passed"
  expect pass "runner: … every check and its lane is listed before anything runs" \
    all_of before "lane a: one → two" "done " , before "lane b: three" "done "
  expect pass "runner: … each check's log is printed, headed by its command" said "----- one (lane a): "
  marks; sp "$@" "$GS" "job=a:one:echo fake-out-one; false" job=a:two:true job=b:three:true run
  expect pass "runner: the first check of a lane fails → exit 1" code_is 1
  expect pass "runner: … the rest of its lane and the other lane still run" ran one two three
  expect pass "runner: … its FAIL line names it; its output is shown" \
    said "FAIL one (exit 1" "FAIL set: 1 of 3 check(s) failed: one" "fake-out-one"
  marks; sp "$@" "$GS" job=a:one:true "job=a:two:exit 3" job=a:three:true job=b:four:true run
  expect pass "runner: a middle check exits 3 → exit 1, its code reported, the next ones run" \
    all_of code_is 1 , said "FAIL two (exit 3" "PASS three" "PASS four" , ran three four
  marks; sp "$@" "$GS" job=a:one:false job=b:two:false run
  expect pass "runner: two failures → both named" all_of code_is 1 , said "2 of 2 check(s) failed: one two"
}
echo "parallel runner"
P="$T/speed"; speed_repo "$P" "$SKILL/scripts" || { echo "FATAL speed repo"; exit 1; }
fresh_locks
runner_cases
marks; sp "$GS" "job=a:one:sleep 2" "job=b:two:sleep 2" "job=c:three:sleep 2" run
expect pass "runner: lanes run at the same time (3 lanes of 2 s in under 5 s)" all_of code_is 0 , wall_under 5
: > "$T/order"
marks; sp "$GS" "job=a:one:sleep 1; echo 1 >> '$T/order'" "job=a:two:echo 2 >> '$T/order'" run
expect pass "runner: a lane runs in queue order" test "$(tr -d '\n' < "$T/order")" = 12
sp "$GS" run
expect pass "runner: no check queued → FAIL" all_of code_is 1 , said "no check queued"
printf 'data\n' > "$T/input"
(cd "$P" && STANDARDS_LOCK_DIR="$SL" "$GS" 'job=a:one:read -r x; test -z "$x"' run) < "$T/input" > "$out" 2>&1; code=$?
expect pass "runner: a check reads nothing from the gate's input" code_is 0
sp "$GS" job=a:ok:true "job=a:bad:exit 4" run rc=ok rc=bad rc=none failed
expect pass "runner: par_rc gives each code (1 for an unknown check); par_failed names failures" \
  said "rc ok=0" "rc bad=4" "rc none=1" "failed=bad"
sp "$GS" job=a:ok:true run rc=ok
expect pass "runner: par_rc still reads 0 once a passing run's own log dir is gone" said "rc ok=0"
logs="$(sed -n 's/.*; logs in \(.*\)$/\1/p' "$out" | head -1)"
expect pass "runner: … that log dir (its own temp dir) is removed after an all-PASS run" all_of test -n "$logs" , test ! -e "$logs"
sp "$GS" job=a:bad:false run
logs="$(sed -n 's/.*; logs in \(.*\)$/\1/p' "$out" | head -1)"
expect pass "runner: … and kept after a failure, the FAIL line naming the log" \
  all_of test -n "$logs" , test -f "$logs/00-bad.log" , said "log $logs/00-bad.log"
# A lane that dies before its check writes an exit code: kill the lane (a process this test
# started) first, so it cannot record anything, then what ran under it.
marks; srm "$T/pl-dies"
# exec: $! is then the gate itself, so its children are the lanes.
(cd "$P" && exec env STANDARDS_LOCK_DIR="$SL" PAR_MARKS="$T/marks" PAR_LOG_DIR="$T/pl-dies" "$GS" "job=a:slow:sleep 30" job=b:quick:true run) < /dev/null > "$out" 2>&1 &
case_pid=$!
for _ in $(seq 1 100); do [ -e "$T/marks/slow" ] && [ -f "$T/pl-dies/01-quick.rc" ] && break; sleep 0.1; done
for lane in $(pgrep -P "$case_pid"); do
  under="$(pgrep -P "$lane")"
  kill -KILL "$lane" 2> /dev/null
  for c in $under; do pkill -KILL -P "$c" 2> /dev/null; kill -KILL "$c" 2> /dev/null; done
done
wait "$case_pid"; code=$?
expect pass "runner: a lane killed mid-check → that check FAILs with no exit code, the set fails" \
  all_of said "FAIL slow (no exit code" , code_is 1
expect pass "runner: … the other lane's check still counts" said "PASS quick"
# TERM to the gate stops what the runner started, after letting a check's EXIT trap run.
srm "$T/long.pid" "$T/trapped"
(cd "$P" && exec env STANDARDS_LOCK_DIR="$SL" "$GS" "job=a:long:trap \": > '$T/trapped'\" EXIT; sh -c 'echo \$\$ > \"$T/long.pid\"; exec sleep 30'" run) < /dev/null > "$out" 2>&1 &
case_pid=$!
for _ in $(seq 1 100); do [ -s "$T/long.pid" ] && break; sleep 0.1; done
kill -TERM "$case_pid"; wait "$case_pid"; code=$?
sleep 0.3
expect pass "runner: TERM → exit 130 and the check's process is gone" all_of code_is 130 , gone "$(cat "$T/long.pid")"
expect pass "runner: … after the check's own EXIT trap ran" test -e "$T/trapped"
expect pass "runner: … and its busy mark is gone" test -z "$(ls -A "$SL/busy" 2> /dev/null)"

# --- Machine-wide gate locks ------------------------------------------------------------------
echo "gate locks"
fresh_locks; hold 4; lock_by timed "$holder"; s0=$(date +%s)
sp "$GS" job=a:one:true run
expect pass "locks: a timed lock held by a live process → the gate waits, says who, then runs" \
  all_of code_is 0 , said "wait timed checks are running or waiting (pid $holder" , since_ge 2
wait "$holder"; lock_by timed "$holder"; s0=$(date +%s)
sp "$GS" job=a:one:true run
expect pass "locks: a timed lock whose process is gone → removed, no wait" all_of code_is 0 , unsaid "wait " , since_lt 2
lock_by timed "$$"; printf 'Mon Jan  1 00:00:00 2001\n' > "$SL/timed.lock/start"
sp "$GS" job=a:one:true run
expect pass "locks: a timed lock whose pid now names a later process → removed, no wait" all_of code_is 0 , unsaid "wait "
fresh_locks; mkdir -p "$SL/timed.lock"
sp "$GS" "held=$SL/timed.lock"
expect pass "locks: a lock with no pid yet, under 10 s old, is held" said held
touch -t 200101010000 "$SL/timed.lock"
sp "$GS" "held=$SL/timed.lock"
expect pass "locks: … and free once older" said free
fresh_locks; hold 3; lock_by timed "$holder"
sp STANDARDS_GATE_BUSY=$$ "$GS" job=a:one:true run
expect pass "locks: a gate nested in a live ancestor gate (STANDARDS_GATE_BUSY) does not wait" all_of code_is 0 , unsaid "wait "
s0=$(date +%s)
sp STANDARDS_GATE_BUSY="$holder" "$GS" job=a:one:true run
expect pass "locks: … STANDARDS_GATE_BUSY naming a process that is no ancestor is ignored: it waits" \
  all_of code_is 0 , said "wait timed checks" , since_ge 1
wait "$holder" 2> /dev/null; fresh_locks
: > "$T/not-a-dir"
sp STANDARDS_LOCK_DIR="$T/not-a-dir/locks" "$GS" job=a:one:true run
expect pass "locks: a busy mark that cannot be made → the set fails, naming the dir (fails closed)" \
  all_of code_is 1 , said "cannot mark this gate busy in $T/not-a-dir/locks" , unsaid "PASS set"
# A lock dir safe_rm may not delete in (under HOME, outside the repo and the temp dirs) could never
# lose a stale lock: refused up front. HOME and TMPDIR are this suite's own dirs, never the real ones.
mkdir -p "$T/fh" "$T/fh-tmp"
sp HOME="$T/fh" TMPDIR="$T/fh-tmp" STANDARDS_LOCK_DIR="$T/fh/locks" "$GS" job=a:one:true run
expect pass "locks: a lock dir where safe_rm may not delete → the set fails (fails closed)" \
  all_of code_is 1 , said "cannot mark this gate busy in $T/fh/locks"
sp PAR_LOG_DIR="$T/not-a-dir/logs" "$GS" job=a:one:true run
expect pass "locks: a log dir that cannot be made → the set fails" all_of code_is 1 , said "cannot create the log dir"
hold 3; mkdir -p "$SL/busy"; printf '%s\n' "$(ps -o lstart= -p "$holder")" > "$SL/busy/$holder"; : > "$SL/busy/999999"
sp "$GS" lock=timed idle unlock=timed "held=$SL/timed.lock"
expect pass "locks: gate_wait_idle waits for another gate's live busy mark; gate_unlock frees the lock" \
  all_of said "wait other gates are running checks (pid $holder)" free , grep -qE '^idle after [1-9]' "$out"
expect pass "locks: … a busy mark whose process is gone is removed" test ! -e "$SL/busy/999999"
wait "$holder" 2> /dev/null
hold 3; lock_by e2e-x "$holder"
sp "$GS" lock=e2e-x unlock=e2e-x
expect pass "locks: gate_lock waits for a live holder, says so, then takes it" \
  all_of said "wait the e2e-x lock is held by pid $holder" , grep -qE '^locked e2e-x after [1-9]' "$out"
wait "$holder" 2> /dev/null
sp "$GS" busy-on job=a:one:true run marked busy-off marked
expect pass "locks: gate_busy_on keeps the mark past par_run (pre-push's tail); busy-off removes it" \
  test "$(grep -E '^(un)?marked$' "$out" | tr '\n' ' ')" = "marked unmarked "
s0=$(date +%s)
sp "$GS" lock=e2e-y inner=lock=e2e-y unlock=e2e-y
expect pass "locks: a lock held by the gate's own outer gate → FAIL at once, no wait" \
  all_of said "held by this gate's own outer gate" "inner exit 1" , since_lt 3
fresh_locks
# alone_cases: ship_alone waits for another gate's live busy mark (STANDARDS_LIB: the lib under test).
alone_cases() {
  hold 3; mkdir -p "$SL/busy"; printf '%s\n' "$(ps -o lstart= -p "$holder")" > "$SL/busy/$holder"; s0=$(date +%s)
  sp "$@" "$GS" "alone=true"
  expect pass "locks: the timed half waits until no other gate is running checks, says so" \
    all_of code_is 0 , said "wait other gates are running checks (pid $holder)" , since_ge 1
  wait "$holder" 2> /dev/null; fresh_locks
}
alone_cases
# Two gates at once, each: a check (par_run), then a timed part (ship_alone). Both finish (no
# deadlock), and neither's timed part overlaps anything of the other's.
: > "$glog"
two_gate() { # two_gate <name>: one of the two gates
  (cd "$P" && STANDARDS_LOCK_DIR="$SL" GATE_LOG="$glog" GATE_NAME="$1" "$GS" \
    "job=a:one:'$GS' log=start-checks sleep=2 log=end-checks" run "alone='$GS' log=start-timed sleep=2 log=end-timed") \
    < /dev/null > "$T/two-$1.out" 2>&1
}
s0=$(date +%s)
two_gate A & pA=$!
two_gate B & pB=$!
wait "$pA"; cA=$?; wait "$pB"; cB=$?
no_overlap() {
  awk '{ t[$1 " " $3] = $2 }
    END {
      split("A B", g, " ")
      for (i = 1; i <= 2; i++) {
        me = g[i]; other = g[3 - i]
        ts = t["start-timed " me]; te = t["end-timed " me]
        if (ts == "" || te == "") exit 1
        if (t["start-checks " other] < te && t["end-checks " other] > ts) exit 1
        if (t["start-timed " other] < te && t["end-timed " other] > ts) exit 1
      }
    }' "$glog"
}
expect pass "locks: two gates at once both finish, and each timed part runs alone" \
  all_of test "$cA" -eq 0 , test "$cB" -eq 0 , since_lt 20 , no_overlap

# --- pre-push: lanes, then the order-dependent checks -----------------------------------------
echo "pre-push lanes"
pps() { # pps [VAR=value ...]: the real pre-push hook of feat/7-x's HEAD
  printf 'refs/heads/feat/7-x %s refs/heads/feat/7-x %s\n' "$(head_of)" 0000000000000000000000000000000000000000 > "$T/sp-refs"
  : > "$flog"; : > "$flog.calls"
  (cd "$P" && env -u STANDARDS_GATE_BUSY -u PAR_LOG_DIR STANDARDS_LOCK_DIR="$SL" FAKE_LOG="$flog" "$@" .standards/hooks/pre-push) < "$T/sp-refs" > "$out" 2>&1
  code=$?
}
listed_failed() { grep -qxF -- "  - $1" "$out"; }
pps
expect pass "pre-push: every check green → PASSED" all_of code_is 0 , said "pre-push PASSED"
expect pass "pre-push: … lists its checks and lanes before running them" \
  all_of before "lane unit: unit → seeds" "done " , before "lane repo: cross-reads → doc-map → decision-log" "done " , before "lane site: site-lint → site-typecheck → site-unit" "done "
expect pass "pre-push: … diff-coverage runs after the unit tests, tdd after diff-coverage" \
  all_of before "done unit" "RUN  diff-coverage" , before "done site-unit" "RUN  diff-coverage" , before "RUN  diff-coverage" "tdd: source changed"
: > "$flog.list"
pps FAKE_LIST="$SL/busy"
expect pass "pre-push: … stays marked busy to its last check (diff-coverage), not only through the lanes" \
  grep -qE '^diff-cover.sh : [0-9]+ $' "$flog.list"
for spec in "lint:lint.sh" "typecheck:typecheck.sh" "unit:unit.sh" "site-unit:site-unit.sh" "diff-coverage:diff-cover.sh"; do
  label="${spec%%:*}"
  pps FAKE_FAIL="${spec#*:}"
  expect pass "pre-push: $label fails alone → blocked, $label listed as failed" \
    all_of code_is 1 , said "pre-push BLOCKED" , listed_failed "$label"
  expect pass "pre-push: … every other check still ran" \
    all_of called "lint.sh " "typecheck.sh " "unit.sh " "site-unit.sh " "diff-cover.sh " , said "tdd: source changed" "PASS decision-log"
done
pps T_LANES="typecheck=build unit=build"
expect pass "pre-push: PREPUSH_LANES puts named checks in one lane, in turn" \
  all_of code_is 0 , said "lane build: typecheck → unit" "lane lint: lint" "lane unit: seeds"
pps T_LANES="*=serial"
expect pass "pre-push: PREPUSH_LANES \"*=serial\" runs every check in one lane" \
  all_of code_is 0 , said "lane serial: lint → typecheck → unit → seeds → site-lint" , unsaid "lane repo:"
pps PAR_LOG_DIR="$T/not-a-dir/logs"
expect pass "pre-push: the runner fails before any check → blocked, 'the parallel runner itself' listed" \
  all_of code_is 1 , listed_failed "the parallel runner itself"
pps STANDARDS_LOCK_DIR="$T/not-a-dir/locks"
expect pass "pre-push: its busy mark cannot be made → blocked before any check" \
  all_of code_is 1 , said "FAIL push: cannot mark this gate busy" , unsaid "lane lint"
fresh_locks; hold 3; lock_by timed "$holder"
pps
expect pass "pre-push: waits behind another gate's timed checks; the wait is left out of the budget" \
  all_of code_is 0 , said "wait timed checks are running or waiting" "for another gate's timed checks (not counted below)"
wait "$holder" 2> /dev/null; fresh_locks

# --- bin/ship's e2e and perf step (ship_checks) -----------------------------------------------
echo "ship e2e + perf"
shp() { sp FAKE_SLEEP="${FAKE_SLEEP:-0}" "$@" "$GS" ship; }   # shp [VAR=value ...]: ship_checks on feat/7-x
FAKE_SLEEP=2 shp
expect pass "ship-checks: all pass → exit 0; e2e, perf prep and perf measure each ran" \
  all_of code_is 0 , called "e2e.sh " "perf.sh prep" "perf.sh measure"
expect pass "ship-checks: … e2e and perf prep ran at the same time" overlapped "e2e.sh " "perf.sh prep"
expect pass "ship-checks: … perf measure started only after both had finished" after_both "perf.sh measure" "e2e.sh " "perf.sh prep"
expect pass "ship-checks: … the set is listed before it runs, the timed half said alone, the verdict recorded" \
  all_of said "lane e2e: e2e → site-e2e" "lane perf: perf-prep" "alone now" "recorded: e2e and perf passed" , unsaid "reused"
shp
expect pass "ship-checks: the same input again → reused: nothing runs, the commit and key printed" \
  all_of code_is 0 , nothing_called , said "reused, not re-run" "on commit $(head_of)" "key  tree "
bump docs/work/7-x/decisions.md; shp
expect pass "ship-checks: only the issue's decisions.md changed → still reused" all_of code_is 0 , nothing_called
shp STANDARDS_RERUN=1
expect pass "ship-checks: STANDARDS_RERUN=1 → runs everything" all_of code_is 0 , called "e2e.sh " "perf.sh prep" "perf.sh measure"
shp T_REUSE=
shp T_REUSE=
expect pass "ship-checks: VERDICT_REUSE off → a re-run runs everything, says nothing of reuse" \
  all_of called "e2e.sh " "perf.sh measure" , unsaid "reused" "recorded"
# key_cases: a recorded pass, then one input changed at a time: each must run everything.
key_cases() {
  shp "$@"; bump notes.txt; shp "$@"
  expect pass "ship-checks: another file changed → runs everything" called "e2e.sh " "perf.sh measure"
  shp "$@"; printf 'x\n' > "$P/untracked.txt"; shp "$@"
  expect pass "ship-checks: an untracked file appeared → runs everything" called "e2e.sh " "perf.sh measure"
  srm "$P/untracked.txt"
  shp "$@"; gp checkout -q main; gp commit -q --allow-empty -m "main moved"; gp push -q origin main
  gp checkout -q feat/7-x; gp rebase -q main; shp "$@"
  expect pass "ship-checks: the base moved (rebase, same files) → runs everything" called "e2e.sh " "perf.sh measure"
  shp "$@"; shp FAKE_VERSION=v9 "$@"
  expect pass "ship-checks: a tool version (VERDICT_KEY_CMD) changed → runs everything" called "e2e.sh " "perf.sh measure"
}
key_cases
printf 'edit\n' >> "$P/notes.txt"; shp
expect pass "ship-checks: an uncommitted edit to a tracked file → runs everything" called "e2e.sh " "perf.sh measure"
gp checkout -q -- notes.txt
shp FAKE_VERSION=fail
expect pass "ship-checks: VERDICT_KEY_CMD fails → runs everything, says nothing can be reused" \
  all_of code_is 0 , called "e2e.sh " , said "verdict key could not be read"
shp FAKE_VERSION=fail
expect pass "ship-checks: … and records nothing: the next such run runs again" called "e2e.sh "
shp
vdir="$(cd "$P" && cd "$(git rev-parse --git-common-dir)" && pwd -P)/standards-verdicts"
for f in "$vdir"/ship-*; do sed '$s/^passed [0-9]*/passed 1000/' "$f" > "$f.new" && mv "$f.new" "$f"; done
shp
expect pass "ship-checks: a recorded pass over a day old → runs everything" called "e2e.sh " "perf.sh measure"
for f in "$vdir"/ship-*; do printf 'garbage\n' > "$f"; done
shp
expect pass "ship-checks: an unreadable record → runs everything" called "e2e.sh "
shp
expect pass "ship-checks: (then it is reused again)" nothing_called
expect pass "ship-checks: records live in the git dir, not the tree" \
  all_of test -n "$(ls "$vdir")" , test -z "$(gp status --porcelain)"
echo "ship e2e + perf: failures"
bump notes.txt
shp FAKE_FAIL=e2e.sh
expect pass "ship-checks: e2e fails → exit 1; perf prep and measure still run" all_of code_is 1 , called "perf.sh prep" "perf.sh measure"
shp
expect pass "ship-checks: … nothing was recorded: the next run runs everything" called "e2e.sh " "perf.sh prep" "perf.sh measure"
shp STANDARDS_RERUN=1 FAKE_FAIL="perf.sh prep"
expect pass "ship-checks: perf prep fails → exit 1, perf measure not run, said so" \
  all_of code_is 1 , not_called "perf.sh measure" , said "perf not run: perf-prep failed"
shp STANDARDS_RERUN=1 FAKE_FAIL="perf.sh measure"
expect pass "ship-checks: perf measure fails → exit 1" all_of code_is 1 , said "FAIL perf (exit 1)"
shp
expect pass "ship-checks: … a forced re-run that failed voids the pass before it: the next run runs everything" \
  called "e2e.sh " "perf.sh measure"
shp STANDARDS_RERUN=1 STANDARDS_LOCK_DIR="$T/not-a-dir/locks"
expect pass "ship-checks: the locks cannot be made → exit 1, the timed half not run" all_of code_is 1 , not_called "perf.sh measure"
shp STANDARDS_RERUN=1 FAKE_TOUCH="$P/during.txt"
expect pass "ship-checks: the input changed during the run → not recorded" all_of code_is 0 , said "verdict not recorded"
srm "$P/during.txt"
echo "ship e2e + perf: configuration"
FAKE_SLEEP=1 shp STANDARDS_RERUN=1 T_PREP= T_PERF=scripts/perf.sh
expect pass "ship-checks: PERF_PREP_CMD empty → PERF_CMD runs whole, after e2e, alone" \
  all_of code_is 0 , called "perf.sh " , not_called "perf.sh prep" , after_both "perf.sh " "e2e.sh " "e2e.sh " , said "alone now"
shp STANDARDS_RERUN=1 T_PREP= T_PERF=
expect pass "ship-checks: no perf configured → SKIP perf, no lock taken" all_of code_is 0 , said "SKIP perf (N/A in config)" , unsaid "alone now"
rid="$(cd "$P" && "$GS" repo-id)"
hold 3; lock_by "e2e-$rid" "$holder"
shp STANDARDS_RERUN=1 T_E2E_EXCLUSIVE=
expect pass "ship-checks: E2E_EXCLUSIVE off → e2e ignores the repo's e2e lock" all_of code_is 0 , unsaid "wait the e2e-"
shp STANDARDS_RERUN=1 T_E2E_EXCLUSIVE=1
expect pass "ship-checks: E2E_EXCLUSIVE=1 → e2e waits for the repo's e2e lock, says so, then runs" \
  all_of code_is 0 , said "wait the e2e-$rid lock is held by pid $holder" , called "e2e.sh "
wait "$holder" 2> /dev/null; fresh_locks
gp worktree add -q --detach "$T/speed-wt"
expect pass "ship-checks: the e2e lock is one per clone (same id from another worktree)" \
  all_of test -n "$rid" , test "$(cd "$T/speed-wt" && "$GS" repo-id)" = "$rid"
srm "$T/speed-wt"; gp worktree prune

# --- bin/ship itself: the step is wired in, and the approval comment says when it reused -------
echo "ship wiring"
bump notes.txt   # a new input: no verdict recorded for it yet
(cd "$P" && dec=docs/work/7-x/decisions.md && review "$ok" "$ok" "" "$(git rev-parse HEAD)" && git commit -qam "pre-merge gate") || echo "FATAL review"
gp push -q origin feat/7-x 2> /dev/null
bs() { # bs [VAR=value ...]: bin/ship 12 against the fake gh; gh calls in $T/gh.log
  : > "$T/gh.log"
  sp GH_LABELS="$T/nolabels" GH_PAGES="$T/nopages" GH_LOG="$T/gh.log" GH_BRANCH=feat/7-x GH_HEAD="$(head_of)" \
    PATH="$T/fakebin:$PATH" "$@" bash bin/ship 12
}
bs FAKE_FAIL=e2e.sh
expect pass "ship: e2e fails → nothing written, ship BLOCKED" \
  all_of said "ship BLOCKED" , test -z "$(grep -E '^pr (merge|comment)' "$T/gh.log")"
bs
expect pass "ship: e2e and perf pass → merge, comment" all_of code_is 0 , called "e2e.sh " "perf.sh measure" , grep -q '^pr merge 12' "$T/gh.log"
bs
expect pass "ship: re-run on the same input → reused, and the approval comment says so" \
  all_of code_is 0 , nothing_called , grep -q 'e2e and perf passed (e2e and perf passed .* reused, not re-run' "$T/gh.log"

# --- The cases bite: drop one tagged line ("# bite: <name>") from a copy of the lib, run the
# cases that guard it against the copy, and some must go wrong.
echo "speed bites"
bite() { # bite <file under scripts/lib> <tag> <cases function>
  local w="$T/bite-$2"
  srm "$w"; mkdir -p "$w"; cp "$SKILL/scripts/lib/"*.sh "$w/"
  sed "/# bite: $2/d" "$SKILL/scripts/lib/$1" > "$w/$1"
  expect pass "bite: copy without '$2' lost exactly one line" \
    test "$(( $(wc -l < "$SKILL/scripts/lib/$1") - $(wc -l < "$w/$1") ))" = 1
  (pass=0; fail=0; "$3" STANDARDS_LIB="$w" > "$T/bite-$2.log" 2>&1; [ "$fail" -gt 0 ])
  bit=$?
  expect pass "bite: cases go wrong without '$2' ($(grep -c '^  WRONG' "$T/bite-$2.log") wrong)" test "$bit" = 0
}
bite parallel.sh count runner_cases
bite ship-checks.sh idle alone_cases
for tag in tree untracked base tools; do bite ship-checks.sh "$tag" key_cases; done
