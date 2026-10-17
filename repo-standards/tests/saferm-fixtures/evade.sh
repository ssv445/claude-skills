#!/usr/bin/env bash
# DATA ONLY: planted by tests/run.sh into a COPY of scripts/. Never run. Every line starting
# with L is a deletion the rm lint must flag; the paths are nonexistent scratch names.
L01=1; command rm -f /nonexistent-lint-probe/a
L02=1; \rm -f /nonexistent-lint-probe/b
L03=1; /bin/rm -f /nonexistent-lint-probe/c
L04=1; printf '%s\n' /nonexistent-lint-probe/d | xargs rm -f
L05=1; find /nonexistent-lint-probe -delete
L06=1; RM=rm; $RM -f /nonexistent-lint-probe/f
L07=1; ${RM} -f /nonexistent-lint-probe/f2
L08=1; "rm" -f /nonexistent-lint-probe/g
L09=1; r''m -f /nonexistent-lint-probe/h
L10=1; legit rm -rf /nonexistent-lint-probe/i
L11=1; git clean -fdx /nonexistent-lint-probe/j
L12=1; unlink /nonexistent-lint-probe/k
L13=1; rmdir /nonexistent-lint-probe/l
L14=1; find /nonexistent-lint-probe -exec rm {} +
L15=1; printf '%s\n' /nonexistent-lint-probe/n | xargs rm
L16=1; rm	-f /nonexistent-lint-probe/q
L17=1; eval "r""m -f /nonexistent-lint-probe/r"
L18=1; x=$(rm -f /nonexistent-lint-probe/s)
L19=1; git rm -q x; rm -f /nonexistent-lint-probe/t
L20=1; git -C /nonexistent-lint-probe clean -fdx
L21=1; git -c core.quotePath=false clean -fd /nonexistent-lint-probe/u
L22=1; rsync -a --delete /nonexistent-lint-probe/v/ /nonexistent-lint-probe/w/
L23=1; rsync -a --delete-after --exclude x /nonexistent-lint-probe/v/ /nonexistent-lint-probe/w/
L24=1; rsync -a --remove-source-files /nonexistent-lint-probe/v/ /nonexistent-lint-probe/w/
L25=1; git worktree remove --force /nonexistent-lint-probe/x
L26=1; git -C /nonexistent-lint-probe worktree remove -f /nonexistent-lint-probe/y
