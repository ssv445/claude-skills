#!/usr/bin/env bash
# Roadmap integrity: every item serves an existing goal, every requires/assumption
# reference resolves, no dependency cycles, and nothing is ready/in-progress/shipped
# on top of an unshipped prerequisite. Inbox entries are not checked.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

P="docs/product"
[ -f "$P/roadmap.md" ] || { info "SKIP roadmap (no $P/roadmap.md)"; exit 0; }
for f in goals.md assumptions.md; do [ -f "$P/$f" ] || { red "FAIL roadmap: $P/$f missing"; exit 1; }; done

awk '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function err(m) { print "  " m; bad = 1 }
FILENAME ~ /goals\.md$/       && /^### G-[0-9]+/ { goal[$2] = 1; next }
FILENAME ~ /assumptions\.md$/ && /^### A-[0-9]+/ { assum[$2] = 1; next }
FILENAME ~ /roadmap\.md$/ {
  if (/^## /) { section = $0; cur = ""; next }
  if (section != "## Items") next
  if (/^### /) {
    cur = $2
    if (cur !~ /^R-[0-9]+$/) { err("bad item id \"" cur "\" (want R-<n>)"); cur = ""; next }
    if (cur in seen) err(cur ": duplicate id")
    seen[cur] = 1; ids[++n] = cur; next
  }
  if (cur != "" && /^- [a-z]+:/) {
    key = $2; sub(/:$/, "", key)
    val = $0; sub(/^- [a-z]+:[ \t]*/, "", val)
    f[cur, key] = trim(val)
  }
}
END {
  # capability providers
  for (i = 1; i <= n; i++) {
    id = ids[i]; m = split(f[id, "provides"], ps, ",")
    for (j = 1; j <= m; j++) { c = trim(ps[j]); if (c ~ /^cap:/) provider[c] = id }
  }
  for (i = 1; i <= n; i++) {
    id = ids[i]; st = f[id, "status"]
    if (st !~ /^(planned|ready|in-progress|shipped|dropped)/) err(id ": status \"" st "\" not one of planned|ready|in-progress|shipped|dropped")
    if (f[id, "goal"] == "" || f[id, "goal"] == "-") err(id ": serves no goal")
    m = split(f[id, "goal"], gs, ",")
    for (j = 1; j <= m; j++) { g = trim(gs[j]); if (g != "-" && !(g in goal)) err(id ": goal " g " not in goals.md") }
    m = split(f[id, "assumptions"], as, ",")
    for (j = 1; j <= m; j++) { a = trim(as[j]); if (a != "-" && a != "" && !(a in assum)) err(id ": assumption " a " not in assumptions.md") }
    deps[id] = ""
    m = split(f[id, "requires"], rs, ",")
    for (j = 1; j <= m; j++) {
      r = trim(rs[j]); if (r == "-" || r == "") continue
      if (r ~ /^cap:/) { if (!(r in provider)) { err(id ": requires " r " but no item provides it"); continue } ; r = provider[r] }
      else if (!(r in seen)) { err(id ": requires " r " which does not exist"); continue }
      deps[id] = deps[id] " " r
      if (st ~ /^(ready|in-progress|shipped)/ && f[r, "status"] !~ /^shipped/)
        err(id ": is " st " but prerequisite " r " is " f[r, "status"])
    }
    if (st ~ /^in-progress/ && (f[id, "issue"] == "" || f[id, "issue"] == "-")) err(id ": in-progress without an issue")
  }
  for (i = 1; i <= n; i++) if (!color[ids[i]]) visit(ids[i], ids[i])
  printf "  roadmap: %d item(s), %d goal ref(s) resolved\n", n, length(goal)
  exit bad
}
function visit(id, path,   k, m, d) {
  color[id] = 1
  m = split(deps[id], d, " ")
  for (k = 1; k <= m; k++) {
    if (color[d[k]] == 1) err("cycle: " path " -> " d[k])
    else if (!color[d[k]]) visit(d[k], path " -> " d[k])
  }
  color[id] = 2
}
' "$P/goals.md" "$P/assumptions.md" "$P/roadmap.md" || { red "FAIL roadmap"; exit 1; }
green "PASS roadmap"
