#!/usr/bin/env bash
# Total coverage may only ratchet up: compare COVERAGE_TOTAL_CMD's number to
# .standards/coverage-baseline (no file = 0). Raise the baseline in the PR when coverage
# rises — one number, nothing else: agent-approval.sh lets only that edit through without the owner.
# --ratchet (bin/ship): also fail when the total is more than COVERAGE_RATCHET_SLACK points
# above the baseline, so the baseline cannot sit at 0 while coverage is 98. Both modes skip
# on a branch whose change class does not touch the app (a docs PR is not blocked by drift).
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

[ -n "$COVERAGE_TOTAL_CMD" ] || { info "SKIP coverage-baseline (N/A in config)"; exit 0; }
# The total measures the app, which a site or docs change cannot move.
class="$(change_class)"
checks_for app "$class" || { info "SKIP coverage-baseline (change class $class: not needed)"; exit 0; }
baseline_file=".standards/coverage-baseline"
baseline="$(cat "$baseline_file" 2>/dev/null)"; baseline="${baseline:-0}"
# The total is the last line of the output, a bare number (a "%" allowed). A failing command
# or anything else fails: junk read as 0 would pass against a missing baseline (0 ≥ 0).
out="$(eval "$COVERAGE_TOTAL_CMD")"; rc=$?
last="$(printf '%s\n' "$out" | tail -1)"
total="$(printf '%s' "$last" | tr -d '%[:space:]')"
if [ $rc -ne 0 ]; then red "FAIL coverage-baseline: COVERAGE_TOTAL_CMD exited $rc (last line: '$last') — fix the command in .standards/config.sh"; exit 1; fi
if ! printf '%s\n' "$total" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
  red "FAIL coverage-baseline: COVERAGE_TOTAL_CMD printed '$last' as its last line, not a number — make it print the total (e.g. 87.4) last"; exit 1
fi
info "coverage-baseline: total $total vs baseline $baseline"
if ! awk -v t="$total" -v b="$baseline" 'BEGIN { exit !(t + 0 >= b + 0) }'; then
  red "FAIL coverage-baseline: total coverage $total is below baseline $baseline"; exit 1
fi
# The suggested baseline is one point under the total rounded down (never below 0), so a
# run-to-run wobble under one point never fails the next push: 85.05 suggests 84, and a
# rerun at 84.95 still passes.
new="$(awk -v t="$total" 'BEGIN { n = int(t) - 1; printf "%d", (n < 0 ? 0 : n) }')"
slack="${COVERAGE_RATCHET_SLACK:-2}"
edit="set $baseline_file to $new (the file holds that one number and nothing else)"
if [ "${1:-}" = "--ratchet" ] && awk -v t="$total" -v b="$baseline" -v s="$slack" 'BEGIN { exit !(t - b > s) }'; then
  red "FAIL coverage-ratchet: total $total is more than $slack points above baseline $baseline — in this PR, $edit"; exit 1
fi
if awk -v n="$new" -v b="$baseline" 'BEGIN { exit !(n + 0 > b + 0) }'; then info "coverage-baseline: raise it: $edit"; fi
green "PASS coverage-baseline"
