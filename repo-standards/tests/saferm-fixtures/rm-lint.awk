# rm-lint.awk: prints file:line of every deletion command in shell scripts; exits 1 if any.
# tests/run.sh runs it over scripts/ and itself, so .standards/ deletes only through safe_rm.
# A lint, not a sandbox: it catches the plain and the lazily disguised forms (command rm,
# \rm, /bin/rm, "rm", r''m, $RM / ${RM}, xargs rm, -exec rm, find -delete, unlink, rmdir,
# git clean and git -C <dir> clean, git worktree remove --force, rsync --delete), not
# deletion through perl / python (perl unlink, os.remove), aliases, or strings assembled
# further than simple quote splicing.
# Usage: awk -v allow=<allow file> -f rm-lint.awk <allow file> <file>...
# The allow file holds "<path suffix><TAB><exact line>": that exact line (marker comment
# included) is skipped once per file, and only in a file whose path ends in the suffix.
# `git rm` (tracked files, recoverable) is exempt only as exactly "git rm".
FNR == 1 { inallow = (FILENAME == allow) }
inallow { i = index($0, "\t"); if (i) ok[substr($0, i + 1)] = substr($0, 1, i - 1); next }
/^[[:space:]]*#/ { next }
($0 in ok) && (FILENAME == ok[$0] || substr(FILENAME, length(FILENAME) - length(ok[$0])) == "/" ok[$0]) && !used[FILENAME, $0]++ { next }
{
  # Quotes and backslashes spliced into a word ("rm", r''m, \rm) are dropped first.
  s = " " $0
  gsub(/["'\\]/, "", s)
  while (match(s, /[^A-Za-z0-9_.\/-]git[ \t]+rm[ \t]/)) s = substr(s, 1, RSTART) "git_rm " substr(s, RSTART + RLENGTH)
  # git's own options may sit before the subcommand: git -C <dir> clean, git -c k=v clean.
  g = "[^A-Za-z0-9_.\\/-]git([ \t]+(-[Cc][ \t]+[^ \t;|&]+|--?[A-Za-z][A-Za-z-]*(=[^ \t;|&]*)?))*[ \t]+"
  if (s ~ /[^A-Za-z0-9_.-]rm([ \t;|&)]|$)/ || s ~ /[^A-Za-z0-9_.-](unlink|rmdir)([ \t;|&)]|$)/ \
      || s ~ /[ \t]-delete([ \t;|&)]|$)/ || s ~ /[$][{]?RM([^A-Za-z0-9_]|$)/ \
      || s ~ (g "clean([ \t;|&)]|$)") \
      || s ~ (g "worktree[ \t]+remove([ \t]+[^ \t;|&]+)*[ \t]+(--force|-f+)([ \t;|&)]|$)") \
      || (s ~ /[^A-Za-z0-9_.\/-]rsync[ \t]/ && s ~ /[ \t]--(del|delete[a-z-]*|remove-source-files)([ \t=;|&)]|$)/)) {
    print FILENAME ":" FNR ": " $0; bad = 1
  }
}
END { exit bad }
