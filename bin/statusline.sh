#!/bin/bash
# statusline.sh — Claude Code statusline hook. Reads the session JSON on stdin
# and prints a status bar: model / project / git on line 1, context usage /
# cost / duration / diff on line 2, and quota / claude start time / running vs
# installed version on line 3 (omitted when none of those are known).
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

# ── quota cache for `cld quota` ──
# rate_limits arrives only for claude.ai subscribers, after a session's first
# reply. Cache it per account (CLAUDE_CONFIG_DIR tells profiles from main) so
# agents can route heavy work to the account with headroom. Percentages and
# reset times only; tmp + mv so parallel sessions never leave a torn file.
usage_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if rl=$(printf '%s' "$input" | jq -ce 'select(.rate_limits) |
      {updated_at: (now | floor), seven_day: .rate_limits.seven_day}' 2>/dev/null) && [ -d "$usage_dir" ]; then
  printf '%s\n' "$rl" > "$usage_dir/usage.json.$$" \
    && mv -f "$usage_dir/usage.json.$$" "$usage_dir/usage.json"
fi

# One jq pass, tab-separated, null-safe. Missing values become "-", never "":
# tab is IFS whitespace, so read would collapse an empty field and shift the rest.
IFS=$'\t' read -r model dir pct cost duration_ms added removed \
    session_id run_ver q5_pct q5_reset q7_pct q7_reset < <(
  printf '%s' "$input" | jq -r '
    [ (.model.display_name // "?"),
      (.workspace.current_dir // "-"),
      ((.context_window.used_percentage // 0) | floor),
      (.cost.total_cost_usd // 0),
      (.cost.total_duration_ms // 0),
      (.cost.total_lines_added // 0),
      (.cost.total_lines_removed // 0),
      (.session_id // "-"),
      (.version // "-"),
      ((.rate_limits.five_hour.used_percentage // "-") | if type == "number" then floor else . end),
      (.rate_limits.five_hour.resets_at // "-"),
      ((.rate_limits.seven_day.used_percentage // "-") | if type == "number" then floor else . end),
      (.rate_limits.seven_day.resets_at // "-")
    ] | map(tostring) | @tsv'
)
[ "$dir" = "-" ] && dir=""
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

# ── line 3: quota, claude start time, running vs installed version ──
_pct_color() {
  if   [ "$1" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$1" -ge 70 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}
# $1 pct, $2 reset epoch, $3 label, $4 date format for the reset time
_quota() {
  [[ "$1" =~ ^[0-9]+$ ]] || return
  local out="$3 $(_pct_color "$1")$1%${NC}"
  [[ "$2" =~ ^[0-9]+$ ]] && out="${out} ${DIM}↻$(date -r "$2" "$4" 2>/dev/null)${NC}"
  printf '%s' "$out"
}
q5=$(_quota "$q5_pct" "$q5_reset" 5h '+%H:%M')
q7=$(_quota "$q7_pct" "$q7_reset" 7d '+%a %H:%M')
quota=""
[ -n "$q5" ] && quota="$q5"
[ -n "$q7" ] && quota="${quota:+$quota · }$q7"

# Start time of the claude process that spawned us. Walk up a few parents in
# case a shell sits between us; cache per session (it never changes).
start_cache="/tmp/statusline-start-${session_id}"
if [ "$session_id" != "-" ] && [ -s "$start_cache" ]; then
  started=$(cat "$start_cache")
else
  started=""; p=$PPID
  for _ in 1 2 3 4; do
    [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null || break
    if [ "$(ps -o comm= -p "$p" 2>/dev/null | xargs basename 2>/dev/null)" = "claude" ]; then
      lstart=$(ps -o lstart= -p "$p" 2>/dev/null)
      started=$(date -j -f '%a %b %d %T %Y' "$lstart" '+%d %b %H:%M' 2>/dev/null)
      break
    fi
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done
  [ -n "$started" ] && [ "$session_id" != "-" ] && printf '%s' "$started" > "$start_cache"
fi

# Installed = what `claude` launches now (native installer symlinks the newest
# version). Running = this session's version, from the statusline input.
inst_ver=$(readlink "$HOME/.local/bin/claude" 2>/dev/null); inst_ver="${inst_ver##*/}"
ver=""
if [ "$run_ver" != "-" ]; then
  ver="v${run_ver}"
  [ -n "$inst_ver" ] && [ "$inst_ver" != "$run_ver" ] && ver="${YELLOW}v${run_ver} → ${inst_ver} installed${NC}"
fi

line3=""
for part in "$quota" "${started:+started $started}" "$ver"; do
  [ -n "$part" ] && line3="${line3:+$line3 | }$part"
done

if [ -n "$line3" ]; then
  printf '%b\n%b\n%b\n' "$line1" "$line2" "$line3"
else
  printf '%b\n%b\n' "$line1" "$line2"
fi
