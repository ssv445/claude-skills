#!/usr/bin/env bash
# Architecture impact: the issue's spec must fill "## Architecture impact". When it declares
# a new module or an owner change, the branch must also update the architecture doc and add an ADR,
# and the spec must ask for owner approval. One owner per fact is only kept if new owners are named.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

arch="docs/guidelines/architecture.md"
d="$(issue_dir)"
spec="${d:+$d/spec.md}"
if [ -z "$spec" ] || [ ! -f "$spec" ]; then
  info "architecture: no spec for this branch, nothing to check"; green "PASS architecture"; exit 0
fi

# The section body: lines after the heading, up to the next "## " heading.
body="$(awk '/^## /{ on = ($0 ~ /^## Architecture impact[[:space:]]*$/); next } on' "$spec")"
grep -q '^## Architecture impact[[:space:]]*$' "$spec" || { red "FAIL architecture: $spec has no \"## Architecture impact\" section"; exit 1; }

fail=0
for field in "Modules touched" "New owners" "New module or owner change"; do
  v="$(printf '%s\n' "$body" | sed -n "s/^- \*\{0,2\}$field:\*\{0,2\}[[:space:]]*//p" | head -1)"
  if [ -z "$v" ]; then red "  miss \"$field:\" is empty or missing"; fail=1
  elif printf '%s' "$v" | grep -q '<'; then red "  miss \"$field:\" still has a <placeholder>"; fail=1
  else info "ok   $field: $v"
  fi
done
[ $fail -eq 0 ] || { red "FAIL architecture: fill \"## Architecture impact\" in $spec"; exit 1; }

change="$(printf '%s\n' "$body" | sed -n 's/^- \*\{0,2\}New module or owner change:\*\{0,2\}[[:space:]]*//p' | head -1)"
case "$change" in
  [Yy]es*)
    changed="$(changed_files)"
    printf '%s\n' "$changed" | grep -qxF "$arch" || { red "  miss $arch not updated in this branch"; fail=1; }
    printf '%s\n' "$changed" | grep -q '^docs/adr/' || { red "  miss no ADR added or changed under docs/adr/"; fail=1; }
    grep -q '^owner-approval:[[:space:]]*required' "$spec" || { red "  miss spec does not set owner-approval: required"; fail=1; }
    [ $fail -eq 0 ] || { red "FAIL architecture: a new module or owner change needs the doc, an ADR and owner approval"; exit 1; }
    info "ok   architecture change carries $arch, an ADR and owner-approval" ;;
  [Nn]o*) ;;
  *) red "FAIL architecture: \"New module or owner change:\" must start with yes or no"; exit 1 ;;
esac
green "PASS architecture"
