#!/usr/bin/env bash
# Architecture impact: the issue's spec must fill "## Architecture impact". A new owner, a new
# module or an owner change must also add an ADR, update the architecture doc (naming each new
# owner) and ask for owner approval. One owner per fact only holds if new owners are named.
. "$(git rev-parse --show-toplevel)/.standards/lib/common.sh"

arch="${ARCH_DOC:-docs/guidelines/architecture.md}"
gate=".standards/checks/architecture.sh"
d="$(issue_dir)"
if [ -z "$d" ]; then
  info "architecture: no docs/work/<issue>-<slug>/ for this branch, nothing to check"; green "PASS architecture"; exit 0
fi
spec="$d/spec.md"
[ -f "$spec" ] || { red "FAIL architecture: $d exists but has no spec.md"; exit 1; }

# Specs written before this gate reached the base branch are grandfathered (author time survives rebase).
added_at() { git log --diff-filter=A --format=%at "$@" | tail -1; }
if ! grep -qiE '^##[[:space:]]+architecture impact[[:space:]]*$' "$spec"; then
  gate_at="$(added_at "$(base_commit)" -- "$gate")"; spec_at="$(added_at HEAD -- "$spec")"
  if [ -z "$gate_at" ] || { [ -n "$spec_at" ] && [ "$spec_at" -lt "$gate_at" ]; }; then
    info "architecture: $spec predates this gate on $BASE_BRANCH, skipped"; green "PASS architecture"; exit 0
  fi
  red "FAIL architecture: $spec has no \"## Architecture impact\" section (template: docs/templates/spec.md)"; exit 1
fi

# Section body up to the next "## " heading, with bullets and markdown emphasis stripped.
body="$(awk '/^##[[:space:]]/{ on = (tolower($0) ~ /^##[[:space:]]+architecture impact[[:space:]]*$/); next } on' "$spec" \
  | sed -E 's/^[[:space:]]*[-*+][[:space:]]+//; s/\*//g')"
field() { printf '%s\n' "$body" | grep -i "^$1[[:space:]]*:" | head -1 | sed -E 's/^[^:]*:[[:space:]]*//; s/[[:space:]]+$//'; }

fail=0
for f in "Modules touched" "New owners" "New module or owner change"; do
  v="$(field "$f")"
  if [ -z "$v" ]; then red "  miss \"$f:\" is empty or missing"; fail=1
  elif printf '%s' "$v" | grep -q '<'; then red "  miss \"$f:\" still has a <placeholder>"; fail=1
  else info "ok   $f: $v"
  fi
done
[ $fail -eq 0 ] || { red "FAIL architecture: fill \"## Architecture impact\" in $spec"; exit 1; }

owners="$(field "New owners")"
change="$(field "New module or owner change" | tr '[:upper:]' '[:lower:]')"
case "$change" in
  yes|yes[!a-z]*) change=yes ;;
  no|no[!a-z]*)   change=no ;;
  *) red "FAIL architecture: \"New module or owner change:\" must start with the word yes or no"; exit 1 ;;
esac
case "$(printf '%s' "$owners" | tr '[:upper:]' '[:lower:]')" in
  none|none[!a-z]*) ;;
  *) [ "$change" = yes ] || { red "FAIL architecture: \"New owners:\" names owners, so \"New module or owner change:\" must be yes"; exit 1; } ;;
esac
[ "$change" = yes ] || { green "PASS architecture"; exit 0; }

changed="$(changed_files)"
printf '%s\n' "$changed" | grep -qxF "$arch" || { red "  miss $arch not updated in this branch"; fail=1; }
[ -n "$(git diff --diff-filter=A --name-only "$(base_commit)" HEAD -- docs/adr/)" ] || { red "  miss no new ADR added under docs/adr/"; fail=1; }
grep -qiE "$(owner_flag_re approval)" "$spec" || { red "  miss spec front matter does not ask for owner approval (owner-approval: required)"; fail=1; }
# Each "thing -> module" in New owners must name a module the architecture doc knows.
for m in $(printf '%s\n' "$owners" | sed 's/→/->/g' | tr ',;' '\n\n' | sed -n 's/.*->[[:space:]]*//p' \
             | sed -E 's/[[:space:]]*\(.*//; s/[[:space:]]+$//; s/[[:space:]]/_SPACE_/g'); do
  m="${m//_SPACE_/ }"
  [ -f "$arch" ] && grep -qiF -- "$m" "$arch" || { red "  miss owner \"$m\" is not named in $arch"; fail=1; }
done
case "$(printf '%s' "$owners" | tr '[:upper:]' '[:lower:]')" in
  none|none[!a-z]*) ;;
  *) printf '%s' "$owners" | sed 's/→/->/g' | grep -q -- '->' || { red "  miss \"New owners:\" must name each as <thing> -> <owning module>"; fail=1; } ;;
esac
[ $fail -eq 0 ] || { red "FAIL architecture: a structure change needs a new ADR, the architecture doc and owner approval"; exit 1; }
info "ok   structure change carries $arch, a new ADR and owner approval"
green "PASS architecture"
