#!/usr/bin/env bash
# TDD red→green: the branch's changed test files must FAIL against the base branch's
# source and PASS against HEAD. Proves the tests were written to catch this change,
# whatever order the commits were made in.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

src=""; tests=""
for f in $(changed_files); do
  if matches_any "$f" "$TEST_GLOBS"; then tests="$tests $f"
  elif matches_any "$f" "$SRC_GLOBS"; then src="$src $f"
  fi
done
info "tdd: source changed:${src:- none}"
info "tdd: tests changed:${tests:- none}"

if [ -z "$src" ]; then green "PASS tdd (no source change)"; exit 0; fi

dec="$(decisions_file)"
# Exception needs a real reason: a "<reason>" placeholder does not count.
if [ -n "$dec" ] && [ -f "$dec" ] && grep -q '^TDD: N/A — [^<]' "$dec"; then
  info "$(grep '^TDD: N/A — [^<]' "$dec")"
  green "PASS tdd (exception recorded; reviewed at pre-merge gate)"; exit 0
fi
if [ -z "$tests" ]; then red "FAIL tdd: source changed with no test change (or record 'TDD: N/A — reason' in decisions.md)"; exit 1; fi
if [ -z "$TEST_FILES_CMD" ]; then red "FAIL tdd: TEST_FILES_CMD is not configured"; exit 1; fi

scratch="$(mktemp -d)"
cleanup() { git worktree remove --force "$scratch" >/dev/null 2>&1; rm -rf "$scratch"; }
trap cleanup EXIT
git worktree add --detach -q "$scratch" "$(base_commit)" || { red "FAIL tdd: could not create scratch checkout"; exit 1; }
for d in $DEPS_LINKS; do
  [ -e "$ROOT/$d" ] && [ ! -e "$scratch/$d" ] && ln -s "$ROOT/$d" "$scratch/$d"
done
for f in $tests; do
  mkdir -p "$scratch/$(dirname "$f")"
  git show "HEAD:$f" > "$scratch/$f"
done

info "tdd: running new tests against base source (must fail)"
if (cd "$scratch" && eval "$TEST_FILES_CMD $tests") >/dev/null 2>&1; then
  red "FAIL tdd: changed tests pass on the base code — they do not catch this change"; exit 1
fi
info "tdd: running new tests against HEAD (must pass)"
if ! eval "$TEST_FILES_CMD $tests"; then red "FAIL tdd: changed tests fail on HEAD"; exit 1; fi
green "PASS tdd (red on base, green on HEAD)"
