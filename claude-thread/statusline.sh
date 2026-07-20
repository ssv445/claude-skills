#!/bin/bash
# statusline.sh — Claude Code statusline hook. Reads the session JSON on stdin
# and prints a two-line status bar: model / project / git on line 1, context
# usage / cost / duration / diff on line 2.
#
# Install (~/.claude/settings.json):
#   "statusLine": { "type": "command",
#     "command": "/Users/<you>/.local/bin/statusline" }
#
# Self-contained: no env.sh, no tmux, no wormhole server. Requires jq.
# Modernized from claude-wormhole's `wormhole statusline`.

command -v jq >/dev/null 2>&1 || { echo "[statusline] jq not found"; exit 0; }

# ── colors ──
if [ -t 1 ] || [ "${STATUSLINE_FORCE_COLOR:-1}" = "1" ]; then
  NC=$'\033[0m'; DIM=$'\033[2m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  CYAN=$'\033[36m'; MAGENTA=$'\033[35m'
else
  NC=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; MAGENTA=""
fi

input=$(cat)

# One jq pass, tab-separated, null-safe.
IFS=$'\t' read -r model dir pct cost duration_ms added removed < <(
  printf '%s' "$input" | jq -r '
    [ (.model.display_name // "?"),
      (.workspace.current_dir // ""),
      ((.context_window.used_percentage // 0) | floor),
      (.cost.total_cost_usd // 0),
      (.cost.total_duration_ms // 0),
      (.cost.total_lines_added // 0),
      (.cost.total_lines_removed // 0)
    ] | @tsv'
)
dir_name="${dir##*/}"
[[ "$pct" =~ ^[0-9]+$ ]] || pct=0

# ── git info (cached 5s per dir; git calls are the slow part) ──
cache_key=$(printf '%s' "$dir" | { md5sum 2>/dev/null || md5 2>/dev/null; } | cut -d' ' -f1)
cache_file="/tmp/statusline-git-${cache_key:-default}"
cache_max_age=5

_stale() {
  [ ! -f "$cache_file" ] || \
  [ $(( $(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0) )) -gt "$cache_max_age" ]
}

if _stale; then
  branch=""; staged=0; modified=0; worktree=""
  if [ -n "$dir" ] && cd "$dir" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    [ -z "$branch" ] && branch=$(git rev-parse --short HEAD 2>/dev/null)
    [ ${#branch} -gt 20 ] && branch="${branch:0:17}..."
    staged=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    modified=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    # worktree name: git-dir != common-dir means we're in a linked worktree.
    # Zed nests as <base>/<wt-name>/<repo-dir>, so prefer the parent dir name
    # when the toplevel basename is just the repo name (matches claude-thread).
    gd=$(git rev-parse --git-dir 2>/dev/null)
    gcd=$(git rev-parse --git-common-dir 2>/dev/null)
    if [ "$gd" != "$gcd" ]; then
      top=$(git rev-parse --show-toplevel 2>/dev/null)
      main=$(dirname "$(dirname "$gcd")")
      if [ "$(basename "$top")" = "$(basename "$main")" ]; then
        worktree=$(basename "$(dirname "$top")")
      else
        worktree=$(basename "$top")
      fi
    fi
  fi
  printf '%s\t%s\t%s\t%s\n' "$branch" "$staged" "$modified" "$worktree" > "$cache_file"
fi
IFS=$'\t' read -r branch staged modified worktree < "$cache_file"

# ── line 1: model, project, worktree, git ──
line1="${CYAN}[${model}]${NC} ${dir_name}"
[ -n "$worktree" ] && line1="${line1} ${MAGENTA}⊕${worktree}${NC}"
if [ -n "$branch" ]; then
  git_info=" | ${DIM}${branch}${NC}"
  [ "${staged:-0}" -gt 0 ]   && git_info="${git_info} ${GREEN}+${staged}${NC}"
  [ "${modified:-0}" -gt 0 ] && git_info="${git_info} ${YELLOW}~${modified}${NC}"
  line1="${line1}${git_info}"
fi

# ── line 2: context bar, cost, duration, diff ──
if   [ "$pct" -ge 90 ]; then bar_color="$RED"
elif [ "$pct" -ge 70 ]; then bar_color="$YELLOW"
else bar_color="$GREEN"; fi

bar_width=10
filled=$((pct * bar_width / 100))
empty=$((bar_width - filled))
bar=""
[ "$filled" -gt 0 ] && bar=$(printf "%${filled}s" | tr ' ' '█')
[ "$empty"  -gt 0 ] && bar="${bar}$(printf "%${empty}s" | tr ' ' '░')"

cost_fmt=$(printf '$%.2f' "$cost")
duration_sec=$((duration_ms / 1000))
line2="${bar_color}${bar}${NC} ${pct}% | ${YELLOW}${cost_fmt}${NC} | ${DIM}$((duration_sec/60))m $((duration_sec%60))s${NC}"
if [ "${added:-0}" -gt 0 ] || [ "${removed:-0}" -gt 0 ]; then
  line2="${line2} | ${GREEN}+${added}${NC}/${RED}-${removed}${NC}"
fi

printf '%b\n%b\n' "$line1" "$line2"
