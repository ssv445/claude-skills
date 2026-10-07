#!/usr/bin/env bash
# Total coverage may only ratchet up: compare COVERAGE_TOTAL_CMD's number to
# .standards/coverage-baseline. Raise the baseline in the PR when coverage rises.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

[ -n "$COVERAGE_TOTAL_CMD" ] || { info "SKIP coverage-baseline (N/A in config)"; exit 0; }
baseline_file=".standards/coverage-baseline"
baseline="$(cat "$baseline_file" 2>/dev/null)"; baseline="${baseline:-0}"
total="$(eval "$COVERAGE_TOTAL_CMD" | tail -1 | tr -d '%[:space:]')"
info "coverage-baseline: total $total vs baseline $baseline"
if awk -v t="$total" -v b="$baseline" 'BEGIN { exit !(t+0 >= b+0 && t != "") }'; then
  green "PASS coverage-baseline"
else
  red "FAIL coverage-baseline: total coverage ${total:-unknown} is below baseline $baseline"; exit 1
fi
