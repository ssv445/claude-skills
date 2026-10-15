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

# Two kinds: "site" (a file under SITE_GLOBS, run with SITE_TEST_FILES_CMD) and "app" (the rest).
# Each kind runs red→green on its own: one combined run would let a failing app test hide a site
# test that already passes on the base (and the reverse). With SITE_GLOBS empty everything is "app".
kind_of() { if matches_any "$1" "$SITE_GLOBS"; then echo site; else echo app; fi; }
app_src=""; site_src=""; app_tests=""; site_tests=""
for f in $src; do
  if [ "$(kind_of "$f")" = site ]; then site_src="$site_src $f"; else app_src="$app_src $f"; fi
done
for f in $tests; do
  if [ "$(kind_of "$f")" = site ]; then site_tests="$site_tests $f"; else app_tests="$app_tests $f"; fi
done
# Each kind of source that changed needs a changed test of the same kind: a site test must not
# stand in for an app change, nor the reverse.
if [ -n "$app_src" ] && [ -z "$app_tests" ]; then red "FAIL tdd: app source changed with no app test change:$app_src"; exit 1; fi
if [ -n "$site_src" ] && [ -z "$site_tests" ]; then red "FAIL tdd: site source changed with no site test change:$site_src"; exit 1; fi

scratch=""
cleanup() { [ -n "$scratch" ] && { git worktree remove --force "$scratch" >/dev/null 2>&1; rm -rf "$scratch"; scratch=""; }; }
trap cleanup EXIT

# red_green <label> <test command> <test files>
red_green() {
  local label="$1" cmd="$2" files="$3" d f
  scratch="$(mktemp -d)"
  git worktree add --detach -q "$scratch" "$(base_commit)" || { red "FAIL tdd: could not create scratch checkout"; return 1; }
  for d in $DEPS_LINKS; do
    mkdir -p "$scratch/$(dirname "$d")"
    [ -e "$ROOT/$d" ] && [ ! -e "$scratch/$d" ] && ln -s "$ROOT/$d" "$scratch/$d"
  done
  for f in $files; do
    mkdir -p "$scratch/$(dirname "$f")"
    git show "HEAD:$f" > "$scratch/$f"
  done

  info "tdd[$label]: running new tests against base source (must fail)"
  if (cd "$scratch" && eval "$cmd $files") >/dev/null 2>&1; then
    red "FAIL tdd[$label]: changed tests pass on the base code — they do not catch this change"; return 1
  fi
  cleanup
  info "tdd[$label]: running new tests against HEAD (must pass)"
  if ! eval "$cmd $files"; then red "FAIL tdd[$label]: changed tests fail on HEAD"; return 1; fi
}

if [ -n "$app_tests" ]; then red_green app "$TEST_FILES_CMD" "$app_tests" || exit 1; cleanup; fi
if [ -n "$site_tests" ]; then red_green site "${SITE_TEST_FILES_CMD:-$TEST_FILES_CMD}" "$site_tests" || exit 1; cleanup; fi
green "PASS tdd (red on base, green on HEAD, per test kind)"
