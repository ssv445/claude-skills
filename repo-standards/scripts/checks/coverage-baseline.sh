#!/usr/bin/env bash
# Total coverage may only ratchet up: compare COVERAGE_TOTAL_CMD's number to
# .standards/coverage-baseline (no file = 0). Raise the baseline in the PR when coverage
# rises — one number, nothing else: agent-approval.sh lets only that edit through without the owner.
# --ratchet (bin/ship): also fail when the total is more than COVERAGE_RATCHET_SLACK points
# above the baseline, so the baseline cannot sit at 0 while coverage is 98.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

[ -n "$COVERAGE_TOTAL_CMD" ] || { info "SKIP coverage-baseline (N/A in config)"; exit 0; }
# The total measures the app, which a site or docs change cannot move.
class="$(change_class)"
checks_for app "$class" || { info "SKIP coverage-baseline (change class $class: not needed)"; exit 0; }
baseline_file=".standards/coverage-baseline"
baseline="$(cat "$baseline_file" 2>/dev/null)"; baseline="${baseline:-0}"
total="$(eval "$COVERAGE_TOTAL_CMD" | tail -1 | tr -d '%[:space:]')"
info "coverage-baseline: total $total vs baseline $baseline"
if ! awk -v t="$total" -v b="$baseline" 'BEGIN { exit !(t+0 >= b+0 && t != "") }'; then
  red "FAIL coverage-baseline: total coverage ${total:-unknown} is below baseline $baseline"; exit 1
fi
# The suggested baseline is the total rounded down to a whole number, so a run-to-run
# wobble under one point does not fail the next push.
new="$(awk -v t="$total" 'BEGIN { printf "%d", t }')"
slack="${COVERAGE_RATCHET_SLACK:-2}"
edit="set $baseline_file to $new (the file holds that one number and nothing else)"
if [ "${1:-}" = "--ratchet" ] && awk -v t="$total" -v b="$baseline" -v s="$slack" 'BEGIN { exit !(t - b > s) }'; then
  red "FAIL coverage-ratchet: total $total is more than $slack points above baseline $baseline — in this PR, $edit"; exit 1
fi
if awk -v n="$new" -v b="$baseline" 'BEGIN { exit !(n + 0 > b + 0) }'; then info "coverage-baseline: raise it: $edit"; fi
green "PASS coverage-baseline"
