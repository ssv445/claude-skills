# Repo standards — per-repo configuration. Sourced by .standards/ scripts.
# Every *_CMD is a real command, or empty with a "# N/A — reason" comment beside it.
# Commands run from the repo root.

OWNER=""                 # GitHub login of the human owner; only they add approved / spec-approved
BASE_BRANCH="main"

# --- pre-push (budget: 2 min total) ---
LINT_CMD=""
TYPECHECK_CMD=""
UNIT_CMD=""
DIFF_COVERAGE_CMD=""     # must exit non-zero when changed-line coverage < DIFF_COVERAGE_MIN
DIFF_COVERAGE_MIN=90
COVERAGE_TOTAL_CMD=""    # prints total line coverage as a bare number, e.g. 87.4; compared to .standards/coverage-baseline
TEST_FILES_CMD=""        # runs ONLY the test files appended as arguments, e.g. "pnpm vitest run"
SEED_CHECK_CMD=""        # validates seeds against the current schema

# Space-separated globs; * also matches "/".
SRC_GLOBS="src/* app/* apps/* packages/* lib/*"
TEST_GLOBS="*.test.* *.spec.* *_test.* */__tests__/* tests/* test/* e2e/*"
DEPS_LINKS="node_modules"        # paths symlinked into the TDD scratch checkout so tests can run there
FILE_SIZE_GLOBS="*.ts *.tsx *.js *.jsx *.mjs *.py *.go *.rb *.php"
MAX_FILE_LINES=400

# --- bin/ship (pre-merge) ---
E2E_CMD=""
PERF_CMD=""              # must exit non-zero when a budget from a spec's Expectations is exceeded

# --- intake ---
AGENT_ISSUES_PER_NIGHT=1
