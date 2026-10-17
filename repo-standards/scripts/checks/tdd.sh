#!/usr/bin/env bash
# TDD red→green: each of the branch's changed test files must FAIL, run on its own, against
# the base branch's source, and together they must PASS against HEAD. Proves the tests were
# written to catch this change, whatever order the commits were made in.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

src=""; tests=""
for f in $(changed_files); do
  if matches_any "$f" "$TEST_GLOBS"; then tests="$tests $f"
  elif matches_any "$f" "$SRC_GLOBS"; then src="$src $f"
  fi
done
info "tdd: source changed:${src:- none}"
info "tdd: tests changed:${tests:- none}"

# Two kinds: "site" (a file under SITE_GLOBS, run with SITE_TEST_FILES_CMD) and "app" (the rest).
# Each kind runs red→green on its own: one combined run would let a failing app test hide a site
# test that already passes on the base (and the reverse). With SITE_GLOBS empty everything is "app".
kind_of() { if matches_any "$1" "$SITE_GLOBS"; then echo site; else echo app; fi; }

# src_globs_cover: "no source change" is a pass only when SRC_GLOBS can match source at all.
# Globs that match no tracked file (code in web/ and server/, globs still the default src/*)
# would pass every branch silently. With SITE_GLOBS set, the same per kind: a kind with tracked
# tests but no tracked source has its source outside SRC_GLOBS. Tests win over source, as above.
# Speed (30k-file repos): git's pathspec match pre-filters to files the globs could match — its
# default pathspec "*" also crosses "/", so it is a superset and matches_any keeps the exact
# rule — and the scan stops once no answer can change (SITE_GLOBS empty: the first source file;
# set: the first source file of each kind).
src_globs_cover() {
  local f app_s="" site_s="" app_t="" site_t="" k t s
  while IFS= read -r -d '' f; do
    if matches_any "$f" "$SITE_GLOBS"; then k=site; else k=app; fi
    if matches_any "$f" "$TEST_GLOBS"; then
      case "$k" in site) site_t=1 ;; *) app_t=1 ;; esac
    elif matches_any "$f" "$SRC_GLOBS"; then
      case "$k" in site) site_s=1 ;; *) app_s=1 ;; esac
    fi
    if [ -z "$SITE_GLOBS" ]; then [ -z "$app_s" ] || break
    elif [ -n "$app_s" ] && [ -n "$site_s" ]; then break; fi
  done < <(set -f; git -c core.quotePath=false ls-files -z -- $SRC_GLOBS $TEST_GLOBS 2>/dev/null)
  if [ -z "$app_s$site_s" ]; then
    red "FAIL tdd: SRC_GLOBS matches no tracked file — set it in .standards/config.sh (or SRC_GLOBS=\"\" with a # N/A — reason comment for a repo with no source)"; return 1
  fi
  [ -n "$SITE_GLOBS" ] || return 0
  for k in app site; do
    case "$k" in app) t="$app_t"; s="$app_s" ;; site) t="$site_t"; s="$site_s" ;; esac
    if [ -n "$t" ] && [ -z "$s" ]; then
      red "FAIL tdd: $k tests are tracked but SRC_GLOBS matches no $k source file — add the $k's source paths to SRC_GLOBS in .standards/config.sh"; return 1
    fi
  done
}

if [ -z "$src" ]; then
  if [ -z "$SRC_GLOBS" ]; then green "PASS tdd (N/A: SRC_GLOBS empty — no source in this repo)"; exit 0; fi
  src_globs_cover || exit 1
  green "PASS tdd (no source change)"; exit 0
fi

dec="$(decisions_file)"
# Exception needs a real reason: a "<reason>" placeholder does not count.
if [ -n "$dec" ] && [ -f "$dec" ] && grep -q '^TDD: N/A — [^<]' "$dec"; then
  info "$(grep '^TDD: N/A — [^<]' "$dec")"
  green "PASS tdd (exception recorded; reviewed at pre-merge gate)"; exit 0
fi
if [ -z "$tests" ]; then red "FAIL tdd: source changed with no test change (or record 'TDD: N/A — reason' in decisions.md)"; exit 1; fi
if [ -z "$TEST_FILES_CMD" ]; then red "FAIL tdd: TEST_FILES_CMD is not configured"; exit 1; fi

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

# tdd_line <kind> <file>: prints the "TDD: <kind> — <files> — <reason>" line in decisions.md
# that names <file> (alone or in a comma list), or fails. A line naming no file covers
# nothing, and a "<reason>" placeholder does not count. Bytes (LC_ALL=C): " — " is multibyte.
tdd_line() {
  [ -n "$dec" ] && [ -f "$dec" ] || return 1
  LC_ALL=C awk -v p="TDD: $1 — " -v f="$2" -v sep=" — " '
    index($0, p) != 1 { next }
    { r = substr($0, length(p) + 1); i = index(r, sep); if (!i) next
      why = substr(r, i + length(sep)); if (why !~ /^[^< ]/) next
      n = split(substr(r, 1, i - 1), fs, ",")
      for (k = 1; k <= n; k++) { x = fs[k]; gsub(/^[ \t]+|[ \t]+$/, "", x); if (x == f) { print; found = 1; exit } } }
    END { exit !found }' "$dec"
}

scratch=""
# The scratch checkout is a mktemp -d dir, which safe_rm allows (a temp dir, not the temp root).
cleanup() { [ -n "$scratch" ] && { drop_worktree "$scratch"; scratch=""; }; }
trap cleanup EXIT

# red_green <label> <test command> <test files> <source changed: 1 or empty>
red_green() {
  local label="$1" cmd="$2" files="$3" need_red="$4" d f
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

  # One file per run: in one combined run, a red file hides a file that already passes on the
  # base. This costs a runner start per file, so each file's time is printed for the pre-push budget.
  info "tdd[$label]: running each new test file on its own against base source (must fail)"
  # A file green on base fails, unless decisions.md declares it a refactor (same assertions,
  # reshaped). A compile-only red proves the test names something new, not that its assertion
  # catches the change: accepted only with a per-file compile-red line. Either way the fail
  # message prints the exact line to add.
  local out start l green_files="" compile_files="" reds=0
  for f in $files; do
    start=$(date +%s)
    if out="$(cd "$scratch" && eval "$cmd $f" 2>&1)"; then
      if l="$(tdd_line refactor "$f")"; then info "$f passes on base — declared: $l"
      else red "  $f passes on the base code ($(( $(date +%s) - start ))s) — it does not catch this change"; green_files="$green_files $f"; fi
    elif [ -n "${TDD_COMPILE_FAIL_RE:-}" ] && printf '%s\n' "$out" | grep -qE "$TDD_COMPILE_FAIL_RE"; then
      info "$f red (compile only — assertion not proven) ($(( $(date +%s) - start ))s)"
      if l="$(tdd_line compile-red "$f")"; then info "$l"; reds=$((reds + 1)); else compile_files="$compile_files $f"; fi
    else
      info "$f red on base ($(( $(date +%s) - start ))s)"; reds=$((reds + 1))
    fi
  done
  if [ -n "$green_files" ]; then
    red "FAIL tdd[$label]: every changed test file must fail on the base code on its own. A file that only reshapes tests the base already passes: add to ${dec:-decisions.md}, one line per file:"
    for f in $green_files; do red "    TDD: refactor — $f — <reason>"; done
    return 1
  fi
  if [ -n "$compile_files" ]; then
    red "FAIL tdd[$label]: red only from a compile error (TDD_COMPILE_FAIL_RE) — make the assertion fail on base (e.g. stub the new name there), or add to ${dec:-decisions.md}, one line per file:"
    for f in $compile_files; do red "    TDD: compile-red — $f — <reason>"; done
    return 1
  fi
  if [ -n "$need_red" ] && [ $reds -eq 0 ]; then
    red "FAIL tdd[$label]: source changed but no changed test file is red on base — add a test that fails on the base code (a declared refactor proves nothing about the change), or record 'TDD: N/A — reason'"; return 1
  fi
  cleanup
  info "tdd[$label]: running new tests against HEAD (must pass)"
  if ! eval "$cmd $files"; then red "FAIL tdd[$label]: changed tests fail on HEAD"; return 1; fi
}

if [ -n "$app_tests" ]; then red_green app "$TEST_FILES_CMD" "$app_tests" "${app_src:+1}" || exit 1; cleanup; fi
if [ -n "$site_tests" ]; then red_green site "${SITE_TEST_FILES_CMD:-$TEST_FILES_CMD}" "$site_tests" "${site_src:+1}" || exit 1; cleanup; fi
green "PASS tdd (red on base, green on HEAD, per test kind)"
