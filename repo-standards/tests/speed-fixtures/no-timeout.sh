
# --- appended by tests/run.sh: no CMD_TIMEOUT at all; the unit command checks it runs plainly ---
unset CMD_TIMEOUT
UNIT_CMD='./same-group.sh $$'
