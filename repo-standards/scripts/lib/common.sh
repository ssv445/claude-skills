#!/usr/bin/env bash
# Shared helpers for .standards/ scripts. Bash 3.2 compatible (macOS default): no
# associative arrays, no mapfile.

ROOT="$(git rev-parse --show-toplevel)" || exit 1
cd "$ROOT" || exit 1
# shellcheck source=/dev/null
. "$ROOT/.standards/config.sh"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
info()  { printf '  %s\n' "$*"; }

# Base commit the branch is compared against: the merge-base with the remote base
# branch when it exists, else the local one.
base_commit() {
  git merge-base "origin/$BASE_BRANCH" HEAD 2>/dev/null || git merge-base "$BASE_BRANCH" HEAD
}

# approver_mode: APPROVER from the base's config.sh — "agent" only if it says so, else
# "owner". Read from the base, not the working copy, so a branch cannot switch the mode
# that judges it.
approver_mode() {
  local b m
  b="$(base_commit)"; [ -n "$b" ] || { echo owner; return; }
  m="$(git show "$b:.standards/config.sh" 2>/dev/null | sed -n 's/^APPROVER="\([a-z]*\)".*/\1/p' | tail -1)"
  [ "$m" = agent ] && echo agent || echo owner
}

# Files added/copied/modified/renamed on this branch, one per line, unquoted: -z keeps
# git from C-quoting non-ASCII names ("caf\303\251"), which would never match a glob.
changed_files() {
  git -c core.quotePath=false diff -z --name-only --diff-filter=ACMR "$(base_commit)" HEAD | tr '\0' '\n'
}

# Every path the branch touches, one per line: added, modified, deleted, and both sides of a
# rename (--no-renames). changed_files leaves out deletions; the change class must not, or a
# branch deleting a source file would look like it changed no source file.
touched_files() {
  git -c core.quotePath=false diff -z --name-only --no-renames "$(base_commit)" HEAD | tr '\0' '\n'
}

# --- change class: which checks a branch needs. Path lists: SHARED/APP/SITE/DOCS_GLOBS in config.sh.
# Off (the class is always "all") until SITE_GLOBS or DOCS_GLOBS is set, so a repo that sets
# nothing runs every check on every branch.

# file_part <file>: shared | app | site | docs; the first list that matches, else app.
file_part() {
  if matches_any "$1" "$SHARED_GLOBS"; then echo shared
  elif matches_any "$1" "$APP_GLOBS"; then echo app
  elif matches_any "$1" "$SITE_GLOBS"; then echo site
  elif matches_any "$1" "$DOCS_GLOBS"; then echo docs
  else echo app; fi
}

# change_class: the class of the whole branch.
#   docs  only docs files: neither the app's nor the site's checks
#   site  site files, docs aside: the site's checks only
#   app   app files, docs aside: every check (the site's ship-time checks only when the site changes)
#   all   app and site files, a shared file, no file, or the list failed: every check
# Fails closed: anything it cannot tell is "all".
change_class() {
  local files f app="" site=""
  [ -n "$SITE_GLOBS$DOCS_GLOBS" ] || { echo all; return; }
  files="$(set -o pipefail; touched_files)" && [ -n "$files" ] || { echo all; return; }
  while IFS= read -r f; do
    case "$(file_part "$f")" in
      shared) echo all; return ;;
      app) app=1 ;;
      site) site=1 ;;
    esac
  done <<<"$files"
  if [ -n "$app" ] && [ -n "$site" ]; then echo all
  elif [ -n "$app" ]; then echo app
  elif [ -n "$site" ]; then echo site
  else echo docs; fi
}

# checks_for <part> [class]: whether a group of checks runs for the class (default: change_class).
#   app          the app's lint, typecheck, tests, coverage, e2e and perf
#   site         the site's lint, typecheck and tests at pre-push (an app change still runs them:
#                the site's tests may read app files)
#   site-change  the site's coverage report and ship-time checks (SITE_E2E_CMD): only when the
#                site changed
# Fails closed: an unknown part or class runs.
checks_for() {
  local c="${2:-$(change_class)}"
  case "$1:$c" in
    app:docs | app:site | site:docs | site-change:docs | site-change:app) return 1 ;;
  esac
  return 0
}

# class_report [class]: one line naming the class and what it skips, so a skip is never silent.
class_report() {
  local c="${1:-$(change_class)}"
  case "$c" in
    docs) info "change class: docs — only docs changed; skipping the app's and the site's checks" ;;
    site) info "change class: site — only the site (and docs) changed; skipping the app's checks" ;;
    app) info "change class: app — every check runs (the site's ship-time checks only when the site changes)" ;;
    *) info "change class: $c — every check runs" ;;
  esac
}

# run_part <label> <part> <command>: run_cmd when checks_for <part>, else a visible SKIP.
run_part() {
  local c
  c="$(change_class)"
  if checks_for "$2" "$c"; then run_cmd "$1" "$3"; else info "SKIP $1 (change class $c: not needed)"; fi
}

# matches_any <file> <space-separated globs>. Globs are matched with [[ == ]], where
# * also matches "/", so "src/*" covers every depth under src/.
matches_any() {
  local f="$1" g
  set -f
  for g in $2; do
    # shellcheck disable=SC2053
    if [[ "$f" == $g ]]; then set +f; return 0; fi
  done
  set +f
  return 1
}

# Issue number from a branch named <type>/<issue>-<slug>.
issue_number() {
  git rev-parse --abbrev-ref HEAD | sed -n 's#^[a-z]*/\([0-9][0-9]*\)-.*#\1#p'
}

# docs/work/<issue>-<slug>/ for the current branch, or empty.
# issue_dirs: every docs/work/<issue>-*/ for the current branch, one per line. Flags are read
# across all of them, so a second folder for the same issue cannot hide one.
issue_dirs() {
  local n d
  n="$(issue_number)"
  [ -n "$n" ] || return 0
  for d in docs/work/"$n"-*/; do
    [ -d "$d" ] && printf '%s\n' "${d%/}"
  done
}

# issue_dir: the one docs/work/<issue>-<slug>/ for the current branch, or empty. Fails closed
# when more than one folder matches the issue: which decisions.md counts would be a guess,
# so none does, and the folders are named on stderr.
issue_dir() {
  local ds
  ds="$(issue_dirs)"
  [ -n "$ds" ] || return 0
  if [ "$(printf '%s\n' "$ds" | wc -l)" -gt 1 ]; then
    red "  miss more than one folder for issue #$(issue_number): $(printf '%s' "$ds" | tr '\n' ' ')— keep one" >&2
    return 1
  fi
  printf '%s\n' "$ds"
}

decisions_file() {
  local d
  d="$(issue_dir)"
  [ -n "$d" ] && printf '%s/decisions.md\n' "$d"
}

# section_verdict <file> <section heading text> → prints the Verdict value, or nothing.
section_verdict() {
  awk -v h="## $2" '
    $0 == h { inside = 1; next }
    inside && /^## / { inside = 0 }
    inside && /^Verdict:/ { sub(/^Verdict:[ \t]*/, ""); print; exit }
  ' "$1"
}

# section_field <file> <section heading text> <line prefix> → prints what follows the
# first line in that section starting with the prefix, e.g. "- Reviewer A:".
section_field() {
  awk -v h="## $2" -v p="$3" '
    $0 == h { inside = 1; next }
    inside && /^## / { inside = 0 }
    inside && index($0, p) == 1 { s = substr($0, length(p) + 1); sub(/^[ \t]*/, "", s); print s; exit }
  ' "$1"
}

# owner_flag_re <review|approval>: anchored ERE (use with grep -i) for an owner flag line.
# Fails closed: any line naming the flag with "required" later on it counts, whatever the
# markdown around it — except lines indented 4+ spaces or a tab (the templates' examples).
# For approval, "required" must come before any "#" comment and not as "not-required", so
# the spec template's default "owner-approval: not-required   # required if: …" is no flag.
owner_flag_re() {
  case "$1" in
    review)   printf '^ {0,3}([^ \t].*)?owner-review.*required' ;;
    approval) printf '^ {0,3}([^ \t].*)?owner-approval([^#]*[^#-])?required' ;;
  esac
}

# owner_answered_re: anchored ERE (use with grep -i) for a closed owner-review flag:
#   owner-review: answered — <reason as in the flag> — <link to the owner's answer> — <the answer, quoted>
# The reason pairs the answer with the flag it closes; the link must be a real URL and the
# answer real text: a "<placeholder>" in any field does not count. An agent writes it in
# place of the flag once the owner has answered, so an answered question needs no
# bin/approve. It checks the shape only: agents post as the owner, so who wrote the answer
# cannot be proven here (the gates are a speed bump for honest agents).
owner_answered_re() {
  printf '^ {0,3}([-*] +)?owner-review: answered (—|-) [^ <].* (—|-) https?://[^ <>]+ (—|-) [^ <]'
}

# owner_answered_lines <file|->: the answered flags in it. A line naming owner-review twice
# is not one (it could hide an open flag behind a closed one).
owner_answered_lines() {
  grep -iE "$(owner_answered_re)" "$1" | grep -viE 'owner-review.*owner-review'
}

# owner_reason: stdin flag or answered lines → each one's reason, lower-cased and trimmed,
# one per line, so a flag and its answer compare equal. Flag: the line without its
# "owner-review: required" token and the separators around it. Answered: the text between
# "answered —" and "— <link>". A reason with no letter or digit is no reason: callers drop it.
owner_reason() {
  awk '{
    l = tolower($0)
    if (match(l, /owner-review: answered (—|-) /)) {
      r = substr(l, RSTART + RLENGTH)
      if (match(r, / (—|-) https?:\/\//)) r = substr(r, 1, RSTART - 1)
    } else if (match(l, /[*_]*owner-review[*_]*:?[*_ \t]*required[*_]*/)) {
      # The text on either side of the flag token, separators dropped: "Price — owner-review:
      # required" and "owner-review: required — price" both give "price".
      a = substr(l, 1, RSTART - 1); b = substr(l, RSTART + RLENGTH)
      sub(/^[ \t]*([-*][ \t]+)?/, "", a); sub(/[ \t]*(—|-|:)?[ \t]*$/, "", a)
      sub(/^[ \t:]*(—|-)?[ \t]*/, "", b)
      r = (a != "" && b != "") ? a " " b : a b
    } else r = l
    sub(/^[ \t]+/, "", r); sub(/[ \t]+$/, "", r)
    print r
  }'
}

# owner_flags <file>: the file's open owner-review flags, "<line>:<text>", or nothing. An
# answered flag is closed even when the quoted answer says "required".
owner_flags() {
  local l
  [ -f "$1" ] || return 0
  grep -inE "$(owner_flag_re review)" "$1" | while IFS= read -r l; do
    [ -n "$(printf '%s\n' "${l#*:}" | owner_answered_lines -)" ] || printf '%s\n' "$l"
  done
}

# docs_only: the branch touches docs and nothing else, so it needs no spec or plan gate.
# No touched file may match SRC_GLOBS, TEST_GLOBS or BEHAVIOR_DOCS_GLOBS (markdown that
# drives behaviour: prompts, agent commands), and no gate file may change — asked of
# agent-approval.sh --gate-files, the one gate-file detection. With DOCS_GLOBS set, the
# change class must be docs (no app, site or shared file). Without it, every touched file
# must be prose (DOCS_ONLY_DEFAULT_GLOBS): a package.json or requirements.txt is not docs.
# Fails closed: no file, a list git cannot produce, or a failed gate-file list is not docs-only.
DOCS_ONLY_DEFAULT_GLOBS="*.md *.mdx *.markdown *.rst *.adoc"
docs_only() {
  local files f gates
  files="$(set -o pipefail; touched_files)" && [ -n "$files" ] || return 1
  while IFS= read -r f; do
    matches_any "$f" "$SRC_GLOBS $TEST_GLOBS ${BEHAVIOR_DOCS_GLOBS:-}" && return 1
    [ -n "$DOCS_GLOBS" ] || matches_any "$f" "$DOCS_ONLY_DEFAULT_GLOBS" || return 1
  done <<<"$files"
  gates="$("$ROOT/.standards/checks/agent-approval.sh" --gate-files 2>/dev/null)" && [ -z "$gates" ] || return 1
  [ -z "$DOCS_GLOBS" ] || [ "$(change_class)" = docs ]
}

# section_count <file> <section heading text> <line prefix> → how many lines in that
# section start with the prefix.
section_count() {
  awk -v h="## $2" -v p="$3" '
    $0 == h { inside = 1; next }
    inside && /^## / { inside = 0 }
    inside && index($0, p) == 1 { n++ }
    END { print n + 0 }
  ' "$1"
}

# run_cmd <label> <command string>. Empty command = N/A in config, reported as SKIP.
run_cmd() {
  local label="$1" cmd="$2" start rc
  if [ -z "$cmd" ]; then info "SKIP $label (N/A in config)"; return 0; fi
  start=$(date +%s)
  info "RUN  $label: $cmd"
  eval "$cmd"
  rc=$?
  if [ $rc -ne 0 ]; then red "FAIL $label (exit $rc)"; return 1; fi
  green "PASS $label ($(( $(date +%s) - start ))s)"
}

# --- deletion: every .standards/ script deletes through safe_rm, never a bare rm. A variable
# that comes out empty or relative must not turn a cleanup into rm -rf of $HOME or /.

# _srm_phys <dir>: sets _srm_phys to the dir's physical absolute path (../ and symlinks
# resolved), or fails when it does not exist. CDPATH off so a relative dir means ./dir; the
# trailing x keeps a name that ends in a newline intact through $( ). pwd -P keeps a leading
# "//" (POSIX leaves it implementation-defined): folded to one "/", or //home would not
# match the /home prefix checks.
_srm_phys() {
  _srm_phys="$(CDPATH='' cd -P -- "$1" 2>/dev/null && pwd -P && echo x)" || return 1
  _srm_phys="${_srm_phys%?x}"
  while :; do case "$_srm_phys" in //*) _srm_phys="${_srm_phys#/}" ;; *) break ;; esac; done  # safe_rm: slashes
}

# _srm_target <path>: sets _srm_target to the physical path safe_rm would remove, or sets
# _srm_why and fails. Only the parent is resolved: a symlink argument names the link, never
# what it points to. Each check is one line tagged "# safe_rm: <name>" so tests/run.sh can
# drop one from a copy and prove its cases notice.
_srm_target() {
  local p="$1" dir base t home top root tmpdir="" holds_home="" roots=()
  [ -n "$p" ] || { _srm_why="empty path"; return 1; }
  while :; do case "$p" in ?*/) p="${p%/}" ;; *) break ;; esac; done
  [ "$p" != / ] || { _srm_why="is /"; return 1; }
  base="${p##*/}"
  case "$p" in */*) dir="${p%/*}"; dir="${dir:-/}" ;; *) dir=. ;; esac
  case "$base" in .|..) _srm_why="ends in . or .. — name the path itself"; return 1 ;; esac
  _srm_phys "$dir" || { _srm_why="parent directory does not exist"; return 1; }
  t="${_srm_phys%/}/$base"
  # $HOME, and anything holding it. No $HOME to compare with: refuse, never guess.
  [ -n "${HOME:-}" ] && _srm_phys "$HOME" || { _srm_why="HOME unset or missing — cannot check"; return 1; }
  home="$_srm_phys"
  [ "$home" != / ] || { _srm_why="HOME is / — cannot check"; return 1; }  # safe_rm: home-root
  case "$home/" in "$t"/*) _srm_why="is \$HOME or holds it"; return 1 ;; esac  # safe_rm: home
  # Temp roots. One that is /, $HOME or holds $HOME is ignored: TMPDIR=$HOME would make all
  # of $HOME deletable. ~/tmp stays a root, for what is strictly inside it. A root holding
  # the repo is kept: /var/folders holds the repos tests build, and the repo root and .git/
  # are refused below either way. A relative TMPDIR would resolve against the cwd: ignored.
  for root in "${TMPDIR:-}" /tmp /private/tmp /var/folders; do
    case "$root" in /*) ;; *) continue ;; esac  # safe_rm: abs-tmpdir
    _srm_phys "$root" || continue
    case "$home/" in "${_srm_phys%/}"/*) continue ;; esac  # safe_rm: tmp-root
    case "$_srm_phys/" in "$t"/*) _srm_why="is a temp root or holds one"; return 1 ;; esac
    [ "$root" != "${TMPDIR:-}" ] || tmpdir="$_srm_phys"
    roots+=("$_srm_phys")
  done
  # The repo: strictly inside, never the root, anything holding it, or .git/. A repo that is
  # $HOME or holds it (dotfiles) is no allowed root: it would make all of $HOME deletable.
  if top="$(git rev-parse --show-toplevel 2>/dev/null)" && _srm_phys "$top"; then
    top="$_srm_phys"
    case "$top/" in "$t"/*) _srm_why="is the repo root or holds it"; return 1 ;; esac
    case "$t/" in "$top/.git/"*) _srm_why="inside .git/"; return 1 ;; esac  # safe_rm: git-dir
    case "$home/" in "$top"/*) holds_home=1 ;; esac  # safe_rm: repo-home
    [ -n "$holds_home" ] || case "$t" in "$top"/*) _srm_target="$t"; return 0 ;; esac
  fi
  # $TMPDIR first: it is the caller's own choice of temp dir, even when it sits under $HOME.
  [ -z "$tmpdir" ] || case "$t" in "$tmpdir"/*) _srm_target="$t"; return 0 ;; esac
  case "$t" in "$home"/*) _srm_why="under \$HOME, outside the repo${holds_home:+ (the repo holds \$HOME, so it is no allowed root)}"; return 1 ;; esac  # safe_rm: home-rule
  for root in "${roots[@]}"; do
    case "$t" in "$root"/*) _srm_target="$t"; return 0 ;; esac
  done
  _srm_why="outside the repo and the temp dirs"; return 1
}

# safe_rm [--check] <path>...: rm -rf each path, but only strictly inside the repo (not .git/)
# or a temp dir ($TMPDIR, /tmp, /var/folders), never $HOME, /, or anything holding them. All
# paths are checked first: one refusal deletes nothing ("refused: <path> — <reason>" on
# stderr, exit 1). A missing path whose parent passes is a no-op. --check: validate only.
safe_rm() {
  local check="" p t bad=0 targets=()
  if [ "${1:-}" = "--check" ]; then check=1; shift; fi
  [ $# -gt 0 ] || { printf 'refused: (no path) — nothing named\n' >&2; return 1; }
  for p in "$@"; do
    if _srm_target "$p"; then targets+=("$_srm_target")
    else printf 'refused: %s — %s\n' "$p" "$_srm_why" >&2; bad=1; fi
  done
  [ $bad -eq 0 ] || return 1
  [ -z "$check" ] || return 0
  for t in "${targets[@]}"; do
    rm -rf -- "$t" || bad=1  # rm-lint: allow (the one rm in .standards/)
  done
  return $bad
}

# drop_worktree <dir>: removes a scratch checkout made with `git worktree add`. The files go
# through safe_rm (a test or deploy run leaves untracked files, which plain `git worktree
# remove` refuses and --force would delete unchecked); then git forgets the missing checkout.
drop_worktree() {
  safe_rm "$1" || return 1
  git worktree remove "$1" >/dev/null 2>&1 || git worktree prune
}
