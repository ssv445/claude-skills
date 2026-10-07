#!/usr/bin/env bash
# Self-test for the repo-standards scripts. Builds a throwaway git repo in a temp dir,
# installs .standards/ into it, and proves each gate both FAILS and PASSES.
# Usage: bash repo-standards/tests/run.sh
set -u
SKILL="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0; fail=0

expect() { # expect <pass|fail> <name> <command...>
  local want="$1" name="$2"; shift 2
  if "$@" >"$T/last.log" 2>&1; then got=pass; else got=fail; fi
  if [ "$got" = "$want" ]; then pass=$((pass + 1)); printf '  ok    %-55s (%s)\n' "$name" "$got"
  else fail=$((fail + 1)); printf '  WRONG %-55s wanted %s, got %s\n' "$name" "$want" "$got"; sed 's/^/        | /' "$T/last.log"; fi
}

# --- guard: blocked and allowed commands ---
echo "guard"
for f in "$SKILL"/tests/guard-fixtures/*.json; do
  n="$(basename "$f" .json)"
  case "$n" in block-*) want=fail ;; *) want=pass ;; esac
  expect "$want" "guard $n" bash "$SKILL/scripts/guard.sh" < "$f"
done

# --- a tiny shell project with the standards installed ---
R="$T/repo"; mkdir -p "$R"; cd "$R" || exit 1
git init -q -b main
git config user.email t@example.invalid; git config user.name test
mkdir -p .standards src/billing tests docs/guidelines docs/work
cp -R "$SKILL/scripts/." .standards/
sed -e 's|^TEST_FILES_CMD=.*|TEST_FILES_CMD="./run-tests.sh"|' \
    -e 's|^UNIT_CMD=.*|UNIT_CMD="./run-tests.sh tests/*.test.sh"|' \
    -e 's|^FILE_SIZE_GLOBS=.*|FILE_SIZE_GLOBS="*.sh"|' \
    -e 's|^MAX_FILE_LINES=.*|MAX_FILE_LINES=20|' \
    "$SKILL/scripts/config.sh" > .standards/config.sh
cat > run-tests.sh <<'EOF'
#!/bin/sh
rc=0; for f in "$@"; do sh "$f" || { echo "test failed: $f"; rc=1; }; done; exit $rc
EOF
cat > src/math.sh <<'EOF'
add() { echo $(( $1 + $2 )); }
EOF
cat > tests/math.test.sh <<'EOF'
. src/math.sh; [ "$(add 1 2)" = 3 ]
EOF
printf 'src/billing/* -> docs/guidelines/billing.md\n' > docs/doc-map.txt
echo "# Billing" > docs/guidelines/billing.md
chmod +x run-tests.sh .standards/hooks/* .standards/checks/* .standards/bin/* .standards/guard.sh
git add -A && git commit -qm base

git checkout -q -b feat/7-mul
mkdir -p docs/work/7-mul
sed 's/Verdict: PENDING/Verdict: PASS/' "$SKILL/templates/decisions.md" > docs/work/7-mul/decisions.md
git add docs/work && git commit -qm "decision log"

echo "tdd"
cat >> src/math.sh <<'EOF'
mul() { echo $(( $1 * $2 )); }
EOF
git add src && git commit -qm "mul without test"
expect fail "tdd: source change with no test" .standards/checks/tdd.sh
cat > tests/mul.test.sh <<'EOF'
. src/math.sh; [ "$(add 2 2)" = 4 ]
EOF
git add tests && git commit -qm "test that does not exercise mul"
expect fail "tdd: test already green on base (not red)" .standards/checks/tdd.sh
cat > tests/mul.test.sh <<'EOF'
. src/math.sh; [ "$(mul 2 3)" = 6 ]
EOF
git add tests && git commit -qm "real mul test"
expect pass "tdd: red on base, green on HEAD" .standards/checks/tdd.sh

echo "doc-map"
echo 'charge() { :; }' > src/billing/charge.sh
cat > tests/charge.test.sh <<'EOF'
. src/billing/charge.sh; charge
EOF
git add src tests && git commit -qm "billing without doc"
expect fail "doc-map: mapped code changed, doc not" .standards/checks/doc-map.sh
echo "docs-unchanged: docs/guidelines/billing.md — internal helper only" >> docs/work/7-mul/decisions.md
git add docs && git commit -qm "exception"
expect pass "doc-map: docs-unchanged exception recorded" .standards/checks/doc-map.sh
git revert --no-edit HEAD >/dev/null
echo "charge() documented" >> docs/guidelines/billing.md
git add docs && git commit -qm "doc updated"
expect pass "doc-map: doc updated with code" .standards/checks/doc-map.sh

echo "decision-log"
expect pass "decision-log: spec + plan gates PASS" .standards/checks/decision-log.sh "Spec gate" "Plan gate"
expect fail "decision-log: pre-merge gate still PENDING" bash -c "sed 's/^Verdict: PASS$/Verdict: PENDING/' docs/work/7-mul/decisions.md > d.tmp && mv d.tmp docs/work/7-mul/decisions.md && .standards/checks/decision-log.sh 'Spec gate'; rc=\$?; git checkout -q docs; exit \$rc"
git checkout -q -b chore-no-issue
expect fail "decision-log: branch without issue number" .standards/checks/decision-log.sh "Spec gate"
git checkout -q feat/7-mul; git branch -q -D chore-no-issue

echo "agent-approval"
dec=docs/work/7-mul/decisions.md
review() { # review <reviewer A> <reviewer B> <arbiter>: rewrite the pre-merge gate lines
  awk -v a="$1" -v b="$2" -v c="$3" '
    /^## / { s = $0 }
    s == "## Pre-merge gate" && /^- Reviewer A:/ { $0 = "- Reviewer A: " a }
    s == "## Pre-merge gate" && /^- Reviewer B:/ { $0 = "- Reviewer B: " b }
    s == "## Pre-merge gate" && /^- Arbiter:/    { $0 = "- Arbiter: " c }
    { print }' "$dec" > "$T/dec" && cp "$T/dec" "$dec"
}
review "PASS — fine" "PASS — fine" ""
expect pass "agent-approval: gate PASS, both reviewers PASS" .standards/checks/agent-approval.sh
review "PASS — fine" "FAIL — misses empty input" ""
expect fail "agent-approval: reviewer FAIL, no arbiter" .standards/checks/agent-approval.sh
review "PASS — fine" "FAIL — misses empty input" "PASS — empty input is covered by the guard"
expect pass "agent-approval: reviewers disagree, arbiter PASS" .standards/checks/agent-approval.sh
review "PASS — fine" "FAIL — misses empty input" "FAIL — B is right"
expect fail "agent-approval: arbiter FAIL" .standards/checks/agent-approval.sh
review "PASS — fine" "PASS — fine" ""
sed 's/^Verdict: PASS$/Verdict: PENDING/' "$dec" > "$T/dec" && cp "$T/dec" "$dec"
expect fail "agent-approval: pre-merge verdict not PASS" .standards/checks/agent-approval.sh
git checkout -q docs
review "PASS — fine" "PASS — fine" ""
echo "owner-review: required — button copy is a taste call" >> "$dec"
expect fail "agent-approval: owner-review: required" .standards/checks/agent-approval.sh
git checkout -q docs
review "PASS — fine" "PASS — fine" ""
echo "agents: keep it short" > CLAUDE.md
git add CLAUDE.md && git commit -qm "gate file"
expect fail "agent-approval: gate file (CLAUDE.md) in the diff" .standards/checks/agent-approval.sh
git reset -q --hard HEAD~1
review "PASS — fine" "PASS — fine" ""
mkdir -p .github && echo "x" > .github/pr.md
git add .github && git commit -qm "gate dir"
expect fail "agent-approval: gate file (.github/) in the diff" .standards/checks/agent-approval.sh
git reset -q --hard HEAD~1

echo "coverage-baseline"
echo 85 > .standards/coverage-baseline
expect fail "coverage: total 80 below baseline 85" env COVERAGE_TOTAL_CMD="echo 80" bash -c '. .standards/config.sh; COVERAGE_TOTAL_CMD="echo 80"; sed -i.bak "s|^COVERAGE_TOTAL_CMD=.*|COVERAGE_TOTAL_CMD=\"echo 80\"|" .standards/config.sh; .standards/checks/coverage-baseline.sh; rc=$?; mv .standards/config.sh.bak .standards/config.sh; exit $rc'
expect pass "coverage: total 90 at/above baseline 85" bash -c 'sed -i.bak "s|^COVERAGE_TOTAL_CMD=.*|COVERAGE_TOTAL_CMD=\"echo 90\"|" .standards/config.sh; .standards/checks/coverage-baseline.sh; rc=$?; mv .standards/config.sh.bak .standards/config.sh; exit $rc'
rm .standards/coverage-baseline

echo "file-size"
expect pass "file-size: small files" .standards/checks/file-size.sh
for i in $(seq 1 30); do echo "x$i() { :; }"; done > src/big.sh
git add src && git commit -qm big
expect fail "file-size: 30-line file over max 20" .standards/checks/file-size.sh
git reset -q --hard HEAD~1

echo "roadmap"
expect pass "roadmap: absent (product layer not used)" .standards/checks/roadmap.sh
mkdir -p docs/product
cp "$SKILL"/tests/roadmap-fixtures/goals.md "$SKILL"/tests/roadmap-fixtures/assumptions.md docs/product/
for f in "$SKILL"/tests/roadmap-fixtures/roadmap-*.md; do
  n="$(basename "$f" .md)"
  cp "$f" docs/product/roadmap.md
  case "$n" in roadmap-valid) want=pass ;; *) want=fail ;; esac
  expect "$want" "roadmap: ${n#roadmap-}" .standards/checks/roadmap.sh
done
cp "$SKILL"/templates/product/goals.md "$SKILL"/templates/product/assumptions.md "$SKILL"/templates/product/roadmap.md docs/product/
expect pass "roadmap: installed templates are valid" .standards/checks/roadmap.sh
rm -rf docs/product

echo "pre-push"
head="$(git rev-parse HEAD)"; z=0000000000000000000000000000000000000000
printf 'refs/heads/feat/7-mul %s refs/heads/feat/7-mul %s\n' "$head" "$z" > "$T/refs-branch"
printf 'refs/heads/feat/7-mul %s refs/heads/main %s\n' "$head" "$z" > "$T/refs-main"
expect pass "pre-push: clean branch, all gates green" .standards/hooks/pre-push < "$T/refs-branch"
expect fail "pre-push: push to main" .standards/hooks/pre-push < "$T/refs-main"
echo 'broken' >> tests/math.test.sh
expect fail "pre-push: uncommitted changes" .standards/hooks/pre-push < "$T/refs-branch"
git commit -qam "break a test"
printf 'refs/heads/feat/7-mul %s refs/heads/feat/7-mul %s\n' "$(git rev-parse HEAD)" "$z" > "$T/refs-branch2"
expect fail "pre-push: failing unit test" .standards/hooks/pre-push < "$T/refs-branch2"

echo
echo "$pass passed, $fail wrong"
[ $fail -eq 0 ]
