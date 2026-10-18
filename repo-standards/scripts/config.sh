# Repo standards — per-repo configuration. Sourced by .standards/ scripts.
# Every *_CMD is a real command, or empty with a "# N/A — reason" comment beside it.
# Commands run from the repo root.

OWNER=""                 # GitHub login of the human owner; only they add approved / spec-approved
BASE_BRANCH="main"
# Who approves what the gates would send to a person. "agent" (default): the agent's own
# approval (agent-approval.sh) covers gate-file changes and blast-radius specs; the spec
# gate PASS stands in for spec-approved. "owner": those need the owner's approved /
# spec-approved label. owner-review: required flags block in both modes — they are questions.
# bin/ship reads this from the base branch, so a branch cannot switch its own mode; a base
# with no readable APPROVER line falls back to "owner" (fail closed).
APPROVER="agent"

# --- pre-push (budget: 2 min total) ---
# SITE_*_CMD (optional): the same gate for a second half of the repo, e.g. a website next to an
# app. They run by change class (see "Change class" below); leave empty for a single-part repo.
LINT_CMD=""
SITE_LINT_CMD=""
TYPECHECK_CMD=""
SITE_TYPECHECK_CMD=""
UNIT_CMD=""
SITE_UNIT_CMD=""
DIFF_COVERAGE_CMD=""     # must exit non-zero when changed-line coverage < DIFF_COVERAGE_MIN. Runs on every class:
                         # with change classes on, the script picks its own reports (checks_for app / site-change)
DIFF_COVERAGE_MIN=90
COVERAGE_TOTAL_CMD=""    # prints total line coverage as a bare number, e.g. 87.4; compared to .standards/coverage-baseline.
                         # Measures the app, so it is skipped when change classes are on and the app is untouched
TEST_FILES_CMD=""        # runs ONLY the test files appended as arguments, e.g. "pnpm vitest run". Must exit
                         # non-zero when it runs zero tests: an empty filter must never count as green
                         # (a runner that passes on "no tests found" turns TDD's red→green into a no-op)
SITE_TEST_FILES_CMD=""   # same for test files under SITE_GLOBS, same zero-tests rule; empty = TEST_FILES_CMD
SEED_CHECK_CMD=""        # validates seeds against the current schema
GUARDS_CMD=""            # optional: runs the repo's invariant guards (e.g. "for g in scripts/guard-*.sh; do $g || exit 1; done").
                         # Each guard prints what it scanned and has a test that plants a violation and sees it fail
GUARDS_PART="app"        # which change class runs GUARDS_CMD: "app" (skipped on a docs- or site-only branch),
                         # "site" (skipped on docs-only), or "always"
TDD_COMPILE_FAIL_RE=""   # optional ERE over a test's failing output on the base that means "did not compile", e.g.
                         # "Cannot find module|cannot find .* in scope|error TS2305". A match is labelled
                         # compile-only red and needs "TDD: compile-red — <reason>" in decisions.md
PREPUSH_LANES=""         # optional: pre-push runs its independent checks at the same time, in lanes; a lane's
                         # checks run in turn. Default lanes: lint, build (typecheck → unit → seeds: they often
                         # share build output), site (site-lint, site-typecheck, site-unit), repo (cross-reads,
                         # doc-map, decision-log, guards, file-size, roadmap, stories). Checks that write nothing in
                         # common can be split out, e.g. "typecheck=typecheck" when typecheck writes no build
                         # output unit reads; "*=serial" runs every check in one lane, one at a time.
                         # diff-coverage, coverage-baseline, tdd and local checks always run after, in turn
LOCK_WAIT_MAX=1800       # seconds any one wait for another gate's lock may last before this gate fails, naming
                         # the lock and its holder (a lock that never frees fails instead of hanging)

# Space-separated globs; * also matches "/".
SRC_GLOBS="src/* app/* apps/* packages/* lib/*"
TEST_GLOBS="*.test.* *.spec.* *_test.* */__tests__/* tests/* test/* e2e/*"
DEPS_LINKS="node_modules"        # paths symlinked into the TDD scratch checkout so tests can run there (nested ok: site/node_modules)
FILE_SIZE_GLOBS="*.ts *.tsx *.js *.jsx *.mjs *.py *.go *.rb *.php"
MAX_FILE_LINES=400
# UI evidence lives on the PR, not in git. UI_GLOBS (empty = off): files whose change needs a
# screenshot in the PR body, e.g. "web/* src/components/* *.css" — bin/ship refuses the PR
# without one. EVIDENCE_MAX_KB: a new image under docs/work/ larger than this fails pre-push.
UI_GLOBS=""
EVIDENCE_MAX_KB=300
# EVIDENCE_CMD (with UI_GLOBS): the repo's one script that captures the standard evidence set — each
# supported viewport in each theme — from a running app into a new temp dir, and prints the files,
# one per line, last; non-zero on any failure. Agents run it for stage 8 instead of improvising
# captures; bin/ship's screenshot miss names it. Start from the skill's
# templates/evidence-capture.example.sh, or wrap the repo's own (e.g. an e2e layout script).
EVIDENCE_CMD=""

# --- Change class (optional): which checks a branch needs, from every path it touches ---
# Off while SITE_GLOBS and DOCS_GLOBS are both empty: every check runs on every branch. Set them
# so a docs-only or site-only branch skips the app's checks (and a docs-only one the site's).
# change_class in .standards/lib/common.sh reads these; first match wins, in this order:
#   SHARED_GLOBS  read by both sides' checks (a test reads it from the other side): class "all"
#   APP_GLOBS     always app, even a doc inside them (e.g. the gate files: ".standards/* bin/*")
#   SITE_GLOBS    the second half of the repo: alone (docs aside), only the site's checks run
#   DOCS_GLOBS    docs: alone, neither side's checks run; with others, neutral
#   anything else is app. Mixed app and site, no file, or a failed file list: "all".
# Repo-standards checks (TDD, doc map, decision log, file size, roadmap, cross-reads) run on every class.
SHARED_GLOBS=""
APP_GLOBS=""
SITE_GLOBS=""            # e.g. "site/* scripts/deploy-site.sh"
DOCS_GLOBS=""            # e.g. "docs/* *.md"
BEHAVIOR_DOCS_GLOBS=""   # optional: markdown that drives behaviour (runtime prompts, agent commands), e.g.
                         # "prompts/*". Never docs-only: a branch touching it needs the spec and plan gates
# cross-reads.sh: a skipped check must not read a changed file. Tracked files (git pathspecs)
# whose quoted path literals are classed: the app side's tests must not read site or docs files,
# the site side's must not read docs files, unless those paths are in SHARED_GLOBS. Empty = unchecked.
CROSS_READS_APP_FILES=""   # e.g. "Tests/*.swift"
CROSS_READS_SITE_FILES=""  # e.g. "site/*.ts site/*.mjs"

# --- bin/ship (pre-merge) ---
E2E_CMD=""
SITE_E2E_CMD=""          # optional; with change classes on, runs only when the site changed
PERF_CMD=""              # must exit non-zero when a budget from a spec's Expectations is exceeded. Runs alone: after
                         # e2e, holding a machine-wide "timed" lock, once no other gate (any worktree's pre-push
                         # or bin/ship) is running checks; gates that start meanwhile wait for it
PERF_PREP_CMD=""         # optional: perf's untimed half (builds, fixture generation, accuracy), run beside E2E_CMD.
                         # Must measure no time and be safe beside e2e. Set, PERF_CMD holds only the timed half
                         # and runs only when this passed
E2E_EXCLUSIVE=""         # "1": e2e cannot run twice at once on this machine (a fixed port, one simulator):
                         # bin/ship holds this repo's e2e lock while it runs, across worktrees
VERDICT_REUSE=""         # "1": a bin/ship re-run on exactly the same input (every tracked file but the issue's
                         # decisions.md, untracked files, the base, the commands, OS, VERDICT_KEY_CMD's output;
                         # under a day) reuses the last e2e + perf PASS; any failure on that input voids it.
                         # STANDARDS_RERUN=1 bin/ship runs them anyway. Records live in .git/standards-verdicts/.
                         # Also needed by `bin/ship --checks-only` (its pass is reused only with this on). The installer
                         # turns it on once VERDICT_KEY_CMD and the key's inputs below are set (logged as its call)
VERDICT_KEY_CMD=""       # with VERDICT_REUSE: prints the versions of the tools e2e and perf use, so a tool
                         # change re-runs them, e.g. "node -v && pnpm -v && pnpm exec playwright --version".
                         # Exits non-zero → nothing is reused or recorded
# What the reuse key covers (ship_verdict_key in .standards/lib/ship-checks.sh): every tracked file but the issue's
# decisions.md, untracked unignored files, uncommitted edits, the base, the e2e/perf commands, OS, tool versions,
# and the three below. It does NOT cover anything else outside git: other gitignored files and build output,
# environment variables not named here, running services, databases, the network, the clock. A test that reads one
# of those can pass on reuse and fail on a real run: name it below, or leave reuse off (the default).
VERDICT_IGNORED_GLOBS=".env*" # gitignored files hashed into the key (a glob without "/" matches at any depth)
VERDICT_ENV=""           # environment variables whose values e2e/perf read, e.g. "NODE_ENV API_URL"; their values go
                         # into the key (hashed, never stored in clear), set or unset
VERDICT_DEPS_MARKERS="node_modules/.modules.yaml node_modules/.package-lock.json node_modules/.yarn-state.yml node_modules/.yarn-integrity"
                         # files a package manager rewrites on every install: content + mtime in the key, with every
                         # known lockfile present (pnpm-lock.yaml, package-lock.json, yarn.lock, Cargo.lock, …)
VERDICT_DEPS_CMD=""      # optional: prints the installed-dependency state for other stacks (e.g. "pip freeze");
                         # must exit 0, else nothing is reused or recorded
MERGE_MODE="squash"      # how bin/ship merges: squash | merge (keeps step-split commits) | rebase
COVERAGE_RATCHET_SLACK=2 # bin/ship fails when total coverage is more than this many points above
                         # .standards/coverage-baseline, and prints the one-line raise
# Deploy (optional; empty = bin/ship stops at the merge). Once the PR is merged, bin/ship runs both
# from a fresh detached checkout of origin/BASE_BRANCH in a temp dir (cwd and $ROOT point at it),
# using the values in the base's copy of this file: an unmerged edit here deploys nothing.
DEPLOY_CMD=""            # e.g. "pnpm install --frozen-lockfile && pnpm run deploy"
LIVE_CHECK_CMD=""        # required with DEPLOY_CMD: exits non-zero when production does not serve this
                         # build (e.g. the live asset name differs from dist/index.html). Read-only,
                         # or a capped few requests

# --- intake ---
AGENT_ISSUES_PER_NIGHT=1
