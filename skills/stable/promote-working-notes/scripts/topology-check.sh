#!/usr/bin/env bash
# topology-check.sh — Gate 2 of the promote-working-notes skill.
#
# Runs over NEWLY-AUTHORED prose only, never over raw source material.
# Reports; never refuses. Always exits 0 — a non-zero exit would make this a
# gate that blocks, and naming a host as inline evidence is a style call.
#
# Usage:
#   topology-check.sh [--vocab FILE] FILE...
#
# Identity terms (host nicknames, internal DNS suffix, client names) are the
# leak itself, so they are never hardcoded here. See references/topology-check.md.

set -uo pipefail

vocab=""
files=()

while (($#)); do
  case "$1" in
    --vocab)
      vocab="${2:-}"
      shift 2
      ;;
    -h | --help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *)
      files+=("$1")
      shift
      ;;
  esac
done

if ((${#files[@]} == 0)); then
  echo "usage: topology-check.sh [--vocab FILE] FILE..." >&2
  exit 0
fi

if [[ -z $vocab ]]; then
  vocab="${TOPOLOGY_VOCAB:-$HOME/.config/topology-vocab.txt}"
fi

# --- generic classes: recognisable by shape, safe to publish -----------------

declare -a class_name class_pattern

add_class() {
  class_name+=("$1")
  class_pattern+=("$2")
}

add_class "private IPv4" \
  '\b(10\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])|192\.168)\.[0-9]{1,3}\.[0-9]{1,3}\b'
add_class "overlay/CGNAT range" \
  '\b100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3}\b'
add_class "absolute home path" \
  '(/home/[a-z0-9_.-]+|/Users/[A-Za-z0-9_.-]+)/'
add_class "credential prefix" \
  '\b(github_pat_|ghp_|gho_|ghs_|ghu_|xox[baprs]-|sk-[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{20,})'
add_class "session cookie" \
  '\b(user_session|_gh_sess|_octo|sessionid)\s*='
add_class "auth header" \
  '(Authorization:|Bearer)[[:space:]]+[A-Za-z0-9._-]{16,}'
add_class "ssh/connection string" \
  '(\bssh[[:space:]]+(-i[[:space:]]+\S+[[:space:]]+)?[a-z0-9_.-]+@|\b[a-z0-9_.-]+@[a-z0-9.-]+:[0-9]{2,5}\b)'
add_class "internal URL" \
  'https?://([a-z0-9-]+(\.(local|lan|internal|home|corp|intranet))\b|[a-z0-9-]+(:[0-9]+)?/)'

# --- run ---------------------------------------------------------------------

hits=0

scan() {
  local label="$1" pattern="$2" out
  out=$(grep -InE "$pattern" "${files[@]}" 2>/dev/null) || return 0
  [[ -z $out ]] && return 0
  printf '\n  %s\n' "$label"
  while IFS= read -r line; do
    printf '    %s\n' "$line"
    hits=$((hits + 1))
  done <<<"$out"
}

echo "topology check — ${#files[@]} file(s)"

for i in "${!class_name[@]}"; do
  scan "${class_name[$i]}" "${class_pattern[$i]}"
done

if [[ -r $vocab ]]; then
  echo
  echo "  identity vocabulary: $vocab"
  while IFS= read -r pat; do
    [[ -z $pat || $pat == \#* ]] && continue
    scan "identity: $pat" "$pat"
  done <"$vocab"
else
  cat <<EOF

  !! NO IDENTITY VOCABULARY FOUND ($vocab)
  !! Host nicknames, internal DNS suffix and client identifiers were NOT checked.
  !! Generic classes ran; the identity half did not. See references/topology-check.md.
EOF
fi

echo
if ((hits == 0)); then
  echo "no hits."
else
  echo "$hits hit(s) — REPORT ONLY. Decide each one; this check does not refuse."
  echo "Substitutions: host -> capability description (never a fake name);"
  echo "DNS suffix -> example.com; home paths -> ~/ ; clients -> acme vocabulary;"
  echo "worked examples keep their shape and magnitude."
fi

exit 0
