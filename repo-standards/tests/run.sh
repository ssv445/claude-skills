#!/usr/bin/env bash
# Self-test for the repo-standards scripts. Builds a throwaway git repo in a temp dir,
# installs .standards/ into it, and proves each gate both FAILS and PASSES.
# Usage: bash repo-standards/tests/run.sh
set -u
SKILL="$(cd "$(dirname "$0")/.." && pwd)"
TMPROOT="${TMPDIR:-/tmp}"; TMPROOT="${TMPROOT%/}"
T="$(mktemp -d "$TMPROOT/repo-standards-test.XXXXXX")" || exit 1
# The one bare rm in this file (the rm lint allows it by its marker): safe_rm lives in an
# installed common.sh, which may not exist when this trap fires. ${T:?} and the case keep it
# to the dir mktemp just made under the temp root.
trap 'case "${T:?}" in "$TMPROOT"/repo-standards-test.?*) rm -rf -- "$T" ;; esac' EXIT  # rm-lint: allow
pass=0; fail=0
# srm <path>...: delete through safe_rm from the test repo's installed common.sh, with every
# path anchored on $R. A refusal leaves state the later tests would misread: stop the run.
srm() { (cd "${R:?}" && bash "$SKILL/tests/saferm-fixtures/safe-rm.sh" "$@") || { echo "FATAL safe_rm refused: $*"; exit 1; }; }

expect() { # expect <pass|fail> <name> <command...>
  local want="$1" name="$2"; shift 2
  [ -f "$T/last.log" ] && cp "$T/last.log" "$T/last.log.prev"
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
# Fail closed without jq: a PATH holding every tool the guard uses but jq. The command is
# one the guard allows, so only the missing jq can block it.
mkdir -p "$T/nojq"
for t in cat git dirname awk sed grep head tr; do ln -s "$(command -v "$t")" "$T/nojq/$t"; done
expect fail "guard: no jq on PATH → blocks (fail closed)" \
  env PATH="$T/nojq" /bin/bash "$SKILL/scripts/guard.sh" < "$SKILL/tests/guard-fixtures/allow-push.json"
expect pass "guard: no jq → says it needs jq, and how to install it" grep -q "guard needs jq.*brew install jq" "$T/last.log.prev"
# Without jq: still out of scope from a cwd outside this repo, and installing jq (exactly, no
# options) is the way out. nojq-block-* fixtures are harmless with jq (above: pass), blocked without.
for f in "$SKILL"/tests/guard-fixtures/*nojq*.json; do
  n="$(basename "$f" .json)"
  case "$n" in block-*|nojq-block-*) want=fail ;; *) want=pass ;; esac
  expect "$want" "guard (no jq) $n" env PATH="$T/nojq" /bin/bash "$SKILL/scripts/guard.sh" < "$f"
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
    -e 's|^APPROVER=.*|APPROVER="owner"|' \
    "$SKILL/scripts/config.sh" > .standards/config.sh
# The shipped default is agent mode; fixtures start in owner mode and switch the base explicitly.
expect pass "config: template default is APPROVER=agent" grep -qx 'APPROVER="agent"' "$SKILL/scripts/config.sh"
# The install copies scripts/ to .standards/, so scripts/VERSION becomes .standards/VERSION: it
# must be the version in SKILL.md's frontmatter, or an upgrade diffs against the wrong release.
skill_version="$(sed -n '1,/^---$/{s/^version: *//p;}' "$SKILL/SKILL.md" | head -1)"
expect pass "version: scripts/VERSION = SKILL.md version ($skill_version)" \
  test -n "$skill_version" -a "$(cat "$SKILL/scripts/VERSION" 2>/dev/null)" = "$skill_version"
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
expect pass "tdd: scratch checkout removed (drop_worktree)" test "$(git worktree list | wc -l | tr -d ' ')" = 1

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

echo "guard scope"
# The guard installed in this repo, fed hook JSON with a cwd. It judges commands aimed at
# this repo only, and blocks executing the approve script, not mentioning it.
git remote add origin https://github.com/acme/app.git
mkdir -p "$T/elsewhere"
g() { # g <pass|fail> <name> <cwd> <command>
  jq -cn --arg d "$3" --arg c "$4" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' > "$T/g.json"
  expect "$1" "guard: $2" bash .standards/guard.sh < "$T/g.json"
}
g fail "merge in this repo"                    "$R" "gh pr merge 12 --squash"
g fail "cd into this repo's subdir, then merge" "$T/elsewhere" "cd $R/src && gh pr merge 12"
g pass "cd to another repo, then merge"        "$R" "cd $T/elsewhere && gh pr merge 25"
g pass "session cwd is another repo"           "$T/elsewhere" "gh pr merge 25"
g pass "merge with -R other/repo"              "$R" "gh pr merge 25 -R other/repo"
g pass "merge with --repo=other/repo"          "$R" "gh pr merge 25 --repo=other/repo"
g fail "merge with -R naming this repo"        "$R" "gh pr merge 12 -R acme/app"
g pass "git -C another repo push --no-verify"  "$R" "git -C $T/elsewhere push --no-verify"
g fail "approve script run"                    "$R" "bin/approve 12"
g fail "approve script run via ./ and bash"    "$R" "./bin/approve 12; bash bin/approve 12"
g fail "approve script run after &&"           "$R" "git status && bin/approve 12"
g pass "approve script read with cat"          "$R" "cat bin/approve"
g pass "approve script grepped"                "$R" "grep -n label bin/approve"
g pass "approve script named in a heredoc body" "$R" "$(printf 'cat > notes.md <<%sEOF%s\nbin/approve 12\nEOF' "'" "'")"
g pass "approve script named in a commit message" "$R" "git commit -m 'owner runs bin/approve 12'"
g pass "hooksPath read with --get"             "$R" "git config --get core.hooksPath"
g pass "hooksPath read bare"                   "$R" "git config core.hooksPath"
g fail "hooksPath set"                         "$R" "git config core.hooksPath /dev/null"
g fail "hooksPath set with -c"                 "$R" "git -c core.hooksPath=/dev/null push"
g fail "hooksPath unset"                       "$R" "git config --unset core.hooksPath"
git remote remove origin

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
# Diff-only re-review after a fix round: "Reviewed: <new sha> (delta from <old sha>)". The new sha
# must cover HEAD like a full review's; the old one must be a commit present here.
review "$ok" "$ok" "" "$(git rev-parse HEAD) (delta from $(git rev-parse HEAD~1))"
aa pass "Reviewed: <sha> (delta from <old sha>), new sha covers HEAD"
expect pass "agent-approval: ... says it reviewed the delta" grep -q "review covers HEAD (reviewed $(git rev-parse HEAD), delta from $(git rev-parse HEAD~1))" "$T/last.log.prev"
review "$ok" "$ok" "" "$(git rev-parse --short HEAD) (delta from $(git rev-parse --short HEAD~2))"
aa pass "Reviewed: short shas in the delta form"
review "$ok" "$ok" "" "$(git rev-parse HEAD~1) (delta from $(git rev-parse HEAD~2))"
aa fail "delta form whose new sha predates a code commit"
review "$ok" "$ok" "" "$(git rev-parse HEAD) (delta from 0123456789abcdef0123456789abcdef01234567)"
aa fail "delta from a sha not present locally"
review "$ok" "$ok" "" "$(git rev-parse HEAD) (delta from HEAD~1)"
aa fail "delta from a symbolic name"
review "$ok" "$ok" "" "$(git rev-parse HEAD) (looked again)"
aa fail "Reviewed: sha with some other suffix"
git checkout -q docs

# Rebasing onto a base that changed other files keeps the review; the same file does not.
feat="$(git rev-parse HEAD)"; main0="$(git rev-parse main)"
git checkout -q main; echo "unrelated" > notes.txt; git add notes.txt; git commit -qm "main: notes"
git checkout -q feat/7-mul; git rebase -q main
review "$ok" "$ok" "" "$feat"
aa pass "rebased onto unrelated base change, review kept"
review "$ok" "$ok" "" "$feat (delta from $(git rev-parse "$feat~1"))"
aa pass "rebased onto unrelated base change, delta review kept (no re-review)"
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
expect fail "agent-approval --gate-files: no base → fails closed" .standards/checks/agent-approval.sh --gate-files
git checkout -q docs; git branch -q main "$main0"

review "$ok" "$ok" ""
echo "owner-review: required — button copy is a taste call" >> "$dec"
aa fail "owner-review: required"
git checkout -q docs
review "$ok" "$ok" ""
echo "- owner-review: required — bulleted" >> "$dec"
aa fail "owner-review: required, bulleted"
git checkout -q docs
for flag in "Owner-review: required — caps" "owner-review:required — no space" "**owner-review: required** — bold" "- _owner-review: required_ — bulleted italic" \
            "**owner-review**: required — bold name" "**owner-review:** required — bold name and colon" "* owner-review: required — star bullet" \
            "  owner-review: required — indented 2"; do
  review "$ok" "$ok" ""
  echo "$flag" >> "$dec"
  aa fail "flag variant: $flag"
  git checkout -q docs
done
review "PASS — fine; owner-review: required — tone of the error copy" "$ok" ""
aa fail "flag inside a reviewer line"
review "$ok" "$ok" ""
echo "    owner-review: required — indented 4, an example" >> "$dec"
aa pass "flag indented 4+ spaces is an example, not a flag"
git checkout -q docs
review "$ok" "$ok" ""
# Inside the Pre-merge gate section, which is no longer the file's last.
awk '{ print } /^## / { s = $0 } s == "## Pre-merge gate" && /^- Reviewer B:/ { print "- Reviewer B: FAIL — a second B line" }' "$dec" > "$T/dec" && cp "$T/dec" "$dec"
aa fail "duplicate reviewer line in the Pre-merge gate"
git checkout -q docs
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
# An answered flag closes without bin/approve: the agent turns the required line into
# "owner-review: answered — <reason as in the flag> — <link> — <answer>". Each removed flag
# needs its own answered line, same reason, added on this branch; any other removal still
# needs the owner.
url="https://github.com/acme/app/pull/12#issuecomment-1"
answer() { # answer <line>: commit a flag, then commit it replaced by <line>; review HEAD
  echo "owner-review: required — copy tone" >> "$dec"; git commit -qam "flag"
  grep -v '^owner-review: required — copy tone$' "$dec" > "$T/dec"; printf '%s\n' "$1" >> "$T/dec"
  cp "$T/dec" "$dec"; git commit -qam "answer"
  review "$ok" "$ok" ""
}
answered() { git checkout -q docs; git reset -q --hard HEAD~2; }
answer "owner-review: answered — copy tone — $url — \"keep it formal\""
aa pass "owner-review flag closed as answered (reason + link + answer)"
answered
answer "- owner-review: answered — Copy tone — $url — \"yes, the field stays required\""
aa pass "answered line whose quoted answer says 'required'"
answered
answer "owner-review: answered — copy tone — <link to the owner's answer> — \"keep it formal\""
aa fail "answered with a placeholder link"
answered
answer "owner-review: answered — copy tone — $url — <the answer, quoted>"
aa fail "answered with a placeholder answer"
answered
answer "owner-review: answered — <reason as in the flag> — $url — \"keep it formal\""
aa fail "answered with a placeholder reason"
answered
answer "owner-review: answered — copy tone — $url — ok; owner-review: required — still open"
aa fail "answered line hiding an open flag"
answered
answer "owner-review: answered — copy tone — $url"
aa fail "answered with a link but no answer"
answered
answer "owner-review: answered — $url — \"keep it formal\""
aa fail "answered without the flag's reason"
answered
answer "owner-review: answered — price — $url — \"keep it formal\""
aa fail "answered with another flag's reason"
answered
flags() { printf 'owner-review: required — %s\n' "$@"; }                       # flags <reason>...
ans() { printf 'owner-review: answered — %s — %s — "%s"\n' "$1" "$url" "$2"; }  # ans <reason> <answer>
close() { # close <file> [line...]: drop every open flag from <file>, append the lines
  local f="$1"; shift
  grep -v '^owner-review: required' "$f" > "$T/dec"; [ $# -eq 0 ] || printf '%s\n' "$@" >> "$T/dec"; cp "$T/dec" "$f"
}
c() { git add docs; git commit -qm "$1"; }
flags price tone >> "$dec"; c flags; close "$dec" "$(ans tone formal)"; c answer; review "$ok" "$ok" ""
aa fail "two flags removed, only one answered"
answered
flags price tone >> "$dec"; c flags; close "$dec" "$(ans price yes)" "$(ans tone formal)"; c answer; review "$ok" "$ok" ""
aa pass "two flags removed, each answered with its reason"
answered
# The same answered line twice does not close a second, different flag.
flags price tone >> "$dec"; c flags; close "$dec" "$(ans price yes)" "$(ans price yes)"; c answer; review "$ok" "$ok" ""
aa fail "one answered line duplicated, a second flag dropped"
answered
# The same flag text in spec.md and decisions.md is two flags: one answer closes one.
flags price >> "$dec"; flags price > docs/work/7-mul/spec.md; c flags
close "$dec" "$(ans price yes)"; close docs/work/7-mul/spec.md; c answer; review "$ok" "$ok" ""
aa fail "identical flags in spec and decisions, one answered"
answered
flags price >> "$dec"; flags price > docs/work/7-mul/spec.md; c flags
close "$dec" "$(ans price yes)"; close docs/work/7-mul/spec.md "$(ans price yes)"; c answer; review "$ok" "$ok" ""
aa pass "identical flags in spec and decisions, each answered"
answered
flags price > docs/work/7-mul/spec.md; c "spec flag"; review "$ok" "$ok" ""
aa fail "open owner-review flag in spec.md"
git checkout -q docs; git reset -q --hard HEAD~1
# An answered line already on the base (an earlier PR on this issue) closes nothing new.
feat="$(git rev-parse HEAD)"; main0="$(git rev-parse main)"
git checkout -q main; mkdir -p docs/work/7-mul; ans price yes > docs/work/7-mul/earlier.md; c "main: PR 1 on issue 7"
git checkout -q feat/7-mul; git rebase -q main
flags price >> "$dec"; c flags; close "$dec"; c "drop the flag"; review "$ok" "$ok" ""
aa fail "answered line on the base reused to drop a new flag"
git checkout -q docs
git checkout -q main; git reset -q --hard "$main0"; git checkout -q feat/7-mul; git reset -q --hard "$feat"
# A reason needs a letter or digit. A flag's reason may come before the token.
TAB="$(printf '\t')"
echo "owner-review: required" >> "$dec"; c flags; close "$dec" "owner-review: answered — $TAB — $url — \"unrelated\""; c answer; review "$ok" "$ok" ""
aa fail "flag with no reason closed by an answer with a blank reason"
expect pass "agent-approval: a reasonless flag is the owner's (bin/approve)" grep -q "only the owner can close it (bin/approve" "$T/last.log.prev"
answered
echo "Price change — owner-review: required" >> "$dec"; c flags
grep -v 'owner-review: required' "$dec" > "$T/dec"; echo "owner-review: answered — $TAB — $url — \"formal\"" >> "$T/dec"; cp "$T/dec" "$dec"; c answer; review "$ok" "$ok" ""
aa fail "reason-first flag closed by an answer with a blank reason"
answered
echo "Price change — owner-review: required" >> "$dec"; c flags
grep -v 'owner-review: required' "$dec" > "$T/dec"; ans "price change" "99" >> "$T/dec"; cp "$T/dec" "$dec"; c answer; review "$ok" "$ok" ""
aa pass "reason-first flag closed by an answer with its reason"
answered
# Every folder for the issue is read: a second one cannot hide a flag, and decisions.md must be one.
echo "owner-review: required — price" >> "$dec"; c flags
mkdir -p docs/work/7-a; cp "$dec" docs/work/7-a/decisions.md; close docs/work/7-a/decisions.md; c "decoy folder"; review "$ok" "$ok" ""
# The decoy's own pre-merge gate covers HEAD, so only the hidden flag can stop it.
awk -v r="$(git rev-parse HEAD)" '/^## /{s=$0} s=="## Pre-merge gate" && /^Reviewed:/{$0="Reviewed: " r}
  s=="## Pre-merge gate" && /^- Reviewer [AB]:/{sub(/:.*/, ": PASS")} {print}' docs/work/7-a/decisions.md > "$T/d7a" && cp "$T/d7a" docs/work/7-a/decisions.md
aa fail "a second folder for the issue (decoy) next to an open flag"
expect pass "agent-approval: names both folders for the issue" grep -q "more than one folder for issue #7" "$T/last.log.prev"
answered
flags price > docs/work/7-mul/plan.md; c "flag in plan notes"; review "$ok" "$ok" ""
aa fail "open owner-review flag in another file of the issue folder"
git checkout -q docs; git reset -q --hard HEAD~1
echo "owner-approval: required" > docs/work/7-mul/spec.md; git add docs; git commit -qm spec
echo "owner-approval: not-required" > docs/work/7-mul/spec.md; git commit -qam "downgrade"
review "$ok" "$ok" ""
aa fail "owner-approval: required removed from the spec"
git reset -q --hard HEAD~2
echo "**Owner-Approval**: required" > docs/work/7-mul/spec.md; git add docs; git commit -qm spec
cp "$SKILL/templates/spec.md" docs/work/7-mul/spec.md; git commit -qam "downgrade to template default"
review "$ok" "$ok" ""
aa fail "bold owner-approval removed from the spec"
git reset -q --hard HEAD~2
cp "$SKILL/templates/spec.md" docs/work/7-mul/spec.md; git add docs; git commit -qm spec
echo "# spec without the approval line" > docs/work/7-mul/spec.md; git commit -qam "drop not-required"
review "$ok" "$ok" ""
aa pass "removing owner-approval: not-required is no flag removal"
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
mkdir -p .Claude && echo "{}" > .Claude/settings.json
git add .Claude && git commit -qm "gate dir, other case"
review "$ok" "$ok" ""
aa fail "gate file in a differently-cased dir (.Claude/)"
git reset -q --hard HEAD~1

# Only the repo-standards block of CLAUDE.md / AGENTS.md is a gate file: the facts around it
# are any PR's to edit. Markers missing or malformed on either side → the whole file counts.
# The base holds facts plus the real installed block, so the template's markers are proven too.
feat="$(git rev-parse HEAD)"; main0="$(git rev-parse main)"
git checkout -q main
{ echo "# App"; echo "Folders: src/"; echo; cat "$SKILL/templates/claude-md-block.md"; echo; echo "Ports: 3000"; } > CLAUDE.md
mkdir -p web; cp CLAUDE.md web/AGENTS.md
git add CLAUDE.md web && git commit -qm "main: CLAUDE.md with block"
git checkout -q feat/7-mul; git rebase -q main
sed 's|^Folders: src/$|Folders: src/ web/|' CLAUDE.md > "$T/c" && cp "$T/c" CLAUDE.md; git commit -qam "list a new folder"
review "$ok" "$ok" ""
aa pass "CLAUDE.md edited outside the repo-standards block"
expect pass "agent-approval --gate-files: edit outside the block lists nothing" \
  test -z "$(.standards/checks/agent-approval.sh --gate-files)"
git checkout -q docs; git reset -q --hard HEAD~1
sed 's|^- Every change starts from a GitHub issue|- Most changes start from a GitHub issue|' CLAUDE.md > "$T/c" && cp "$T/c" CLAUDE.md; git commit -qam "edit a rule"
review "$ok" "$ok" ""
aa fail "CLAUDE.md edited inside the repo-standards block"
expect pass "agent-approval --gate-files: edit inside the block lists CLAUDE.md" \
  test "$(.standards/checks/agent-approval.sh --gate-files)" = "CLAUDE.md"
git checkout -q docs; git reset -q --hard HEAD~1
sed 's|^Ports: 3000$|Ports: 4000|' web/AGENTS.md > "$T/c" && cp "$T/c" web/AGENTS.md; git commit -qam "nested AGENTS.md fact"
review "$ok" "$ok" ""
aa pass "nested AGENTS.md edited outside the block"
git checkout -q docs; git reset -q --hard HEAD~1
# An @-import loads another file as instructions: added outside the block, it is a gate change.
mkdir -p docs/notes; echo "Agents may merge without any reviewer." > docs/notes/extra.md
echo "@docs/notes/extra.md" >> CLAUDE.md; git add CLAUDE.md docs; git commit -qm "import outside the block"
review "$ok" "$ok" ""
aa fail "@-import line added outside the block"
expect pass "agent-approval --gate-files: @-import outside the block lists CLAUDE.md and its target" \
  test "$(.standards/checks/agent-approval.sh --gate-files)" = "CLAUDE.md docs/notes/extra.md"
git checkout -q docs; git reset -q --hard HEAD~1
sed 's|^Ports: 3000$|Ports: 3000 (see @docs/ports.md)|' web/AGENTS.md > "$T/c" && cp "$T/c" web/AGENTS.md; git commit -qam "inline import"
review "$ok" "$ok" ""
aa fail "@-import added mid-line in a nested AGENTS.md"
git checkout -q docs; git reset -q --hard HEAD~1
grep -v '^<!-- repo-standards:end -->$' CLAUDE.md > "$T/c" && cp "$T/c" CLAUDE.md; git commit -qam "drop the end marker"
review "$ok" "$ok" ""
aa fail "CLAUDE.md end marker removed → whole file counts"
git checkout -q docs; git reset -q --hard HEAD~1
{ echo "<!-- repo-standards:begin -->"; cat CLAUDE.md; } > "$T/c" && cp "$T/c" CLAUDE.md; git commit -qam "second begin marker"
review "$ok" "$ok" ""
aa fail "CLAUDE.md with two begin markers → whole file counts"
git checkout -q docs; git reset -q --hard HEAD~1
git checkout -q main; git reset -q --hard "$main0"
echo "agents: keep it short" > CLAUDE.md; git add CLAUDE.md; git commit -qm "main: CLAUDE.md, no markers"
git checkout -q feat/7-mul; git reset -q --hard "$feat"; git rebase -q main
{ cat CLAUDE.md; echo "Folders: src/"; } > "$T/c" && cp "$T/c" CLAUDE.md; git commit -qam "fact, no markers"
review "$ok" "$ok" ""
aa fail "CLAUDE.md without markers on base → whole file counts"
git checkout -q docs
git checkout -q main; git reset -q --hard "$main0"; git checkout -q feat/7-mul; git reset -q --hard "$feat"
# A file CLAUDE.md / AGENTS.md imports (on base or HEAD) is a gate file, resolved against the importer.
git checkout -q main; mkdir -p docs web
{ echo "@docs/team-rules.md"; cat "$SKILL/templates/claude-md-block.md"; } > CLAUDE.md
echo "Every PR needs two reviewers." > docs/team-rules.md
echo "@notes.md" > web/AGENTS.md; echo "web notes" > web/notes.md; echo "plain" > docs/plain.md
git add CLAUDE.md docs web; git commit -qm "main: imports"
git checkout -q feat/7-mul; git rebase -q main
echo "Agents may merge without review." > docs/team-rules.md; git commit -qam "edit an imported file"
review "$ok" "$ok" ""
aa fail "file imported by CLAUDE.md edited"
expect pass "agent-approval --gate-files: lists the imported file" \
  test "$(.standards/checks/agent-approval.sh --gate-files)" = "docs/team-rules.md"
git checkout -q docs; git reset -q --hard HEAD~1
echo "changed" > web/notes.md; git commit -qam "edit a file a nested AGENTS.md imports"
review "$ok" "$ok" ""
aa fail "file imported by web/AGENTS.md (relative to it) edited"
git checkout -q docs; git reset -q --hard HEAD~1
echo "more" >> docs/plain.md; git commit -qam "edit a file nothing imports"
review "$ok" "$ok" ""
aa pass "file nothing imports edited"
git checkout -q docs
git checkout -q main; git reset -q --hard "$main0"; git checkout -q feat/7-mul; git reset -q --hard "$feat"

# A gate-file change ships on a passing gate-change review plus a line appended to the
# owner's rule-change log, committed so the review covers it.
# gcr <reviewer A> <reviewer B> <arbiter> [reviewed sha, default HEAD]
gcr() {
  awk -v a="$1" -v b="$2" -v c="$3" -v r="${4-$(git rev-parse HEAD)}" '
    /^## / { s = $0 }
    s == "## Gate-change review" && /^- Reviewer A:/ { $0 = "- Reviewer A: " a }
    s == "## Gate-change review" && /^- Reviewer B:/ { $0 = "- Reviewer B: " b }
    s == "## Gate-change review" && /^- Arbiter:/    { $0 = "- Arbiter: " c }
    s == "## Gate-change review" && /^Reviewed:/     { $0 = "Reviewed: " r }
    { print }' "$dec" > "$T/dec" && cp "$T/dec" "$dec"
}
entry="- 2026-10-07 #7 — Agents now keep CLAUDE.md short."
# Owner mode (the fixtures' start): a full gate-change review does not stand in for the owner.
echo "agents: keep it short" > CLAUDE.md; echo "$entry" > docs/rule-changes.md
git add CLAUDE.md docs && git commit -qm "gate file + log line"
review "$ok" "$ok" ""; gcr "$ok" "$ok" ""
aa fail "APPROVER=owner → gate change with a passing gate-change review still needs the owner"
git checkout -q docs; git reset -q --hard HEAD~1
# Agent mode, set on the base.
feat1="$(git rev-parse HEAD)"; main1="$(git rev-parse main)"
git checkout -q main; sed 's/^APPROVER=.*/APPROVER="agent"/' .standards/config.sh > "$T/c" && cp "$T/c" .standards/config.sh
git commit -qam "APPROVER=agent"; git checkout -q feat/7-mul; git rebase -q main
echo "agents: keep it short" > CLAUDE.md
git add CLAUDE.md && git commit -qm "gate file, no log entry"
review "$ok" "$ok" ""; gcr "$ok" "$ok" ""
aa fail "gate file changed, review PASS, no rule-change log entry"
git checkout -q docs
cp "$SKILL/templates/rule-changes.md" docs/rule-changes.md; git add docs; git commit -qm "log template only"
review "$ok" "$ok" ""; gcr "$ok" "$ok" ""
aa fail "rule-change log holds only the template's example line"
git checkout -q docs
echo "$entry" >> docs/rule-changes.md; git commit -qam "log entry"
review "$ok" "$ok" ""; gcr "$ok" "$ok" ""
aa pass "gate file changed, gate-change review PASS + log entry"
cp "$T/last.log" "$T/aa.log"
expect pass "agent-approval: names the changed gate files for bin/ship" \
  grep -q "ok   gate files changed, approved under APPROVER=agent (gate-change review PASS): CLAUDE.md" "$T/aa.log"
git checkout -q docs
review "$ok" "$ok" ""; gcr "$ok" "$no" "PASS — B misread the diff"
aa pass "gate-change reviewers split, arbiter PASS"
git checkout -q docs
review "$ok" "$ok" ""; gcr "$ok" "$no" ""
aa fail "gate-change reviewer FAIL, no arbiter"
git checkout -q docs
review "$ok" "$ok" ""; gcr "$ok" "$ok" ""
sed 's/^Verdict: PASS$/Verdict: PENDING/' "$dec" | awk '/^## Gate-change review$/ { g = 1 } !g && /^Verdict:/ { sub(/PENDING/, "PASS") } { print }' > "$T/dec" && cp "$T/dec" "$dec"
aa fail "gate-change verdict not PASS"
git checkout -q docs
review "$ok" "$ok" ""; gcr "$ok" "$ok" "" "$(git rev-parse HEAD~2)"
aa fail "gate-change review predates the gate-file commit"
git checkout -q docs
# The log line is what the owner reads: rewording it after the review needs a new review.
reviewed="$(git rev-parse HEAD)"
sed 's/short\./short (and also drops the doc map)./' docs/rule-changes.md > "$T/log" && cp "$T/log" docs/rule-changes.md; git commit -qam "reword entry"
review "$ok" "$ok" "" "$reviewed"; gcr "$ok" "$ok" "" "$reviewed"
aa fail "log entry reworded after the gate-change review"
git checkout -q docs; git reset -q --hard HEAD~1
review "$ok" "$ok" ""; gcr "$ok" "$ok" ""
printf '\n## Gate-change review\n- Reviewer A: FAIL\nVerdict: FAIL\n' >> "$dec"
aa fail "duplicate Gate-change review section"
git checkout -q docs
review "$ok" "$ok" ""; gcr "$ok" "$ok" ""
echo "owner-review: required — this drops the doc-map check" >> "$dec"
aa fail "gate-change review PASS, but owner-review flag raised"
git checkout -q docs
review "$no" "$no" ""; gcr "$ok" "$ok" ""
aa fail "gate-change review PASS, but pre-merge gate FAIL"
git checkout -q docs
review "$no" "$no" ""; gcr "$no" "$no" ""
aa fail "gate-change and pre-merge both FAIL"
expect pass "agent-approval: no false 'gate-change review PASS' line after an earlier miss" \
  bash -c "! grep -q 'ok   gate files changed' '$T/last.log.prev'"
git checkout -q docs
review "$ok" "$ok" ""
awk '/^## Gate-change review$/ { g = 1; next } g && /^## / { g = 0 } !g' "$dec" > "$T/dec" && cp "$T/dec" "$dec"
aa fail "gate file changed, no Gate-change review section"
git checkout -q docs
git checkout -q main; git reset -q --hard "$main1"; git checkout -q feat/7-mul; git reset -q --hard "$feat1"

# The rule-change log only grows, on any branch.
feat="$(git rev-parse HEAD)"; main0="$(git rev-parse main)"
git checkout -q main; { cat "$SKILL/templates/rule-changes.md"; echo "$entry"; } > docs/rule-changes.md; git add docs; git commit -qm "main: log"
git checkout -q feat/7-mul; git rebase -q main
echo "- 2026-10-08 #8 — a later change." >> docs/rule-changes.md; git commit -qam "append to log"
review "$ok" "$ok" ""
aa pass "rule-change log appended, no gate file changed"
git checkout -q docs; git reset -q --hard HEAD~1
grep -v '^- 2026-10-07' docs/rule-changes.md > "$T/log" && cp "$T/log" docs/rule-changes.md; git commit -qam "drop a log line"
review "$ok" "$ok" ""
aa fail "rule-change log lost a line"
git checkout -q docs
git checkout -q main; git reset -q --hard "$main0"; git checkout -q feat/7-mul; git reset -q --hard "$feat"

# The coverage baseline may be raised without the owner; any other edit is a gate change.
feat="$(git rev-parse HEAD)"; main0="$(git rev-parse main)"
git checkout -q main; echo 80 > .standards/coverage-baseline; git add .standards; git commit -qm "baseline 80"
git checkout -q feat/7-mul; git rebase -q main
echo 85 > .standards/coverage-baseline; git commit -qam "raise baseline"
review "$ok" "$ok" ""
aa pass "coverage baseline raised 80 → 85"
git checkout -q docs; git reset -q --hard HEAD~1
echo 70 > .standards/coverage-baseline; git commit -qam "lower baseline"
review "$ok" "$ok" ""
aa fail "coverage baseline lowered 80 → 70"
git checkout -q docs; git reset -q --hard HEAD~1
printf '90\n# note\n' > .standards/coverage-baseline; git commit -qam "baseline plus text"
review "$ok" "$ok" ""
aa fail "coverage baseline with extra lines"
git checkout -q docs
git checkout -q main; git reset -q --hard "$main0"; git checkout -q feat/7-mul; git reset -q --hard "$feat"
# No baseline on the base counts as 0 (coverage-baseline.sh reads it so): creating the file
# with one number raises it, which the ratchet asks for, so it needs no gate-change review.
echo 85 > .standards/coverage-baseline; git add .standards; git commit -qm "first baseline"
review "$ok" "$ok" ""
aa pass "coverage baseline created (absent on base) with one number"
git checkout -q docs; git reset -q --hard HEAD~1
printf '90\n# note\n' > .standards/coverage-baseline; git add .standards; git commit -qm "first baseline plus text"
review "$ok" "$ok" ""
aa fail "coverage baseline created with extra lines"
git checkout -q docs; git reset -q --hard "$feat"

# APPROVER, read from the base's config.sh: "agent" lets the agent approve gate-file changes;
# owner-review flags still block. A branch cannot switch the mode that judges it.
echo "agents: keep it short" > CLAUDE.md; git add CLAUDE.md; git commit -qm "gate file"
sed 's/^APPROVER=.*/APPROVER="agent"/' .standards/config.sh > "$T/c" && cp "$T/c" .standards/config.sh; git commit -qam "branch sets APPROVER=agent"
review "$ok" "$ok" ""
aa fail "APPROVER=agent set only on the branch → still owner mode"
git checkout -q docs; git reset -q --hard "$feat"
feat="$(git rev-parse HEAD)"; main0="$(git rev-parse main)"
git checkout -q main; sed 's/^APPROVER=.*/APPROVER="agent"/' .standards/config.sh > "$T/c" && cp "$T/c" .standards/config.sh
git commit -qam "APPROVER=agent"; git checkout -q feat/7-mul; git rebase -q main
echo "agents: keep it short" > CLAUDE.md; git add CLAUDE.md; git commit -qm "gate file"
review "$ok" "$ok" ""
aa fail "APPROVER=agent (base), gate file without gate-change review → refused"
git checkout -q docs
echo "$entry" > docs/rule-changes.md; git add docs; git commit -qm "log line"
review "$ok" "$ok" ""; gcr "$ok" "$ok" ""
aa pass "APPROVER=agent (base) → gate-file change approved after gate-change review"
echo "owner-review: required — tone" >> "$dec"
aa fail "APPROVER=agent → owner-review flag still blocks"
git checkout -q docs
review "$ok" "$no" ""
aa fail "APPROVER=agent → reviewer FAIL still blocks"
git checkout -q docs
git checkout -q main; git reset -q --hard "$main0"; git checkout -q feat/7-mul; git reset -q --hard "$feat"

echo "approve"
# A fake gh logs every call and answers the queries bin/approve and bin/ship make; a call
# whose arguments contain $GH_FAIL fails. `script` gives approve the terminal it insists on.
mkdir -p "$T/fakebin"
cat > "$T/fakebin/gh" <<'EOF'
#!/bin/sh
echo "$*" >> "$GH_LOG"
if [ -n "${GH_FAIL:-}" ]; then case "$*" in *"$GH_FAIL"*) exit 1 ;; esac; fi
case "$*" in
  "pr view --json number"*) echo 12 ;;
  "pr view 12 --json headRefName"*) # the PR body is the file $GH_BODY, when set
    jq -cn --arg r "$GH_BRANCH" --arg o "$GH_HEAD" --rawfile b "${GH_BODY:-/dev/null}" '{headRefName:$r,headRefOid:$o,body:$b}' ;;
  "pr view 12 --json state"*) # after the merge: GH_STATE (default MERGED), merge commit GH_MERGE_OID (default origin/main)
    jq -cn --arg s "${GH_STATE:-MERGED}" --arg m "${GH_MERGE_OID:-$(git rev-parse origin/main)}" '{state:$s,mergeCommit:{oid:$m}}' ;;
  "repo view"*) echo o/r ;;
  "api "*) # GH_PAGES holds a JSON array of pages. Like real gh: --slurp prints them all as
           # one array; -q applies its filter to each page separately.
    case "$*" in
      *--slurp*) cat "$GH_PAGES" ;;
      *) f="$(printf '%s\n' "$@" | sed -n '/^-q$/{n;p;}')"
         jq -c '.[]' "$GH_PAGES" | while IFS= read -r p; do printf '%s\n' "$p" | jq -r "$f"; done ;;
    esac ;;
  *"--json labels"*) cat "$GH_LABELS" ;;
  "pr merge"*) [ -z "${GH_MERGE_SWITCH:-}" ] || git checkout -q main ;;  # --delete-branch leaves it
esac
exit 0
EOF
chmod +x "$T/fakebin/gh"
approve_run() { # approve_run <labels already on the PR> [VAR=value ...]: output in $T/approve.out
  printf '%s\n' "$1" > "$T/labels"; : > "$T/gh.log"; shift
  # Typed after a pause: input piped at once reaches the pty before approve's prompt reads it.
  { sleep 0.5; printf '%s\n' "${TYPED:-12}"; sleep 0.5; } | env "$@" GH_LOG="$T/gh.log" GH_LABELS="$T/labels" PATH="$T/fakebin:$PATH" \
    script -q /dev/null bash .standards/bin/approve 12 > "$T/approve.out" 2>&1
}
edits() { grep -E -- '--(add|remove)-label' "$T/gh.log" | tr '\n' ';'; }
approve_run approved
expect pass "approve: already approved → remove, then add (fresh event)" \
  test "$(edits)" = "pr edit 12 --remove-label approved;pr edit 12 --add-label approved;"
approve_run other
expect pass "approve: not yet approved → add only" test "$(edits)" = "pr edit 12 --add-label approved;"
approve_run approved GH_FAIL="--json labels"
expect pass "approve: label lookup fails → stops, no edits" \
  bash -c "[ -z \"\$(grep -E -- '--(add|remove)-label' '$T/gh.log')\" ] && grep -q 'could not read' '$T/approve.out'"
approve_run approved GH_FAIL="--add-label"
expect pass "approve: add fails after remove → says re-run" grep -q "label removed; re-run" "$T/approve.out"
expect pass "approve: prompt asks for the number" grep -q "Type the number 12 to approve pr #12" "$T/approve.out"
TYPED=approved approve_run other
expect pass "approve: wrong text typed → says what was expected, no edits" \
  bash -c "[ -z \"\$(grep -E -- '--(add|remove)-label' '$T/gh.log')\" ] && grep -q 'expected the number 12' '$T/approve.out'"

echo "coverage-baseline"
echo 85 > .standards/coverage-baseline
expect fail "coverage: total 80 below baseline 85" env COVERAGE_TOTAL_CMD="echo 80" bash -c '. .standards/config.sh; COVERAGE_TOTAL_CMD="echo 80"; sed -i.bak "s|^COVERAGE_TOTAL_CMD=.*|COVERAGE_TOTAL_CMD=\"echo 80\"|" .standards/config.sh; .standards/checks/coverage-baseline.sh; rc=$?; mv .standards/config.sh.bak .standards/config.sh; exit $rc'
expect pass "coverage: total 90 at/above baseline 85" bash -c 'sed -i.bak "s|^COVERAGE_TOTAL_CMD=.*|COVERAGE_TOTAL_CMD=\"echo 90\"|" .standards/config.sh; .standards/checks/coverage-baseline.sh; rc=$?; mv .standards/config.sh.bak .standards/config.sh; exit $rc'
# The suggested baseline is floor(total) − 1: a wobble under one point on the next run never fails.
expect pass "coverage: above baseline → prints the new baseline, floor − 1" grep -q "raise it: set .standards/coverage-baseline to 89 " "$T/last.log.prev"
# A total that is no number, or a command that fails, fails both modes, naming the output: junk
# never counts as 0 (with no baseline file, 0 ≥ 0 would pass).
covc() { # covc <name> <fixture> [--ratchet]: COVERAGE_TOTAL_CMD="sh <fixture>" must fail
  cp .standards/config.sh "$T/cfg.bak"
  sed "s|^COVERAGE_TOTAL_CMD=.*|COVERAGE_TOTAL_CMD=\"sh $SKILL/tests/coverage-fixtures/$2\"|" "$T/cfg.bak" > .standards/config.sh
  expect fail "coverage${3:+ $3}: $1" .standards/checks/coverage-baseline.sh ${3:-}
  cp "$T/cfg.bak" .standards/config.sh
}
mv .standards/coverage-baseline "$T/baseline.bak"
for flag in "" --ratchet; do
  covc "command prints no number (no baseline file)" junk.sh $flag
  expect pass "coverage${flag:+ $flag}: ... names the output" grep -q "COVERAGE_TOTAL_CMD printed 'Error: coverage tool crashed'" "$T/last.log.prev"
  covc "command exits non-zero" crash.sh $flag
  expect pass "coverage${flag:+ $flag}: ... names the exit code" grep -q "COVERAGE_TOTAL_CMD exited 3" "$T/last.log.prev"
  covc "last line is a status line, not the number" trailer.sh $flag
done
mv "$T/baseline.bak" .standards/coverage-baseline
# The ratchet (bin/ship runs --ratchet): a total more than COVERAGE_RATCHET_SLACK above the
# baseline fails until the baseline is raised, printing the exact edit.
cov() { # cov <pass|fail> <name> <total> [slack]: --ratchet with COVERAGE_TOTAL_CMD="echo <total>"
  cp .standards/config.sh "$T/cfg.bak"
  sed -e "s|^COVERAGE_TOTAL_CMD=.*|COVERAGE_TOTAL_CMD=\"echo $3\"|" -e "s|^COVERAGE_RATCHET_SLACK=.*|COVERAGE_RATCHET_SLACK=${4:-2}|" "$T/cfg.bak" > .standards/config.sh
  expect "$1" "coverage ratchet: $2" .standards/checks/coverage-baseline.sh --ratchet
  cp "$T/cfg.bak" .standards/config.sh
}
cov pass "total 86.5, baseline 85, slack 2" 86.5
cov fail "total 98.8, baseline 85, slack 2" 98.8
expect pass "coverage ratchet: prints the one-line edit" grep -q "set .standards/coverage-baseline to 97 " "$T/last.log.prev"
cov pass "total 98.8, baseline 85, slack 20" 98.8 20
# The suggestion must itself pass the ratchet: total − suggestion ≤ slack (slack 1: 98, not 97).
cov fail "total 98.8, baseline 85, slack 1" 98.8 1
expect pass "coverage ratchet: slack 1 → suggests 98" grep -q "set .standards/coverage-baseline to 98 " "$T/last.log.prev"
cov fail "below baseline still fails" 80
srm "${R:?}/.standards/coverage-baseline"
cov fail "no baseline file counts as 0" 50

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
# Grandfathered: a file already over the limit on the base blocks only when the branch grows it.
main0="$(git rev-parse main)"
git checkout -q main; for i in $(seq 1 30); do echo "x$i() { :; }"; done > src/legacy.sh
git add src && git commit -qm "main: legacy file over the limit"
git checkout -q -b feat/8-size
sed 's/^x5() .*/x5() { echo five; }/' src/legacy.sh > "$T/l" && cp "$T/l" src/legacy.sh; git commit -qam "edit, same length"
expect pass "file-size: over-limit file on base, edited, not grown" .standards/checks/file-size.sh
expect pass "file-size: says over limit but not grown" grep -q "over limit but not grown: src/legacy.sh (30 lines)" "$T/last.log.prev"
echo 'x31() { :; }' >> src/legacy.sh; git commit -qam "grow it"
expect fail "file-size: over-limit file on base, grown" .standards/checks/file-size.sh
expect pass "file-size: names the base length to get back to" grep -q "src/legacy.sh: 31 lines, was 30 on base" "$T/last.log.prev"
# A rename (git's rename detection) keeps the grandfathering: judged against the old path's length.
git reset -q --hard HEAD~2
git mv src/legacy.sh src/legacy2.sh; sed '$d' src/legacy2.sh > "$T/l" && cp "$T/l" src/legacy2.sh; git commit -qam "rename and shrink"
expect pass "file-size: grandfathered file renamed and shrunk" .standards/checks/file-size.sh
expect pass "file-size: ... names the old path" grep -q "over limit but not grown: src/legacy2.sh (29 lines; was 30 as src/legacy.sh)" "$T/last.log.prev"
printf 'y1() { :; }\ny2() { :; }\n' >> src/legacy2.sh; git commit -qam "grow the renamed file"
expect fail "file-size: grandfathered file renamed and grown" .standards/checks/file-size.sh
git checkout -q feat/7-mul; git branch -q -D feat/8-size; git branch -q -f main "$main0"
# Evidence images belong on the PR: a new one under docs/work/ over EVIDENCE_MAX_KB (300) fails.
head -c 409600 /dev/zero > docs/work/7-mul/after.PNG; git add docs; git commit -qm "big screenshot"
expect fail "file-size: new 400 KB image under docs/work/" .standards/checks/file-size.sh
expect pass "file-size: says attach it to the PR instead" grep -q "docs/work/7-mul/after.PNG: 400 KB.*attach it to the PR instead" "$T/last.log.prev"
git reset -q --hard HEAD~1
head -c 10240 /dev/zero > docs/work/7-mul/diagram.png; mkdir -p assets; head -c 409600 /dev/zero > assets/logo.png
git add docs assets; git commit -qm "small diagram, big product asset"
expect pass "file-size: 10 KB image under docs/work/, 400 KB asset elsewhere" .standards/checks/file-size.sh
expect pass "file-size: counts the images it checked" grep -q "1 new image(s) under docs/work/ checked" "$T/last.log.prev"
git reset -q --hard HEAD~1
# An image moved into docs/work/ (a rename) counts as new there.
main0="$(git rev-parse main)"
git checkout -q main; mkdir -p assets; head -c 409600 /dev/zero > assets/shot.png; git add assets; git commit -qm "main: big asset"
git checkout -q -b feat/8-img; mkdir -p docs/work/8-img; git mv assets/shot.png docs/work/8-img/shot.png; git commit -qm "move it into evidence"
expect fail "file-size: 400 KB image moved into docs/work/" .standards/checks/file-size.sh
git checkout -q feat/7-mul; git branch -q -D feat/8-img; git branch -q -f main "$main0"

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
srm "${R:?}/docs/product"

echo "stories"
# Optional: only with docs/user-stories/. Every "Covered by" file exists and holds each quoted
# test name; a line naming no file must say "manual only".
expect pass "stories: no docs/user-stories/ → N/A" .standards/checks/stories.sh
expect pass "stories: says N/A" grep -q "N/A: no docs/user-stories/" "$T/last.log.prev"
mkdir -p docs/user-stories tests/stories
cp "$SKILL/tests/stories-fixtures/area.test.sh" tests/stories/
for f in "$SKILL"/tests/stories-fixtures/*.md; do
  n="$(basename "$f" .md)"
  cp "$f" docs/user-stories/01-adding.md
  case "$n" in valid) want=pass ;; *) want=fail ;; esac
  expect "$want" "stories: $n" .standards/checks/stories.sh
  case "$n" in
    valid) expect pass "stories: valid → prints what it checked" grep -q "7 Covered by line(s), 5 file reference(s), 7 test name(s)" "$T/last.log.prev" ;;
    bare-missing) expect pass "stories: a bare TEST_GLOBS path that does not exist → named" grep -q "(US-AD-08): tests/stories/no-such.test.sh does not exist" "$T/last.log.prev" ;;
    missing-name) expect pass "stories: names the story, file and missing test" \
      grep -q "01-adding.md:6 (US-AD-09): tests/stories/area.test.sh has no \"subtracts two numbers\"" "$T/last.log.prev" ;;
    missing-file) expect pass "stories: names the missing file" grep -q "(US-AD-05): tests/stories/no-such.test.sh does not exist" "$T/last.log.prev" ;;
    no-test) expect pass "stories: a line with no file and no 'manual only'" grep -q "(US-AD-07): Covered by names no test file" "$T/last.log.prev" ;;
  esac
done
cp "$SKILL/templates/user-stories/README.md" docs/user-stories/README.md; srm "${R:?}/docs/user-stories/01-adding.md"
expect pass "stories: the installed README template passes" .standards/checks/stories.sh
srm "${R:?}/docs/user-stories" "${R:?}/tests/stories"

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

echo "ship"
# Its own repo with a real origin, since bin/ship fetches and compares against it.
git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$T/ship" 2>/dev/null; cd "$T/ship" || exit 1
git config user.email t@example.invalid; git config user.name test
mkdir -p .standards bin src docs/work/1-x
cp -R "$SKILL/scripts/." .standards/; cp "$SKILL/scripts/bin/ship" bin/ship
sed -e 's/^OWNER=""/OWNER="owner"/' -e 's/^APPROVER=.*/APPROVER="owner"/' "$SKILL/scripts/config.sh" > .standards/config.sh
chmod +x bin/ship .standards/checks/* .standards/bin/*
echo base > src/a.txt
git add -A && git commit -qm base && git push -q origin main
git checkout -q -b feat/1-x
echo change > src/a.txt; git commit -qam change
dec=docs/work/1-x/decisions.md
sed 's/Verdict: PENDING/Verdict: PASS/' "$SKILL/templates/decisions.md" > "$dec"
review "$ok" "$ok" "" "$(git rev-parse HEAD)"
git add docs && git commit -qm "decision log"
ship_run() { # ship_run [VAR=value ...]: bin/ship 12 against the fake gh; output in $T/ship.out
  : > "$T/gh.log"
  env GH_LABELS="$T/nolabels" GH_PAGES="$T/nopages" "$@" GH_LOG="$T/gh.log" GH_BRANCH=feat/1-x GH_HEAD="$(git rev-parse HEAD)" \
    PATH="$T/fakebin:$PATH" bash bin/ship 12 > "$T/ship.out" 2>&1
}
writes() { grep -E '^pr (merge|comment)' "$T/gh.log" | awk '{ print $2 }' | tr '\n' ';'; }
: > "$T/nolabels"; echo approved > "$T/approved"
# Issue-event pages as the API returns them (real pages hold 30 events; 2 pages suffice).
lab() { printf '{"event":"labeled","label":{"name":"approved"},"actor":{"login":"%s"},"created_at":"%s"}' "$1" "$2"; }
echo '[[]]' > "$T/nopages"
echo "[[$(lab owner 2999-01-01T00:00:00Z)]]" > "$T/fresh"
echo "[[$(lab owner 2000-01-01T00:00:00Z)]]" > "$T/stale"
echo "[[$(lab owner 2999-01-01T00:00:00Z)],[{\"event\":\"commented\"}]]" > "$T/label-then-page"
echo "[[$(lab someone 2998-01-01T00:00:00Z)],[$(lab owner 2999-01-01T00:00:00Z)]]" > "$T/two-actors"
fresh="$T/fresh"

ship_run
expect pass "ship: agent path → merge, then comment" test "$(writes)" = "merge;comment;"
expect pass "ship: merge pinned with --match-head-commit HEAD" grep -q -- "--match-head-commit $(git rev-parse HEAD)" "$T/gh.log"
expect pass "ship: no gate change → comment says so, no rules-changed label" \
  bash -c "grep -q 'No gate file changed' '$T/gh.log' && ! grep -q 'rules-changed' '$T/gh.log'"
ship_run GH_FAIL="pr merge"
expect pass "ship: merge fails → no comment" test "$(writes)" = "merge;"
expect pass "ship: no gate change, comment fails after merge → warns, run succeeds" ship_run GH_FAIL="pr comment"
expect pass "ship: MERGE_MODE default → --squash" grep -q -- "^pr merge 12 --squash " "$T/gh.log"
# MERGE_MODE and the coverage ratchet, set on the base like any config.
feat="$(git rev-parse HEAD)"; main0="$(git rev-parse main)"
git checkout -q main
sed -e 's/^MERGE_MODE=.*/MERGE_MODE="merge"/' -e 's/^COVERAGE_TOTAL_CMD=.*/COVERAGE_TOTAL_CMD="echo $FAKE_COV"/' .standards/config.sh > "$T/c" && cp "$T/c" .standards/config.sh
echo 80 > .standards/coverage-baseline; git add .standards; git commit -qm "main: merge commits, coverage" && git push -q origin main
git checkout -q feat/1-x; git rebase -q main
ship_run FAKE_COV=81.5
expect pass "ship: MERGE_MODE=merge → gh pr merge --merge" bash -c "test '$(writes)' = 'merge;comment;' && grep -q -- '^pr merge 12 --merge ' '$T/gh.log'"
ship_run FAKE_COV=98.8
expect pass "ship: coverage 98.8 vs baseline 80 → nothing written" test "$(writes)" = ""
expect pass "ship: coverage ratchet prints the edit" grep -q "set .standards/coverage-baseline to 97 " "$T/ship.out"
echo 97 > .standards/coverage-baseline; git commit -qam "raise baseline"
review "$ok" "$ok" "" "$(git rev-parse HEAD)"; git commit -qam "re-review"
ship_run FAKE_COV=98.8
expect pass "ship: baseline raised → agent approves and merges" test "$(writes)" = "merge;comment;"
sed 's/^MERGE_MODE=.*/MERGE_MODE="fast"/' .standards/config.sh > "$T/c" && cp "$T/c" .standards/config.sh; git commit -qam "bad mode"
ship_run FAKE_COV=98.8
expect pass "ship: unknown MERGE_MODE → nothing written, says which values" \
  bash -c "test -z '$(writes)' && grep -q 'MERGE_MODE=\"fast\" — use squash, merge or rebase' '$T/ship.out'"
git checkout -q main; git reset -q --hard "$main0"; git push -q -f origin main 2>/dev/null
git checkout -q feat/1-x; git reset -q --hard "$feat"
echo "owner-review: required — taste" >> "$dec"; git commit -qam "flag"
ship_run
expect pass "ship: agent refused, no owner label → nothing written" test "$(writes)" = ""
ship_run GH_LABELS="$T/approved" GH_PAGES="$fresh"
expect pass "ship: owner label checked first → merge, no comment" test "$(writes)" = "merge;"
ship_run GH_LABELS="$T/approved" GH_PAGES="$T/stale"
expect pass "ship: owner label older than head → nothing written" test "$(writes)" = ""
ship_run GH_LABELS="$T/approved" GH_PAGES="$T/label-then-page"
expect pass "ship: label event on page 1 of 2 still found" test "$(writes)" = "merge;"
ship_run GH_LABELS="$T/approved" GH_PAGES="$T/two-actors"
expect pass "ship: latest label event across pages credited (OWNER)" test "$(writes)" = "merge;"
git reset -q --hard HEAD~1
sed 's/^Verdict: PASS$/Verdict: PENDING/' "$dec" > "$T/dec" && cp "$T/dec" "$dec"; git commit -qam "gates pending"
ship_run GH_LABELS="$T/approved" GH_PAGES="$fresh"
expect pass "ship: another gate failed → nothing written, even with owner label" test "$(writes)" = ""
git reset -q --hard HEAD~1

# Re-exec of the base copy, temp cleanup, and a spoofed env var never deleting bin/ship.
mkdir -p "$T/fakemktemp" "$T/tmpfiles"
cat > "$T/fakemktemp/mktemp" <<'EOF'
#!/bin/sh
exec /usr/bin/mktemp "$PROBE_TMP/$(basename "${1:-tmp.XXXXXX}")"
EOF
chmod +x "$T/fakemktemp/mktemp"
# The branch's copy says something else once past the re-exec point; the base copy must win.
sed 's/PASS branch current and pushed/BRANCH-COPY-CONTINUED/' bin/ship > "$T/s" && cp "$T/s" bin/ship; git commit -qam "edit bin/ship"
PATH="$T/fakemktemp:$PATH" ship_run PROBE_TMP="$T/tmpfiles"
expect pass "ship: branch edits bin/ship → base copy runs" \
  bash -c "grep -q 'PASS branch current and pushed' '$T/ship.out' && ! grep -q BRANCH-COPY-CONTINUED '$T/ship.out'"
expect pass "ship: no temp files left" test -z "$(ls -A "$T/tmpfiles")"
git reset -q --hard HEAD~1
ship_run STANDARDS_SHIP_FROM_BASE=bin/ship
ship_run STANDARDS_SHIP_FROM_BASE="$PWD/bin/ship"
expect pass "ship: spoofed STANDARDS_SHIP_FROM_BASE never deletes bin/ship" test -f bin/ship

# UI evidence: with UI_GLOBS set (on the base), a PR touching a UI file needs an image in its
# body, or "Screenshots: N/A — <reason>". Screenshots live on the PR, never in git.
feat="$(git rev-parse HEAD)"; main0="$(git rev-parse main)"
git checkout -q main; sed 's|^UI_GLOBS=.*|UI_GLOBS="src/*"|' .standards/config.sh > "$T/c" && cp "$T/c" .standards/config.sh
git commit -qam "main: UI_GLOBS" && git push -q origin main; git checkout -q feat/1-x; git rebase -q main
body() { printf '%s\n' "Closes #1" "" "$@" > "$T/body"; }   # body <line>...: the PR body for ship_run
body "## Evidence" "| AC1 | e2e | ok | ok | test | PASS |"
ship_run GH_BODY="$T/body"
expect pass "ship: UI file changed, no image in the PR body → nothing written" test "$(writes)" = ""
expect pass "ship: ... names the UI file and the --attach fix" \
  bash -c "grep -q 'UI files changed (src/a.txt)' '$T/ship.out' && grep -q 'gh pr edit 12 .*--attach' '$T/ship.out'"
expect pass "ship: ... EVIDENCE_CMD empty → says to set it, the rulebook's stage 8" \
  grep -q 'EVIDENCE_CMD is empty in .standards/config.sh: set it to the repo.s one capture script' "$T/ship.out"
git checkout -q main; sed 's|^EVIDENCE_CMD=.*|EVIDENCE_CMD="scripts/evidence-capture.sh"|' .standards/config.sh > "$T/c" && cp "$T/c" .standards/config.sh
git commit -qam "main: EVIDENCE_CMD" && git push -q origin main; git checkout -q feat/1-x; git rebase -q main
ship_run GH_BODY="$T/body"
expect pass "ship: ... EVIDENCE_CMD set → names the command to run" \
  bash -c "test -z '$(writes)' && grep -q 'capture the set with: scripts/evidence-capture.sh' '$T/ship.out'"
body "![after, 375 px](https://github.com/user-attachments/assets/0f0f)"
ship_run GH_BODY="$T/body"
expect pass "ship: markdown image in the PR body → merge" test "$(writes)" = "merge;comment;"
body '<img width="375" alt="after" src="https://github.com/user-attachments/assets/0f0f">'
ship_run GH_BODY="$T/body"
expect pass "ship: <img> in the PR body → merge" test "$(writes)" = "merge;comment;"
body "<!-- template hint:" "![after](https://github.com/user-attachments/assets/0f0f)" "-->"
ship_run GH_BODY="$T/body"
expect pass "ship: image only inside an HTML comment → nothing written" test "$(writes)" = ""
body "Screenshots: N/A — <reason>"
ship_run GH_BODY="$T/body"
expect pass "ship: 'Screenshots: N/A' with a placeholder → nothing written" test "$(writes)" = ""
body "Screenshots: N/A — a renamed constant; no pixel moves"
ship_run GH_BODY="$T/body"
expect pass "ship: 'Screenshots: N/A — reason' → merge" test "$(writes)" = "merge;comment;"
git checkout -q main; git reset -q --hard "$main0"; git push -q -f origin main 2>/dev/null
git checkout -q feat/1-x; git reset -q --hard "$feat"
ship_run
expect pass "ship: UI_GLOBS empty → no image needed" test "$(writes)" = "merge;comment;"

# The evidence capture template (templates/evidence-capture.example.sh): a syntax check and its dry
# run only — a real run needs a browser and a running app. The dry run must call no browser (a fake
# agent-browser first on PATH records any call) and list one file per page × viewport × theme.
echo "evidence template"
ev="$SKILL/templates/evidence-capture.example.sh"
mkdir -p "$T/fakeab"; cp "$SKILL/tests/ship-fixtures/fake-agent-browser.sh" "$T/fakeab/agent-browser"; chmod +x "$T/fakeab/agent-browser"
evd() { : > "$T/ab.log"; env AB_LOG="$T/ab.log" PATH="$T/fakeab:$PATH" TMPDIR="$T" "$@" /bin/bash "$ev" --dry-run > "$T/ev.out" 2> "$T/ev.err"; }
expect pass "evidence: the template parses (bash -n)" /bin/bash -n "$ev"
evd EVIDENCE_PAGES="/ /settings/team" EVIDENCE_VIEWPORTS="390x844 844x390" EVIDENCE_THEMES="light dark"
expect pass "evidence: dry run → 2 pages × 2 viewports × 2 themes = 8 files listed, nothing else on stdout" \
  test "$(grep -c '\.png$' "$T/ev.out")" = 8 -a "$(wc -l < "$T/ev.out" | tr -d ' ')" = 8
expect pass "evidence: ... named page-WxH-theme, '/' as home" \
  bash -c "grep -qx '$T/evidence.DRY-RUN/home-390x844-light.png' '$T/ev.out' && grep -qx '$T/evidence.DRY-RUN/settings-team-844x390-dark.png' '$T/ev.out'"
expect pass "evidence: ... no browser call, no dir written" bash -c "test ! -s '$T/ab.log' && test ! -e '$T/evidence.DRY-RUN'"
evd
expect pass "evidence: defaults → home at 390x844, 360x740, 844x390 in light and dark (6 files)" test "$(grep -c '\.png$' "$T/ev.out")" = 6
evd EVIDENCE_VIEWPORTS="390by844"; evc=$?
expect pass "evidence: a viewport that is not WxH → exit 2 before any capture, says so" \
  bash -c "test $evc = 2 && test ! -s '$T/ev.out' && grep -q \"viewport '390by844' is not WxH\" '$T/ev.err' && test ! -s '$T/ab.log'"

# Deploy: with DEPLOY_CMD set (on the base), bin/ship deploys after the merge from a fresh
# detached checkout of origin/main in a temp dir, runs LIVE_CHECK_CMD there, then removes it.
# The deploy script is committed on main and named through $ROOT, which bin/ship points at the
# fresh checkout: an unmerged edit of the script or of config.sh must never run.
git checkout -q main; cp "$SKILL/tests/ship-fixtures/deploy-probe.sh" deploy-probe.sh
sed -e "s|^DEPLOY_CMD=.*|DEPLOY_CMD='bash \$ROOT/deploy-probe.sh deploy'|" -e "s|^LIVE_CHECK_CMD=.*|LIVE_CHECK_CMD='bash \$ROOT/deploy-probe.sh live'|" .standards/config.sh > "$T/c" && cp "$T/c" .standards/config.sh
git add deploy-probe.sh .standards; git commit -qm "main: deploy" && git push -q origin main; git checkout -q feat/1-x; git rebase -q main
dep() { : > "$T/probe.log"; ship_run PROBE_LOG="$T/probe.log" "$@"; }   # dep [VAR=value ...]
probe_dir() { awk -v s="$1" '$1 == s { print $2 }' "$T/probe.log"; }   # probe_dir <step>: where it ran
dep
expect pass "ship: DEPLOY_CMD set → merge, comment, then deploy and live check" \
  bash -c "test '$(writes)' = 'merge;comment;' && test \"\$(awk '{ print \$1 }' '$T/probe.log' | tr '\n' ' ')\" = 'deploy live '"
expect pass "ship: deploy ran at origin/main, outside the working copy" \
  bash -c "test \"\$(awk '{ print \$3 }' '$T/probe.log' | sort -u)\" = '$(git rev-parse origin/main)' && test '$(probe_dir deploy)' != '$(pwd -P)'"
expect pass "ship: deploy checkout removed (dirty with build output)" \
  bash -c "test -n '$(probe_dir deploy)' && test ! -e '$(probe_dir deploy)' && test \"\$(git worktree list | wc -l | tr -d ' ')\" = 1"
expect fail "ship: live check fails after the merge → run fails" dep PROBE_LIVE_RC=1
expect pass "ship: ... says it is merged and deployed, and how to re-check" \
  bash -c "grep -q 'FAIL live-check: #12 is merged and deployed' '$T/ship.out' && grep -q 'bin/ship --deploy' '$T/ship.out'"
expect pass "ship: ... checkout removed after a failed live check" bash -c "test -n '$(probe_dir live)' && test ! -e '$(probe_dir live)'"
expect fail "ship: deploy fails → run fails" dep PROBE_DEPLOY_RC=1
expect pass "ship: ... no live check after a failed deploy, says production runs the old build" \
  bash -c "test \"\$(awk '{ print \$1 }' '$T/probe.log')\" = deploy && grep -q 'production still runs the previous build' '$T/ship.out'"
: > "$T/probe.log"; : > "$T/gh.log"
expect pass "ship --deploy: deploys origin/main only, no merge" \
  env PROBE_LOG="$T/probe.log" GH_LOG="$T/gh.log" PATH="$T/fakebin:$PATH" bash bin/ship --deploy
expect pass "ship --deploy: ... ran deploy and live, wrote nothing to GitHub" \
  bash -c "test \"\$(awk '{ print \$1 }' '$T/probe.log' | tr '\n' ' ')\" = 'deploy live ' && test -z \"\$(grep -E '^pr (merge|comment)' '$T/gh.log')\""
# Uncommitted edits to config.sh and to the deploy script in the working copy: the base's run.
sed "s|^DEPLOY_CMD=.*|DEPLOY_CMD='bash \$ROOT/deploy-probe.sh rogue'|" .standards/config.sh > "$T/c" && cp "$T/c" .standards/config.sh
cp "$SKILL/tests/ship-fixtures/deploy-probe-branch.sh" deploy-probe.sh
: > "$T/probe.log"
env PROBE_LOG="$T/probe.log" GH_LOG="$T/gh.log" PATH="$T/fakebin:$PATH" bash bin/ship --deploy > "$T/ship.out" 2>&1
expect pass "ship --deploy: unmerged config.sh and script edits never run (base's DEPLOY_CMD, base's script)" \
  test "$(awk '{ print $1 }' "$T/probe.log" | tr '\n' ' ')" = "deploy live "
git checkout -q -- .standards/config.sh deploy-probe.sh
# Merged? A merge queue or auto-merge leaves the PR open: no deploy, and say how to deploy later.
dep GH_STATE=OPEN
expect pass "ship: PR still OPEN after the merge call → no deploy, says so" \
  bash -c "test '$(writes)' = 'merge;comment;' && test ! -s '$T/probe.log' && grep -q 'SKIP deploy: #12 is not merged into origin/main yet (state OPEN)' '$T/ship.out'"
dep GH_MERGE_OID="$(git rev-parse HEAD)"
expect pass "ship: merge commit not on origin/main → no deploy" \
  bash -c "test ! -s '$T/probe.log' && grep -q 'SKIP deploy: #12 is not merged into origin/main yet' '$T/ship.out'"
# A deploy needs a live check: DEPLOY_CMD without LIVE_CHECK_CMD fails at ship start, nothing written.
git checkout -q main; sed 's|^LIVE_CHECK_CMD=.*|LIVE_CHECK_CMD=""|' .standards/config.sh > "$T/c" && cp "$T/c" .standards/config.sh
git commit -qam "main: no live check" && git push -q origin main; git checkout -q feat/1-x; git rebase -q main
dep
expect pass "ship: DEPLOY_CMD without LIVE_CHECK_CMD → nothing written, says so" \
  bash -c "test -z '$(writes)' && test ! -s '$T/probe.log' && grep -q 'DEPLOY_CMD is set but LIVE_CHECK_CMD is empty' '$T/ship.out'"
git checkout -q main; git reset -q --hard "$main0"; git push -q -f origin main 2>/dev/null
git checkout -q feat/1-x; git reset -q --hard "$feat"

# APPROVER modes: a blast-radius spec (no spec-approved label) plus a gate-file change.
echo "owner-approval: required" > docs/work/1-x/spec.md; echo "agents: keep it short" > CLAUDE.md
git add docs CLAUDE.md && git commit -qm "blast-radius spec, gate file"
review "$ok" "$ok" "" "$(git rev-parse HEAD)"; git commit -qam "re-review"
ship_run
expect pass "ship: APPROVER=owner → blast-radius spec + gate file refused" test "$(writes)" = ""
git checkout -q main; sed 's/^APPROVER=.*/APPROVER="agent"/' .standards/config.sh > "$T/c" && cp "$T/c" .standards/config.sh
git commit -qam "APPROVER=agent" && git push -q origin main; git checkout -q feat/1-x; git rebase -q main
ship_run
expect pass "ship: APPROVER=agent, gate file without gate-change review → refused" test "$(writes)" = ""
# The gate-change review and a log line: merge, label, record.
echo "- 2026-10-07 #1 — Agents now keep CLAUDE.md short." > docs/rule-changes.md; git add docs; git commit -qm "log line"
gcr "$ok" "$ok" "" "$(git rev-parse HEAD)"; review "$ok" "$ok" "" "$(git rev-parse HEAD)"; git commit -qam "gate-change review"
ship_run
expect pass "ship: APPROVER=agent → agent approves, merges, comments" test "$(writes)" = "merge;comment;"
expect pass "ship: comment states the mode and lists the changed gate file" \
  bash -c "grep -q 'Mode: APPROVER=agent' '$T/gh.log' && grep -q 'Gate files changed.*CLAUDE.md' '$T/gh.log'"
expect pass "ship: gate change → PR labelled rules-changed" grep -q -- "pr edit 12 --add-label rules-changed" "$T/gh.log"
expect pass "ship: gate change → comment carries the log line, no @-mention" \
  bash -c "grep -q 'Agents now keep CLAUDE.md short.' '$T/gh.log' && ! grep -q '@owner' '$T/gh.log'"
ship_run GH_MERGE_SWITCH=1
expect pass "ship: merge leaves the branch → log line still in the comment" grep -q 'Agents now keep CLAUDE.md short.' "$T/gh.log"
git checkout -q feat/1-x
expect fail "ship: gate change, comment fails after merge → run fails" ship_run GH_FAIL="pr comment"
expect fail "ship: gate change, label fails after merge → run fails" ship_run GH_FAIL="rules-changed"
echo "owner-review: required — tone" >> "$dec"; git commit -qam "flag"
ship_run
expect pass "ship: APPROVER=agent → owner-review flag still blocks" test "$(writes)" = ""
# The owner approves the same gate change: still labelled and recorded, whoever approved.
ship_run GH_LABELS="$T/approved" GH_PAGES="$fresh"
expect pass "ship: owner-approved gate change → merge, then comment" test "$(writes)" = "merge;comment;"
expect pass "ship: owner-approved gate change → PR labelled rules-changed" grep -q -- "pr edit 12 --add-label rules-changed" "$T/gh.log"
expect pass "ship: owner-approved gate change → comment lists the gate file" grep -q 'Gate files changed.*CLAUDE.md' "$T/gh.log"
expect fail "ship: owner-approved gate change, label fails → run fails" ship_run GH_LABELS="$T/approved" GH_PAGES="$fresh" GH_FAIL="rules-changed"
expect fail "ship: owner-approved gate change, comment fails → run fails" ship_run GH_LABELS="$T/approved" GH_PAGES="$fresh" GH_FAIL="pr comment"
# No gate-file list, no merge: a check that cannot list the branch's changes (stub, on the base
# and so on the rebased branch too) stops an owner-approved ship before the merge.
feat="$(git rev-parse HEAD)"; main0="$(git rev-parse main)"
git checkout -q main; cp "$SKILL/tests/ship-fixtures/agent-approval-cannot-list.sh" .standards/checks/agent-approval.sh
chmod +x .standards/checks/agent-approval.sh; git commit -qam "stub agent-approval" && git push -q origin main
git checkout -q feat/1-x; git rebase -q main
ship_run GH_LABELS="$T/approved" GH_PAGES="$fresh"
expect pass "ship: gate files cannot be listed → nothing written (no merge)" test "$(writes)" = ""
expect pass "ship: gate files cannot be listed → says so" grep -q "could not list the gate files" "$T/ship.out"
git checkout -q main; git reset -q --hard "$main0"; git push -q -f origin main 2>/dev/null
git checkout -q feat/1-x; git reset -q --hard "$feat"

# --- change class: which checks a branch needs ---
echo "change class"
C="$T/cls"; mkdir -p "$C"; cd "$C" || exit 1
git init -q -b main
git config user.email t@example.invalid; git config user.name test
mkdir -p .standards src tests site/src site/tests docs
cp -R "$SKILL/scripts/." .standards/
cat >> .standards/config.sh <<'EOF'
SRC_GLOBS="src/* site/src/*"
TEST_GLOBS="tests/* site/tests/*"
TEST_FILES_CMD="./run-tests.sh"
SITE_TEST_FILES_CMD="./run-tests.sh"
COVERAGE_TOTAL_CMD="echo 1"
SHARED_GLOBS="docs/shared.md"
APP_GLOBS=".standards/*"
SITE_GLOBS="site/*"
DOCS_GLOBS="docs/* *.md"
CROSS_READS_APP_FILES="tests/*.test.sh"
CROSS_READS_SITE_FILES="site/tests/*.test.sh"
EOF
cat > run-tests.sh <<'EOF'
#!/bin/sh
rc=0; for f in "$@"; do sh "$f" || { echo "test failed: $f"; rc=1; }; done; exit $rc
EOF
chmod +x run-tests.sh .standards/checks/* .standards/hooks/*
echo 'a() { echo 1; }' > src/a.sh
echo 'o() { :; }' > src/old.sh
echo 'v() { echo 1; }' > site/src/lib.sh
echo 'x' > site/data.txt
echo 'shared' > docs/shared.md
echo 'notes' > docs/notes.md
echo 5 > .standards/coverage-baseline
echo 'true' > site/tests/keep.test.sh
echo '. src/a.sh; [ "$(a)" = 1 ]' > tests/a.test.sh
git add -A . && git commit -qm base
cls() { bash -c '. .standards/lib/common.sh; change_class'; }
branch() { git checkout -q main; git checkout -q -B "$1"; }
class_is() { # class_is <want> <name>
  expect pass "class $2 -> $1" test "$(cls)" = "$1"
}

branch feat/9-docs; echo more >> docs/notes.md; git commit -qam docs
class_is docs "docs only"
expect fail "coverage-baseline runs when the app is touched (self-proof)" bash -c "git checkout -q -B feat/9-probe main && echo y >> src/a.sh && git commit -qam probe && .standards/checks/coverage-baseline.sh"
branch feat/9-docs2; echo more >> docs/notes.md; git commit -qam docs
expect pass "coverage-baseline skipped on a docs branch" bash -c ".standards/checks/coverage-baseline.sh | grep -q 'SKIP coverage-baseline'"
# The ratchet too: drift from earlier merges (total 90 vs baseline 5) must not block a docs PR.
expect pass "coverage ratchet skipped on a docs branch, says so" \
  bash -c "echo 'COVERAGE_TOTAL_CMD=\"echo 90\"' >> .standards/config.sh; out=\$(.standards/checks/coverage-baseline.sh --ratchet); rc=\$?; git checkout -q .standards/config.sh; [ \$rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'SKIP coverage-baseline (change class docs'"
expect fail "coverage ratchet: same drift on an app branch fails (self-proof)" \
  bash -c "git checkout -q -B feat/9-probe2 main && echo y >> src/a.sh && git commit -qam probe && echo 'COVERAGE_TOTAL_CMD=\"echo 90\"' >> .standards/config.sh; .standards/checks/coverage-baseline.sh --ratchet; rc=\$?; git checkout -q .standards/config.sh; exit \$rc"
branch feat/9-site; echo 2 > site/data.txt; echo more >> docs/notes.md; git commit -qam site
class_is site "site files and docs"
branch feat/9-app; echo y >> src/a.sh; git commit -qam app
class_is app "app file"
branch feat/9-del; git rm -q src/old.sh; git commit -qm "delete an app file"
class_is app "deleted app file (not invisible)"
branch feat/9-both; echo y >> src/a.sh; echo 2 > site/data.txt; git commit -qam both
class_is all "app and site"
branch feat/9-shared; echo more >> docs/shared.md; git commit -qam shared
class_is all "shared file"
branch feat/9-gate; echo "# x" >> .standards/lib/common.sh; git commit -qam "gate file"
class_is app ".standards/ is app even though it is not source"
branch feat/9-none; git commit -q --allow-empty -m none
class_is all "no file changed"
expect pass "classes off (no SITE/DOCS globs) -> all" bash -c "git checkout -q feat/9-docs && . .standards/lib/common.sh && SITE_GLOBS='' DOCS_GLOBS='' && [ \"\$(change_class)\" = all ]"
expect pass "checks_for: site branch skips app, runs site" bash -c ". .standards/lib/common.sh; ! checks_for app site && checks_for site site && ! checks_for site-change docs && checks_for site-change all && checks_for nonsense docs"

echo "tdd per test kind"
tdd() { expect "$1" "tdd: $2" .standards/checks/tdd.sh; }
branch feat/9-t1
echo 'v() { echo 2; }' > site/src/lib.sh; echo '. site/src/lib.sh; [ "$(v)" = 2 ]' > site/tests/v.test.sh
git add -A . && git commit -qm "site change with a site test"
tdd pass "site source + red/green site test"
branch feat/9-t2
echo 'a() { echo 3; }' > src/a.sh; echo 'true' > site/tests/other.test.sh
git add -A . && git commit -qm "app change, only a site test"
tdd fail "app source with only a site test"
branch feat/9-t3
echo 'a() { echo 3; }' > src/a.sh; echo '. src/a.sh; [ "$(a)" = 3 ]' > tests/a.test.sh
echo 'v() { echo 2; }' > site/src/lib.sh; echo '. site/src/lib.sh; [ "$(v)" = 2 ]' > site/tests/v.test.sh
git add -A . && git commit -qm "both with proper tests"
tdd pass "app and site, each test red on base and green on HEAD"
branch feat/9-t4
echo 'a() { echo 3; }' > src/a.sh; echo 'true' > tests/a.test.sh
echo 'v() { echo 2; }' > site/src/lib.sh; echo '. site/src/lib.sh; [ "$(v)" = 2 ]' > site/tests/v.test.sh
git add -A . && git commit -qm "app test is green on base, site test is red"
tdd fail "app test green on base is not hidden by a red site test"
# No source change passes only when SRC_GLOBS can match source at all (config edits stay
# uncommitted: the check sources the working copy, the diff reads commits).
git checkout -q feat/9-docs
tdd pass "no source change, SRC_GLOBS matches tracked source"
echo 'SRC_GLOBS="web/* server/*"' >> .standards/config.sh
tdd fail "no source change, SRC_GLOBS matches no tracked file"
expect pass "tdd: zero-match failure names SRC_GLOBS" grep -q "SRC_GLOBS matches no tracked file" "$T/last.log.prev"
git checkout -q .standards/config.sh
echo 'SRC_GLOBS="src/*"' >> .standards/config.sh
tdd fail "site tests tracked, SRC_GLOBS covers no site source"
git checkout -q .standards/config.sh
echo 'SRC_GLOBS=""' >> .standards/config.sh
tdd pass "SRC_GLOBS explicitly empty → N/A"
expect pass "tdd: empty SRC_GLOBS prints an N/A line" grep -q "N/A: SRC_GLOBS empty" "$T/last.log.prev"
git checkout -q .standards/config.sh
# Each changed test file must be red on its own: a red file in the same run must not hide one
# that already passes on the base (same kind, unlike feat/9-t4).
branch feat/9-t5
echo 'a() { echo 3; }' > src/a.sh; echo '. src/a.sh; [ "$(a)" = 3 ]' > tests/a.test.sh; echo 'true' > tests/b.test.sh
git add -A . && git commit -qm "two app tests, one green on base"
tdd fail "app test green on base is not hidden by a red app test"
expect pass "tdd: names the test that passes on base" grep -q "tests/b.test.sh passes on the base code" "$T/last.log.prev"
git rm -q tests/b.test.sh; git commit -qm "drop the green test"
tdd pass "each changed test red on its own"
expect pass "tdd: prints each file's red time" grep -q "tests/a.test.sh red on base ([0-9][0-9]*s)" "$T/last.log.prev"
# Compile-red: the base fails only because the test names what does not exist there yet. With
# TDD_COMPILE_FAIL_RE matching that output, it is labelled and needs a decisions.md line.
branch feat/9-t6; mkdir -p docs/work/9-t6
echo 'a() { echo 1; }; a3() { echo 3; }' > src/a.sh; echo '. src/a.sh; [ "$(a3)" = 3 ]' > tests/a3.test.sh
echo "# Decisions — #9" > docs/work/9-t6/decisions.md
git add -A . && git commit -qm "new function, test names it"
tdd pass "missing function on base, TDD_COMPILE_FAIL_RE unset → red"
echo 'TDD_COMPILE_FAIL_RE="command not found|not found"' >> .standards/config.sh
tdd fail "compile-only red without a TDD: compile-red line"
cp "$T/last.log" "$T/compile.log"
expect pass "tdd: labels it compile only" grep -q "tests/a3.test.sh red (compile only — assertion not proven)" "$T/compile.log"
expect pass "tdd: prints the exact compile-red line to add" grep -q "TDD: compile-red — tests/a3.test.sh — <reason>" "$T/compile.log"
echo "TDD: compile-red — tests/a3.test.sh — <reason>" >> docs/work/9-t6/decisions.md
tdd fail "compile-red line with a placeholder reason"
echo "TDD: compile-red — a3 is new; the test asserts its value once it exists" >> docs/work/9-t6/decisions.md
tdd fail "compile-red line naming no file covers nothing"
echo "TDD: compile-red — tests/other.test.sh — a3 is new" >> docs/work/9-t6/decisions.md
tdd fail "compile-red line naming another file"
echo "TDD: compile-red — tests/x.test.sh, tests/a3.test.sh — a3 is new; the test asserts its value once it exists" >> docs/work/9-t6/decisions.md
tdd pass "compile-only red, its file in a compile-red comma list"
git checkout -q .standards/config.sh docs
# A refactored test file that still passes on base: blocked until decisions.md names it in
# "TDD: refactor — <file> — <reason>"; the fail message prints that line. Another changed test
# must still be red: a refactor alone proves nothing about the source change.
branch feat/9-t7; mkdir -p docs/work/9-t7; echo "# Decisions — #9" > docs/work/9-t7/decisions.md
echo 'a() { echo 1; }; b() { echo 2; }' > src/a.sh; echo '. src/a.sh; [ "$(b)" = 2 ]' > tests/b.test.sh
echo '. src/a.sh; test "$(a)" = 1' > tests/a.test.sh
git add -A . && git commit -qm "new b with a red test, a.test.sh refactored"
tdd fail "refactored test green on base, no TDD: refactor line"
expect pass "tdd: prints the exact refactor line to add" grep -q "TDD: refactor — tests/a.test.sh — <reason>" "$T/last.log.prev"
echo "TDD: refactor — tests/a.test.sh — <reason>" >> docs/work/9-t7/decisions.md
tdd fail "refactor line with a placeholder reason"
echo "TDD: refactor — tests/a.test.sh — same assertion, test instead of [ ]" >> docs/work/9-t7/decisions.md
tdd pass "refactored test named in a TDD: refactor line, another test red"
git rm -q tests/b.test.sh; git commit -qm "only the refactor left"
tdd fail "source change whose only test change is a declared refactor"
git checkout -q docs

echo "docs-only lane"
# A branch touching only docs needs no spec or plan gate; the pre-merge gate still applies.
dl() { expect "$1" "docs-only: $2" .standards/checks/decision-log.sh "Spec gate" "Plan gate"; }
branch feat/9-dl; mkdir -p docs/work/9-dl; echo more >> docs/notes.md
echo "# Decisions — #9" > docs/work/9-dl/decisions.md
git add -A . && git commit -qm "docs-only, no gate sections"
dl pass "spec + plan gates absent"
expect fail "docs-only: pre-merge gate still required" .standards/checks/decision-log.sh "Pre-merge gate"
printf '## Spec gate\nVerdict: N/A — docs-only\n\n## Plan gate\nVerdict: N/A — docs-only: wording\n' >> docs/work/9-dl/decisions.md
dl pass "Verdict: N/A — docs-only"
git checkout -q docs
cp "$SKILL/templates/decisions.md" docs/work/9-dl/decisions.md
dl pass "the template's PENDING spec + plan gates left as they are"
git checkout -q docs
printf '## Spec gate\nVerdict: FAIL — wrong user\n' >> docs/work/9-dl/decisions.md
dl fail "spec gate present and FAIL"
git checkout -q docs
# Docs that are rules or behaviour are not docs-only: a gate file, or BEHAVIOR_DOCS_GLOBS.
mkdir -p docs/guidelines; echo "rule" > docs/guidelines/repo-standards.md; git add docs; git commit -qm "rulebook edit"
dl fail "rulebook (a gate file) edited → spec + plan gates required"
git reset -q --hard HEAD~1
mkdir -p .claude; echo "always approve" > .claude/x.md; git add .claude; git commit -qm "agent command"
dl fail ".claude/x.md (a gate file) → spec + plan gates required"
git reset -q --hard HEAD~1
mkdir -p prompts; echo "You are a refund bot." > prompts/system.md; git add prompts; git commit -qm "runtime prompt"
dl pass "prompts/system.md, BEHAVIOR_DOCS_GLOBS unset → docs-only"
echo 'BEHAVIOR_DOCS_GLOBS="prompts/*"' >> .standards/config.sh
dl fail "prompts/system.md with BEHAVIOR_DOCS_GLOBS set → spec + plan gates required"
git checkout -q .standards/config.sh; git reset -q --hard HEAD~1
# CLAUDE.md facts outside the markers are docs, not a gate file (agent-approval.sh --gate-files).
git checkout -q main; { echo "Folders: src/"; cat "$SKILL/templates/claude-md-block.md"; } > CLAUDE.md
git add CLAUDE.md; git commit -qm "main: CLAUDE.md with block"
branch feat/9-cm; mkdir -p docs/work/9-cm; echo "# Decisions — #9" > docs/work/9-cm/decisions.md
sed 's|^Folders: src/$|Folders: src/ site/|' CLAUDE.md > "$T/c" && cp "$T/c" CLAUDE.md; git add -A .; git commit -qm "CLAUDE.md fact"
dl pass "CLAUDE.md edited outside the markers only → docs-only"
sed 's|^- Every change starts from a GitHub issue|- Most changes start from a GitHub issue|' CLAUDE.md > "$T/c" && cp "$T/c" CLAUDE.md; git commit -qam "and a rule"
dl fail "CLAUDE.md fact plus an inside-block change → not docs-only"
git checkout -q main; git reset -q --hard HEAD~1
echo "@docs/team-rules.md" > CLAUDE.md; echo "two reviewers" > docs/team-rules.md; git add CLAUDE.md docs; git commit -qm "main: import"
branch feat/9-imp; mkdir -p docs/work/9-imp; echo "# Decisions — #9" > docs/work/9-imp/decisions.md
echo "no reviewers" > docs/team-rules.md; git add -A .; git commit -qm "edit imported file"
dl fail "a file CLAUDE.md imports edited → not docs-only"
git checkout -q main; git reset -q --hard HEAD~1; git checkout -q feat/9-dl
echo y >> src/a.sh; git commit -qam "now an app change too"
dl fail "app file touched → spec + plan gates required"
git reset -q --hard HEAD~1
# Without DOCS_GLOBS: only prose files, none under SRC_GLOBS or TEST_GLOBS.
echo 'DOCS_GLOBS=""' >> .standards/config.sh
dl pass "DOCS_GLOBS unset, only .md files touched"
git checkout -q .standards/config.sh
echo '{}' > package.json; git add package.json; git commit -qm "a manifest"
echo 'DOCS_GLOBS=""' >> .standards/config.sh
dl fail "DOCS_GLOBS unset, package.json touched"
git checkout -q .standards/config.sh; git reset -q --hard HEAD~1
echo "# notes" > src/README.md; git add src; git commit -qm "readme under src"
echo 'DOCS_GLOBS=""' >> .standards/config.sh
dl fail "a .md under SRC_GLOBS is source, not docs"
git checkout -q .standards/config.sh; git reset -q --hard HEAD~1

echo "cross-reads"
cr() { expect "$1" "cross-reads: $2" .standards/checks/cross-reads.sh; }
branch feat/9-cr
cr pass "tests read only app paths"
echo '. src/a.sh; cat "site/data.txt"' > tests/a.test.sh; git commit -qam "app test reads a site file"
cr fail "app test reads a site file not in SHARED_GLOBS"
echo 'SHARED_GLOBS="$SHARED_GLOBS site/data.txt"' >> .standards/config.sh
cr pass "same read, path listed in SHARED_GLOBS"
git checkout -q .standards/config.sh
echo 'SITE_GLOBS=""; DOCS_GLOBS=""' >> .standards/config.sh
cr pass "classes off -> check skipped"
git checkout -q .standards/config.sh
git checkout -q main -- tests/a.test.sh; git commit -qam "no cross read"
echo "const p = '../docs/notes.md'" > site/tests/n.test.sh; git add site/tests/n.test.sh; git commit -qm "site test reads a docs file"
cr fail "site test reads a docs file not in SHARED_GLOBS"
git rm -q site/tests/n.test.sh site/tests/keep.test.sh; git commit -qm "drop site tests"
cr fail "configured side with no file to scan fails closed"

echo "guards"
# GUARDS_CMD runs in pre-push by change class: GUARDS_PART "app" (default) skips it on a docs
# or site branch; "always" runs it on every branch. The probe guard exits $GUARD_RC.
pp() { # pp <GUARD_RC>: pre-push of HEAD; output in $T/pp.out
  printf 'refs/heads/x %s refs/heads/x %s\n' "$(git rev-parse HEAD)" "$z" > "$T/pp-refs"
  GUARD_RC="$1" .standards/hooks/pre-push < "$T/pp-refs" > "$T/pp.out" 2>&1
}
git checkout -q main
printf '#!/bin/sh\necho "guard-probe: scanned src/"\nexit ${GUARD_RC:-0}\n' > guard-probe.sh; chmod +x guard-probe.sh
echo 'GUARDS_CMD="./guard-probe.sh"' >> .standards/config.sh; git add guard-probe.sh .standards; git commit -qm "main: a guard"
branch feat/9-gd; echo more >> docs/notes.md; git commit -qam docs
pp 1
expect pass "guards: docs branch → SKIP guards" grep -q "SKIP guards (change class docs" "$T/pp.out"
branch feat/9-ga; echo y >> src/a.sh; git commit -qam app
pp 1
expect pass "guards: app branch, guard fails → FAIL guards, push blocked" \
  bash -c "grep -q 'FAIL guards' '$T/pp.out' && grep -q 'pre-push BLOCKED' '$T/pp.out'"
pp 0
expect pass "guards: app branch, guard passes → PASS guards, its output shown" \
  bash -c "grep -q 'PASS guards' '$T/pp.out' && grep -q 'guard-probe: scanned src/' '$T/pp.out'"
git checkout -q main; echo 'GUARDS_PART="always"' >> .standards/config.sh; git commit -qam "main: guards always"
branch feat/9-gd2; echo more >> docs/notes.md; git commit -qam docs
pp 1
expect pass "guards: GUARDS_PART=always → runs on a docs branch" grep -q "FAIL guards" "$T/pp.out"
git checkout -q main; git reset -q --hard HEAD~2

echo "local checks"
# .standards/local/pre-push.d/*: the repo's own checks, run after the standard ones on every
# class; upgrades never touch them. The probe exits $LOCAL_RC.
git checkout -q main; mkdir -p .standards/local/pre-push.d
cp "$SKILL/tests/local-fixtures/probe.sh" .standards/local/pre-push.d/10-probe; chmod +x .standards/local/pre-push.d/10-probe
git add .standards; git commit -qm "main: a local check"
branch feat/9-lc; echo more >> docs/notes.md; git commit -qam docs
LOCAL_RC=1 pp 0
expect pass "local: failing local check → FAIL local 10-probe, push blocked" \
  bash -c "grep -q 'FAIL local 10-probe' '$T/pp.out' && grep -q 'pre-push BLOCKED' '$T/pp.out'"
LOCAL_RC=0 pp 0
expect pass "local: passing local check → PASS, its output shown" \
  bash -c "grep -q 'PASS local 10-probe' '$T/pp.out' && grep -q 'local-probe: scanned src/' '$T/pp.out' && ! grep -q 'FAIL local' '$T/pp.out'"
cp "$SKILL/tests/local-fixtures/probe.sh" .standards/local/pre-push.d/20-noexec; chmod -x .standards/local/pre-push.d/20-noexec
git add .standards; git commit -qm "not executable"
LOCAL_RC=0 pp 0
expect pass "local: a file that is not executable → blocked, says chmod +x" \
  bash -c "grep -q 'chmod +x .standards/local/pre-push.d/20-noexec' '$T/pp.out' && grep -q 'pre-push BLOCKED' '$T/pp.out'"
git checkout -q main; git reset -q --hard HEAD~1

# --- safe_rm: the only way .standards/ scripts delete ---
echo "safe-rm"
# rm_lint <dir or file>...: prints file:line of every deletion command but `git rm`, and
# fails if there is one. The program (tests/saferm-fixtures/rm-lint.awk) and its allow list
# (rm-allow.txt: the exact safe_rm line and the exact EXIT trap line, by path) live outside
# the scanned files, so their patterns are no hits here. A lint, not a sandbox.
rm_lint() {
  local fx="$SKILL/tests/saferm-fixtures"
  find "$@" -type f -exec awk -v allow="$fx/rm-allow.txt" -f "$fx/rm-lint.awk" "$fx/rm-allow.txt" {} +
}
expect pass "lint-rm: scripts/, tests/run.sh, the speed cases and the evidence template are clean" \
  rm_lint "$SKILL/scripts" "$SKILL/tests/run.sh" "$SKILL/tests/speed-cases.sh" "$SKILL/tests/parallel-fixtures" "$SKILL/templates/evidence-capture.example.sh"
# Planted in a copy, never in the real scripts/.
cp -R "$SKILL/scripts" "$T/lint-probe"
expect pass "lint-rm: the unplanted copy passes" rm_lint "$T/lint-probe"
cat "$SKILL/tests/saferm-fixtures/bare-rm.sh" >> "$T/lint-probe/checks/tdd.sh"
expect fail "lint-rm: planted copy of scripts/ fails" rm_lint "$T/lint-probe"
expect pass "lint-rm: names the planted file:line" grep -q "lint-probe/checks/tdd.sh:[0-9][0-9]*: rm[ ]-f" "$T/last.log.prev"
cp "$SKILL/scripts/checks/tdd.sh" "$T/lint-probe/checks/tdd.sh"
cat "$SKILL/tests/saferm-fixtures/marked-rm.sh" >> "$T/lint-probe/checks/doc-map.sh"
expect fail "lint-rm: the marker outside common.sh excuses nothing" rm_lint "$T/lint-probe"
# Disguised forms, one per line, planted in a copy: every one must be flagged.
cp "$SKILL/scripts/checks/doc-map.sh" "$T/lint-probe/checks/doc-map.sh"
cp "$SKILL/tests/saferm-fixtures/evade.sh" "$T/lint-probe/checks/evade.sh"
rm_lint "$T/lint-probe" > "$T/evade.out" 2>&1
expect pass "lint-rm: flags every disguised form ($(grep -c '/evade.sh:[0-9]*: L' "$T/evade.out") of $(grep -c '^L' "$SKILL/tests/saferm-fixtures/evade.sh"))" \
  test "$(grep -c '/evade.sh:[0-9]*: L' "$T/evade.out")" = "$(grep -c '^L' "$SKILL/tests/saferm-fixtures/evade.sh")"
# The marker is honoured by exact line and path, not by file name: a new checks/run.sh gets none.
cp -R "$SKILL/scripts" "$T/lint-probe2"
cp "$SKILL/tests/saferm-fixtures/marked-rm.sh" "$T/lint-probe2/checks/run.sh"
expect fail "lint-rm: a new file named run.sh gets no free marker" rm_lint "$T/lint-probe2"

# saferm_box <dir> <common.sh>: a fake HOME (<dir>/home) and fake TMPDIR (<dir>/tmp) holding
# sentinel files, and a git repo inside the fake HOME (like ~/www/repo) with .standards/
# installed and <common.sh> as its lib. Nothing here touches the real HOME.
saferm_box() {
  local B="$1"
  mkdir -p "$B/home/secret" "$B/home/docs" "$B/home/tmp/x" "$B/home/www/repo" "$B/tmp" || return 1
  : > "$B/sentinel"; : > "$B/home/sentinel"; : > "$B/home/secret/sentinel"; : > "$B/home/docs/sentinel"
  : > "$B/home/www/outside.txt"; : > "$B/tmp/sentinel"
  # Two repos holding their $HOME: one is $HOME (dotfiles), one is its parent.
  mkdir -p "$B/dot/home/docs" "$B/par/home/docs" || return 1
  : > "$B/dot/home/docs/sentinel"; : > "$B/par/home/docs/sentinel"
  (cd "$B/home/www/repo" && git init -q -b main && mkdir -p .standards && cp -R "$SKILL/scripts/." .standards/ \
    && cp "$2" .standards/lib/common.sh && : > .git/sentinel && mkdir -p junk1 junk2/sub && : > junk2/sub/f \
    && ln -s "$B/home/secret" link-to-secret && ln -s "$B/home" home-link) || return 1
  for d in "$B/dot/home" "$B/par"; do
    (cd "$d" && git init -q -b main && cp -R "$B/home/www/repo/.standards" .standards) || return 1
  done
}
# sr_run <box> <arg>...: safe_rm in the box's repo, as the box's HOME and TMPDIR.
sr_run() { local B="$1"; shift; sr_tmp "$B" "$B/tmp" "$@"; }
# sr_tmp <box> <tmpdir> <arg>...: the same with another TMPDIR.
sr_tmp() { local B="$1" tmp="$2"; shift 2; sr_at "$B/home/www/repo" "$B/home" "$tmp" "$@"; }
# sr_at <cwd> <HOME> <TMPDIR> <arg>...: safe_rm run from <cwd> as that HOME and TMPDIR.
sr_at() {
  local cwd="$1" home="$2" tmp="$3"; shift 3
  (cd "$cwd" && HOME="$home" TMPDIR="$tmp" bash "$SKILL/tests/saferm-fixtures/safe-rm.sh" "$@")
}
# saferm_cases <box>: every refusal, then the sentinels, then what it must delete.
saferm_cases() {
  local B="$1" R2="$1/home/www/repo" d
  expect fail "safe_rm: no path" sr_run "$B"
  expect fail "safe_rm: empty path" sr_run "$B" ""
  expect fail "safe_rm: \$HOME" sr_run "$B" "$B/home"
  expect fail "safe_rm: \$HOME with a trailing slash" sr_run "$B" "$B/home/"
  expect fail "safe_rm: parent of \$HOME" sr_run "$B" "$B"
  expect fail "safe_rm: ../ out of the repo (relative)" sr_run "$B" "../outside.txt"
  expect fail "safe_rm: ../ out of the repo (absolute)" sr_run "$B" "$R2/../outside.txt"
  expect fail "safe_rm: symlinked parent pointing into \$HOME" sr_run "$B" "$R2/link-to-secret/sentinel"
  expect fail "safe_rm: file in \$HOME outside the repo" sr_run "$B" "$B/home/secret/sentinel"
  expect fail "safe_rm: the repo root" sr_run "$B" "$R2"
  expect fail "safe_rm: the repo root as ." sr_run "$B" "."
  expect fail "safe_rm: a file inside .git/" sr_run "$B" "$R2/.git/sentinel"
  expect fail "safe_rm: .git itself" sr_run "$B" ".git"
  expect fail "safe_rm: the temp root itself" sr_run "$B" "$B/tmp"
  expect fail "safe_rm: parent directory missing" sr_run "$B" "$R2/no-such-dir/x"
  expect fail "safe_rm --check /" sr_run "$B" --check /
  expect pass "safe_rm: refusal says refused: <path> — <reason>" grep -q "^refused: / — " "$T/last.log.prev"
  # A TMPDIR that is /, $HOME or holds $HOME is no temp root: it would make all of $HOME
  # deletable. One strictly inside $HOME (~/tmp) still counts, for what is inside it only.
  expect fail "safe_rm: TMPDIR=\$HOME → \$HOME/docs refused" sr_tmp "$B" "$B/home" "$B/home/docs"
  expect fail "safe_rm: TMPDIR=\$HOME → file in \$HOME refused" sr_tmp "$B" "$B/home" "$B/home/secret/sentinel"
  expect fail "safe_rm: TMPDIR=parent of \$HOME → \$HOME/docs refused" sr_tmp "$B" "$B" "$B/home/docs"
  expect fail "safe_rm: TMPDIR=/ → --check \$HOME/docs refused" sr_tmp "$B" / --check "$B/home/docs"
  expect fail "safe_rm: TMPDIR=\$HOME/tmp → \$HOME/docs refused" sr_tmp "$B" "$B/home/tmp" "$B/home/docs"
  # A leading // (pwd -P keeps it) must not slip past the prefix checks.
  expect fail "safe_rm: TMPDIR=//<holds \$HOME> → //\$HOME/docs refused" sr_tmp "$B" "/$B" "/$B/home/docs"
  expect fail "safe_rm: HOME=//\$HOME → \$HOME/docs refused" sr_at "$R2" "/$B/home" "$B/tmp" "$B/home/docs"
  expect fail "safe_rm: HOME=/ → --check \$HOME/docs refused" sr_at "$R2" / "$B/tmp" --check "$B/home/docs"
  # A relative TMPDIR would resolve against the cwd: ignored.
  expect fail "safe_rm: TMPDIR=.. → a file beside the repo refused" sr_tmp "$B" .. "$B/home/www/outside.txt"
  expect fail "safe_rm: TMPDIR=../../secret → a file in it refused" sr_tmp "$B" ../../secret "$B/home/secret/sentinel"
  # A repo that is $HOME or holds it (dotfiles) is no allowed root.
  expect fail "safe_rm: repo = \$HOME → \$HOME/docs refused" sr_at "$B/dot/home" "$B/dot/home" "$B/tmp" "$B/dot/home/docs"
  expect pass "safe_rm: ... and says the repo holds \$HOME" grep -q 'repo holds \$HOME' "$T/last.log.prev"
  expect fail "safe_rm: repo holds \$HOME → \$HOME/docs refused" sr_at "$B/par" "$B/par/home" "$B/tmp" "$B/par/home/docs"
  expect fail "safe_rm: one good and one bad path → refused" sr_run "$B" "$R2/junk1" "$B/home/secret/sentinel"
  expect pass "safe_rm: ... and the good one is not deleted either" test -d "$R2/junk1"
  for d in "$B/sentinel" "$B/home/sentinel" "$B/home/secret/sentinel" "$B/home/docs/sentinel" "$B/home/www/outside.txt" \
           "$B/dot/home/docs/sentinel" "$B/par/home/docs/sentinel" \
           "$B/tmp/sentinel" "$R2/.git/sentinel" "$R2/.git/HEAD" "$R2/.standards/lib/common.sh"; do
    expect pass "safe_rm: still there after every refusal: ${d#"$B"/}" test -e "$d"
  done
  expect pass "safe_rm --check: a good path passes" sr_run "$B" --check "$R2/junk1"
  expect pass "safe_rm --check: ... and deletes nothing" test -d "$R2/junk1"
  expect pass "safe_rm: a dir inside the repo" sr_run "$B" "$R2/junk2"
  expect pass "safe_rm: ... is gone" test ! -e "$R2/junk2"
  d="$(mktemp -d "$B/tmp/del.XXXXXX")" && : > "$d/f"
  expect pass "safe_rm: a mktemp -d dir in TMPDIR" sr_run "$B" "$d"
  expect pass "safe_rm: ... is gone" test ! -e "$d"
  expect pass "safe_rm: TMPDIR=\$HOME/tmp → a dir inside it" sr_tmp "$B" "$B/home/tmp" "$B/home/tmp/x"
  expect pass "safe_rm: ... is gone" test ! -e "$B/home/tmp/x"
  d="$(mktemp -d "$B/tmp/dot.XXXXXX")"
  expect pass "safe_rm: repo = \$HOME → a mktemp -d dir is still deletable" sr_at "$B/dot/home" "$B/dot/home" "$B/tmp" "$d"
  expect pass "safe_rm: ... is gone" test ! -e "$d"
  expect pass "safe_rm: missing path, parent passes → no-op" sr_run "$B" "$R2/never-existed"
  expect pass "safe_rm: a symlink to \$HOME" sr_run "$B" "$R2/home-link"
  expect pass "safe_rm: ... removes the link" test ! -L "$R2/home-link"
  expect pass "safe_rm: ... and keeps its target" test -f "$B/home/sentinel"
}
saferm_box "$T/box" "$SKILL/scripts/lib/common.sh"
saferm_cases "$T/box"
# The cases bite: drop one check (its line tagged "# safe_rm: <name>") from a copy of
# common.sh, run every case in a fresh box against it, and some must go wrong. The other
# checks (/, $HOME itself, the repo root, the home rule) are layered behind these: dropping
# one alone is caught by another, so it is no bite test. (The home rule only bites when a
# temp root holds $HOME, and tmp-root now ignores such a root.)
for weak in git-dir tmp-root slashes home-root abs-tmpdir repo-home; do
  sed "/# safe_rm: $weak\$/d" "$SKILL/scripts/lib/common.sh" > "$T/common-$weak.sh"
  expect pass "safe_rm bite: copy without '$weak' lost exactly one line" \
    test "$(( $(wc -l < "$SKILL/scripts/lib/common.sh") - $(wc -l < "$T/common-$weak.sh") ))" = 1
  saferm_box "$T/weak-$weak" "$T/common-$weak.sh"
  (pass=0; fail=0; saferm_cases "$T/weak-$weak" > "$T/bite-$weak.log" 2>&1; [ "$fail" -gt 0 ])
  bit=$?
  expect pass "safe_rm bite: cases go wrong without '$weak' ($(grep -c '^  WRONG' "$T/bite-$weak.log") wrong)" test "$bit" = 0
done

# --- speed, same gates: the parallel runner, gate locks, pre-push lanes, bin/ship's e2e + perf ---
. "$SKILL/tests/speed-cases.sh"

echo
echo "$pass passed, $fail wrong"
[ $fail -eq 0 ]
