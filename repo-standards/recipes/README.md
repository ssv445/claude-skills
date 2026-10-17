# Recipes: coverage and single-file test runs per language

Not installed. Step 4 of `SKILL.md` points here when filling `.standards/config.sh`. Copy the recipe for the repo's stack, adapt the paths, then prove each command can fail (step 8).

What every recipe must give:

- `TEST_FILES_CMD` runs only the test files appended as arguments, and **exits non-zero when it ran zero tests**. A runner that passes on "no tests found" turns TDD red→green into a no-op.
- `DIFF_COVERAGE_CMD` exits non-zero when changed lines are covered less than `DIFF_COVERAGE_MIN`. The usual tool is [`diff-cover`](https://github.com/Bachmann1234/diff_cover) (`pipx install diff-cover`), which reads lcov or Cobertura XML.
- `COVERAGE_TOTAL_CMD` prints total line coverage as a bare number (`87.4`). No instrumented line yet prints `0`, not a vacuous 100.

A helper script lives in `.standards/local/` (upgrades never overwrite it; only `pre-push.d/` there runs on push). Call it by absolute path: `tdd.sh` runs `TEST_FILES_CMD` inside a scratch checkout of the base, which may not have the script yet.

```sh
TEST_FILES_CMD='"$ROOT/.standards/local/tdd-tests.sh"'
```

Total from an lcov file, for any stack that writes one:

```sh
awk -F: '/^LF:/ { f += $2 } /^LH:/ { h += $2 } END { if (f == 0) print 0; else printf "%.1f\n", 100 * h / f }' coverage/lcov.info
```

## TypeScript / Vitest

```sh
UNIT_CMD="pnpm vitest run --coverage"   # vitest.config.ts: coverage: { provider: "v8", reporter: ["lcov", "text-summary"] }
TEST_FILES_CMD="pnpm vitest run"        # exits 1 on "No test files found" (keep passWithNoTests off)
DIFF_COVERAGE_CMD='diff-cover coverage/lcov.info --compare-branch=origin/$BASE_BRANCH --fail-under=$DIFF_COVERAGE_MIN'
COVERAGE_TOTAL_CMD="<the lcov awk above>"
TDD_COMPILE_FAIL_RE="Cannot find module|does not provide an export named|error TS2305"
```

**Two Vitest configs** (plain Node tests plus Cloudflare Workers tests under `@cloudflare/vitest-pool-workers`, as in a Workers app): each test file must run under the config that owns it. Name the second kind so a glob can tell them apart (`*.workers.test.ts`), exclude it from the first config, and route files in `.standards/local/tdd-tests.sh`:

```sh
#!/usr/bin/env bash
# tdd-tests.sh <test file>...: each file under the Vitest config that owns it.
[ $# -gt 0 ] || { echo "usage: tdd-tests.sh <test file>..." >&2; exit 2; }
node=(); workers=()
for f in "$@"; do
  case "$f" in
    *.workers.test.ts) workers+=("$f") ;;
    *.test.ts) node+=("$f") ;;
    *) echo "tdd-tests: do not know how to run $f" >&2; exit 2 ;;
  esac
done
rc=0
[ ${#node[@]} -eq 0 ] || pnpm vitest run --config vitest.config.ts "${node[@]}" || rc=1
[ ${#workers[@]} -eq 0 ] || pnpm vitest run --config vitest.workers.config.ts --max-workers=1 --no-isolate "${workers[@]}" || rc=1
exit $rc
```

`UNIT_CMD` then runs both configs (`pnpm test && pnpm test:workers`). Check whether the Workers run writes coverage before you count on it; if only the Node config does, say which source files that leaves uncovered in a comment next to `DIFF_COVERAGE_CMD`.

## Python / pytest

```sh
UNIT_CMD="python -m pytest --cov=src --cov-report=xml"
TEST_FILES_CMD="python -m pytest -q"     # exits 5 when it collects no test
DIFF_COVERAGE_CMD='diff-cover coverage.xml --compare-branch=origin/$BASE_BRANCH --fail-under=$DIFF_COVERAGE_MIN'
COVERAGE_TOTAL_CMD="python -m coverage report --format=total"   # coverage >= 7
TDD_COMPILE_FAIL_RE="ImportError|ModuleNotFoundError|cannot import name"
DEPS_LINKS=".venv"
```

## Go

Go runs packages, not files, and `go test -run X` with no match **exits 0** ("no tests to run"). So `.standards/local/tdd-tests.sh` collects the `Test…` names in each file, runs them in that file's package, and fails when a file has none:

```sh
#!/usr/bin/env bash
# tdd-tests.sh <x_test.go>...: run the Test functions these files define, in their packages.
[ $# -gt 0 ] || { echo "usage: tdd-tests.sh <x_test.go>..." >&2; exit 2; }
rc=0
for f in "$@"; do
  case "$f" in *_test.go) ;; *) echo "tdd-tests: skipping non-test file $f" >&2; continue ;; esac
  names="$(sed -n 's/^func \(Test[A-Za-z0-9_]*\)(t \*testing\.T).*/\1/p' "$f" | paste -sd'|' -)"
  [ -n "$names" ] || { echo "tdd-tests: no func Test… in $f" >&2; exit 1; }
  go test "./$(dirname "$f")" -run "^($names)\$" -count=1 || rc=1
done
exit $rc
```

```sh
UNIT_CMD="go test -coverprofile=coverage.out ./..."
COVERAGE_TOTAL_CMD="go tool cover -func=coverage.out | awk '/^total:/ { sub(/%/, \"\", \$3); print \$3 }'"
DIFF_COVERAGE_CMD='gocover-cobertura < coverage.out > coverage.xml && diff-cover coverage.xml --compare-branch=origin/$BASE_BRANCH --fail-under=$DIFF_COVERAGE_MIN'
TDD_COMPILE_FAIL_RE="undefined: |has no field or method|cannot use .* as"
DEPS_LINKS=""   # the module cache is global
```

`gocover-cobertura` (github.com/boumenot/gocover-cobertura) converts the profile; install it at a pinned version and list it in the repo's setup.

## Swift (SwiftPM, Swift Testing)

Swift cannot run one file either. `.standards/local/tdd-tests.sh` collects the `@Test` function and `@Suite` type names (and XCTest `func test…` methods) from the given files and passes one alternation to `swift test --filter`. A filter that matches nothing runs zero tests and passes, so the script fails when it finds no name:

```sh
#!/usr/bin/env bash
# tdd-tests.sh <test file>...: run only the tests these Swift files define.
[ $# -gt 0 ] || { echo "usage: tdd-tests.sh <test file>..." >&2; exit 2; }
files=()
for f in "$@"; do
  case "$f" in
    *.swift) files+=("$f") ;;
    *) echo "tdd-tests: skipping non-test file $f" >&2 ;;   # fixtures under Tests/ match TEST_GLOBS
  esac
done
[ ${#files[@]} -gt 0 ] || { echo "tdd-tests: no runnable test file in: $*" >&2; exit 1; }
names="$(awk '
  /@Suite/ { suite = 1 }
  suite && match($0, /(struct|class|enum|actor)[ \t]+[A-Za-z_][A-Za-z0-9_]*/) {
    split(substr($0, RSTART, RLENGTH), p, /[ \t]+/); print p[2]; suite = 0
  }
  /@Test/ { test = 1 }
  test && match($0, /func[ \t]+[A-Za-z_][A-Za-z0-9_]*/) {
    split(substr($0, RSTART, RLENGTH), p, /[ \t]+/); print p[2]; test = 0
  }
  match($0, /func[ \t]+test[A-Za-z0-9_]*/) { split(substr($0, RSTART, RLENGTH), p, /[ \t]+/); print p[2] }
' "${files[@]}" | sort -u | paste -sd'|' -)"
[ -n "$names" ] || { echo "tdd-tests: no @Test, @Suite or func test… in: ${files[*]}" >&2; exit 1; }
echo "tdd-tests: swift test --filter '$names'" >&2
swift test --filter "$names"
```

Coverage, in `.standards/local/coverage.sh` (`total` prints the number, `diff` runs diff-cover). It reads the profile `swift test --enable-code-coverage` (`UNIT_CMD`) left, and runs the tests itself only when there is none:

```sh
#!/usr/bin/env bash
# coverage.sh total|diff: line coverage of the package's own sources.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"
lcov() {
  local bin profdata xctest exe
  bin="$(swift build --show-bin-path)" || return 1
  profdata="$bin/codecov/default.profdata"
  [ -f "$profdata" ] || swift test --enable-code-coverage >&2 || return 1
  xctest="$(ls -d "$bin"/*.xctest | head -1)"
  exe="$xctest/Contents/MacOS/$(basename "$xctest" .xctest)"   # macOS bundle layout
  mkdir -p coverage
  # Leave out tests, build output, and any target no unit test can reach (say why in config.sh).
  xcrun llvm-cov export -format=lcov -instr-profile="$profdata" "$exe" \
    -ignore-filename-regex='(/Tests/|/\.build/)' > coverage/lcov.info
}
case "$1" in
  total) lcov || exit 1
         awk -F: '/^LF:/ { f += $2 } /^LH:/ { h += $2 } END { if (f == 0) print 0; else printf "%.1f\n", 100 * h / f }' coverage/lcov.info ;;
  diff)  lcov || exit 1
         diff-cover coverage/lcov.info --compare-branch="origin/$BASE_BRANCH" --fail-under="$DIFF_COVERAGE_MIN" ;;
  *) echo "usage: coverage.sh total|diff" >&2; exit 2 ;;
esac
```

```sh
UNIT_CMD="swift test --enable-code-coverage"
TEST_FILES_CMD='"$ROOT/.standards/local/tdd-tests.sh"'
DIFF_COVERAGE_CMD=".standards/local/coverage.sh diff"
COVERAGE_TOTAL_CMD=".standards/local/coverage.sh total"
TDD_COMPILE_FAIL_RE="cannot find .* in scope|has no member|no such module"
FILE_SIZE_GLOBS="*.swift"
```

With change classes on, `coverage.sh diff` should build only what the branch touched: wrap each report in `checks_for app` / `checks_for site-change` from `common.sh`, and skip with a printed line when neither applies.
