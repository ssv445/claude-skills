# Repo standards — per-repo configuration. Sourced by .standards/ scripts.
# Every *_CMD is a real command, or empty with a "# N/A — reason" comment beside it.
# Commands run from the repo root.

OWNER=""                 # GitHub login of the human owner; only they add approved / spec-approved
BASE_BRANCH="main"
# Who approves what the gates would send to a person. "owner" (default): gate-file changes
# and blast-radius specs need the owner's approved / spec-approved label. "agent": the
# agent's own approval (agent-approval.sh) covers those too; the spec gate PASS stands in
# for spec-approved. owner-review: required flags block in both modes — they are questions.
# bin/ship reads this from the base branch, so a branch cannot switch its own mode.
APPROVER="owner"

# --- pre-push (budget: 2 min total) ---
LINT_CMD=""
TYPECHECK_CMD=""
UNIT_CMD=""
# The two coverage commands: if they read a report another command writes (e.g. lcov from
# UNIT_CMD), a skipped or cached test class writes none, so they may read a stale one —
# with TEST_CLASSES, have them produce their own report. Maintenance mode skips them.
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
ARCH_DOC="docs/guidelines/architecture.md"   # the architecture doc checked by checks/architecture.sh

# --- bin/ship (pre-merge) ---
E2E_CMD=""
PERF_CMD=""              # must exit non-zero when a budget from a spec's Expectations is exceeded

# --- test classes (optional; a monorepo's app, site, …) ---
# Empty TEST_CLASSES: nothing changes. The plain *_CMD above always run; class commands run
# besides them. Per class: CLASS_<name>_PATHS — globs as above, listing everything its tests
# depend on (sources, test files, runner, lockfile); then any of CLASS_<name>_UNIT_CMD
# (pre-push), CLASS_<name>_E2E_CMD and CLASS_<name>_PERF_CMD (bin/ship), and
# CLASS_<name>_TIMEOUT (seconds, overrides CMD_TIMEOUT). A class runs only when the branch
# changes one of its paths (minus IGNORE_PATHS), and is skipped when the same content and
# command already passed in this clone (<git common dir>/standards-state/results, shared by
# its worktrees). With no base commit to compare against, every class runs. Required alongside: a full run on
# the base branch nightly and before each release (rulebook, "Tests and releases").
TEST_CLASSES=""          # e.g. "app site"
# CLASS_app_PATHS="apps/mac/* packages/core/*"
# CLASS_app_UNIT_CMD="pnpm --filter mac test"
IGNORE_PATHS=""          # never trigger a class, e.g. "VERSION */version.ts"

# --- every command ---
CMD_TIMEOUT=1800         # whole seconds; a command still running is stopped, with all it started, and fails its
                         # gate. Set it above the slowest normal run. Empty or unset: no limit.
HEAVY_LOCK=""            # optional: lock file or dir the repo's heavy jobs hold; pre-push and bin/ship warn when
HEAVY_LOCK_MAX_AGE=3600  # …it is older than this many seconds

# --- release ---
# bin/preflight runs each line as one command (blank and # lines skipped): PASS/FAIL per
# line, non-zero exit on any FAIL. Its output, not a "ready" claim, says a release can go.
PREFLIGHT_CHECKS=""

# --- intake ---
AGENT_ISSUES_PER_NIGHT=1
