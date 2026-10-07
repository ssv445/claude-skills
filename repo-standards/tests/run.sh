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
# review <reviewer A> <reviewer B> <arbiter> [reviewed sha, default HEAD]: rewrite the
# pre-merge gate lines in the working tree.
review() {
  awk -v a="$1" -v b="$2" -v c="$3" -v r="${4-$(git rev-parse HEAD)}" '
    /^## / { s = $0 }
    s == "## Pre-merge gate" && /^- Reviewer A:/ { $0 = "- Reviewer A: " a }
    s == "## Pre-merge gate" && /^- Reviewer B:/ { $0 = "- Reviewer B: " b }
    s == "## Pre-merge gate" && /^- Arbiter:/    { $0 = "- Arbiter: " c }
    s == "## Pre-merge gate" && /^Reviewed:/     { $0 = "Reviewed: " r }
    { print }' "$dec" > "$T/dec" && cp "$T/dec" "$dec"
}
aa() { expect "$1" "agent-approval: $2" .standards/checks/agent-approval.sh; }
ok="PASS — fine"; no="FAIL — misses empty input"
review "$ok" "$ok" ""
aa pass "gate PASS, both reviewers PASS"
review "PASS" "PASS" ""
aa pass "bare PASS"
review "$ok" "$no" ""
aa fail "reviewer FAIL, no arbiter"
review "$ok" "$no" "PASS — empty input is covered by the guard"
aa pass "reviewers disagree, arbiter PASS"
review "$ok" "$no" "FAIL — B is right"
aa fail "arbiter FAIL"
review "$no" "$no" "PASS — overruled both"
aa fail "both reviewers FAIL, arbiter PASS"
review "" "" "PASS — no reviewers ran"
aa fail "no reviewers, arbiter PASS"
review "PASSABLE" "$ok" ""
aa fail "PASSABLE is not PASS"
review "$ok" "$ok" ""
sed 's/^Verdict: PASS$/Verdict: PENDING/' "$dec" > "$T/dec" && cp "$T/dec" "$dec"
aa fail "pre-merge verdict not PASS"
git checkout -q docs
review "$ok" "$ok" ""
printf '\n## Pre-merge gate\n- Reviewer A: FAIL\nVerdict: FAIL\n' >> "$dec"
aa fail "duplicate Pre-merge gate section"
git checkout -q docs

review "$ok" "$ok" "" "$(git rev-parse HEAD~1)"
aa fail "review predates a code commit"
review "$ok" "$ok" "" ""
aa fail "no Reviewed sha"
review "$ok" "$ok" ""
git commit -qam "record pre-merge gate"
aa pass "only decisions.md changed since the reviewed commit"
git reset -q --hard HEAD~1
echo "v1" > "src/café.txt"; git add src; git commit -qm "café v1"
reviewed="$(git rev-parse HEAD)"
echo "v2" > "src/café.txt"; git commit -qam "café v2"
review "$ok" "$ok" "" "$reviewed"
aa fail "non-ASCII file changed after review"
git checkout -q docs; git reset -q --hard HEAD~2
review "$ok" "$ok" "" "HEAD"
aa fail "Reviewed: HEAD (symbolic name)"
review "$ok" "$ok" "" "feat/7-mul"
aa fail "Reviewed: <branch name>"
git branch abcdef0
review "$ok" "$ok" "" "abcdef0"
aa fail "Reviewed: hex-looking branch name"
git checkout -q docs; git branch -q -D abcdef0
review "$ok" "$ok" "" "0123456789abcdef0123456789abcdef01234567"
aa fail "Reviewed: sha not present locally"
git checkout -q docs

# Rebasing onto a base that changed other files keeps the review; the same file does not.
feat="$(git rev-parse HEAD)"; main0="$(git rev-parse main)"
git checkout -q main; echo "unrelated" > notes.txt; git add notes.txt; git commit -qm "main: notes"
git checkout -q feat/7-mul; git rebase -q main
review "$ok" "$ok" "" "$feat"
aa pass "rebased onto unrelated base change, review kept"
git checkout -q docs
git checkout -q main; { echo "# math helpers"; cat src/math.sh; } > "$T/m" && cp "$T/m" src/math.sh; git commit -qam "main: math header"
git checkout -q feat/7-mul; git rebase -q main
review "$ok" "$ok" "" "$feat"
aa fail "rebased onto base that changed a reviewed file"
git checkout -q docs
git checkout -q main; git reset -q --hard "$main0"; git checkout -q feat/7-mul; git reset -q --hard "$feat"

# Fail closed: no base to compare against.
git branch -q -D main
review "$ok" "$ok" ""
aa fail "no base commit (base ref deleted)"
git checkout -q docs; git branch -q main "$main0"

review "$ok" "$ok" ""
echo "owner-review: required — button copy is a taste call" >> "$dec"
aa fail "owner-review: required"
git checkout -q docs
review "$ok" "$ok" ""
echo "- owner-review: required — bulleted" >> "$dec"
aa fail "owner-review: required, bulleted"
git checkout -q docs
for flag in "Owner-review: required — caps" "owner-review:required — no space" "**owner-review: required** — bold" "- _owner-review: required_ — bulleted italic"; do
  review "$ok" "$ok" ""
  echo "$flag" >> "$dec"
  aa fail "flag variant: $flag"
  git checkout -q docs
done
echo "**Owner-Review:required** — loose" >> "$dec"; git commit -qam "loose flag"
git checkout -q HEAD~1 -- "$dec"; git commit -qam "unflag loose"
review "$ok" "$ok" ""
aa fail "loose owner-review flag removed on the branch"
git reset -q --hard HEAD~2
# A flag dropped only while resolving a merge.
feat="$(git rev-parse HEAD)"
echo "owner-review: required — merge test" >> "$dec"; git commit -qam "flag"
git checkout -q -b side; echo "side" > side.txt; git add side.txt; git commit -qm side
git checkout -q feat/7-mul; git merge -q --no-ff --no-commit side
git checkout -q "$feat" -- "$dec"; git commit -qm "merge side, dropping the flag"
review "$ok" "$ok" ""
aa fail "owner-review flag removed in a merge commit"
git checkout -q docs; git reset -q --hard "$feat"; git branch -q -D side
echo "owner-review: required — copy tone" >> "$dec"; git commit -qam "flag"
git checkout -q HEAD~1 -- "$dec"; git commit -qam "unflag"
review "$ok" "$ok" ""
aa fail "owner-review flag removed on the branch"
git reset -q --hard HEAD~2
echo "owner-approval: required" > docs/work/7-mul/spec.md; git add docs; git commit -qm spec
echo "owner-approval: not-required" > docs/work/7-mul/spec.md; git commit -qam "downgrade"
review "$ok" "$ok" ""
aa fail "owner-approval: required removed from the spec"
git reset -q --hard HEAD~2

echo "agents: keep it short" > CLAUDE.md
git add CLAUDE.md && git commit -qm "gate file"
review "$ok" "$ok" ""
aa fail "gate file (CLAUDE.md) in the diff"
git reset -q --hard HEAD~1
mkdir -p .github && echo "x" > .github/pr.md
git add .github && git commit -qm "gate dir"
review "$ok" "$ok" ""
aa fail "gate file (.github/) in the diff"
git reset -q --hard HEAD~1
mkdir -p .github && echo "x" > ".github/wörk.yml"
git add .github && git commit -qm "non-ASCII gate file"
review "$ok" "$ok" ""
aa fail "non-ASCII gate file under .github/"
git reset -q --hard HEAD~1
echo "x" > lefthook.yml; git add lefthook.yml && git commit -qm "hook manager config"
review "$ok" "$ok" ""
aa fail "gate file lefthook.yml in the diff"
git reset -q --hard HEAD~1
git mv .standards/hooks/pre-push pre-push-moved && git commit -qm "move a gate file out"
review "$ok" "$ok" ""
aa fail "gate file renamed out of .standards/"
git reset -q --hard HEAD~1
echo "src/* -> docs/guidelines/billing.md" >> docs/doc-map.txt && git commit -qam "loosen doc map"
review "$ok" "$ok" ""
aa fail "gate input docs/doc-map.txt in the diff"
git reset -q --hard HEAD~1

echo "approve"
# A fake gh logs every call; `script` gives approve the terminal it insists on.
mkdir -p "$T/fakebin"
cat > "$T/fakebin/gh" <<'EOF'
#!/bin/sh
echo "$*" >> "$GH_LOG"
case "$*" in *"--json labels"*) cat "$GH_LABELS" ;; esac
exit 0
EOF
chmod +x "$T/fakebin/gh"
approve_calls() { # approve_calls <labels already on the PR>: prints the label edits made
  printf '%s\n' "$1" > "$T/labels"; : > "$T/gh.log"
  # Typed after a pause: input piped at once reaches the pty before approve's prompt reads it.
  { sleep 0.5; printf '12\n'; sleep 0.5; } | GH_LOG="$T/gh.log" GH_LABELS="$T/labels" PATH="$T/fakebin:$PATH" \
    script -q /dev/null bash .standards/bin/approve 12 >/dev/null 2>&1
  grep -E -- '--(add|remove)-label' "$T/gh.log" | tr '\n' ';'
}
expect pass "approve: already approved → remove, then add (fresh event)" \
  test "$(approve_calls approved)" = "pr edit 12 --remove-label approved;pr edit 12 --add-label approved;"
expect pass "approve: not yet approved → add only" \
  test "$(approve_calls other)" = "pr edit 12 --add-label approved;"

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
for i in $(seq 1 30); do echo "x$i() { :; }"; done > "src/grö.sh"
git add src && git commit -qm "big, non-ASCII name"
expect fail "file-size: non-ASCII file name over max 20" .standards/checks/file-size.sh
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
