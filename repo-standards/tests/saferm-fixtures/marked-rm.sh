
# Planted by tests/run.sh into a COPY of scripts/: the lint's allow marker outside
# lib/common.sh must not excuse a bare rm. Never run.
rm -f /nonexistent-saferm-lint-probe/y  # rm-lint: allow
