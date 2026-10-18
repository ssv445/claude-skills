
# --- appended by tests/run.sh's speed cases (tests/parallel-fixtures/config-speed.sh) ---
# Every command is a copy of fake.sh; T_* environment variables let a case change one setting
# without rewriting this file.
LINT_CMD="scripts/lint.sh"
TYPECHECK_CMD="scripts/typecheck.sh"
UNIT_CMD="scripts/unit.sh"
SITE_UNIT_CMD="scripts/site-unit.sh"
DIFF_COVERAGE_CMD="scripts/diff-cover.sh"
E2E_CMD="scripts/e2e.sh"
PERF_PREP_CMD="${T_PREP-scripts/perf.sh prep}"
PERF_CMD="${T_PERF-scripts/perf.sh measure}"
E2E_EXCLUSIVE="${T_E2E_EXCLUSIVE-}"
VERDICT_REUSE="${T_REUSE-1}"
VERDICT_KEY_CMD="${T_KEY_CMD-scripts/version.sh}"
PREPUSH_LANES="${T_LANES-}"
VERDICT_ENV="${T_VERDICT_ENV-MODE}"
VERDICT_DEPS_CMD="${T_DEPS_CMD-}"
LOCK_WAIT_MAX="${T_LOCK_WAIT_MAX-1800}"
UI_GLOBS="${T_UI_GLOBS-}"
EVIDENCE_CMD="${T_EVIDENCE_CMD-}"
