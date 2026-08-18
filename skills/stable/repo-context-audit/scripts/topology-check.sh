#!/usr/bin/env bash
# topology-check.sh — Gate 2 of references/route-promote.md in the repo-context-audit skill.
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

# The scan engine is `rg`, deliberately. `grep` is commonly shimmed to a
# BRE-mode tool in an agent sandbox, where it returns ZERO matches on a pattern
# it cannot parse — a secret scanner that fails open is worse than none.
if ! command -v rg >/dev/null 2>&1; then
  echo "topology-check: ripgrep (rg) is required and was not found." >&2
  echo "This check does not fall back to grep: a BRE-mode shim returns zero" >&2
  echo "matches on these patterns and would report a false all-clear." >&2
  exit 0
fi

vocab=""
files=()

while (($#)); do
  case "$1" in
    --vocab)
      vocab="${2:-}"
      shift 2
      ;;
    -h | --help)
      sed -n '2,12p' "$0"
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
add_class "link-local range" \
  '\b169\.254\.[0-9]{1,3}\.[0-9]{1,3}\b'
add_class "absolute home path" \
  '(/home/[a-z0-9_.-]+|/Users/[A-Za-z0-9_.-]+|/root)/'
add_class "credential prefix" \
  '\b(github_pat_|ghp_|gho_|ghs_|ghu_|xox[baprs]-|sk-[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{20,})'
add_class "private key header" \
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
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
  # -I skips binary; --no-heading + -H -n gives the flat path:line:text shape.
  # A file containing a NUL byte makes rg stop searching mid-file, so --text
  # keeps the scan honest to the end of a file rather than silently truncating.
  out=$(rg --no-config --text --no-heading --with-filename --line-number \
    --color never --regexp "$pattern" -- "${files[@]}" 2>/dev/null) || return 0
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
  # An empty or comment-only vocabulary is NOT a pass. Scanning for nothing and
  # printing "no hits" is the exact failure this check exists to avoid.
  vocab_terms=0
  while IFS= read -r pat; do
    [[ -z $pat || $pat == \#* ]] && continue
    vocab_terms=$((vocab_terms + 1))
  done <"$vocab"

  if ((vocab_terms == 0)); then
    cat <<EOF

  !! IDENTITY VOCABULARY IS EMPTY ($vocab)
  !! It exists but contains no terms, so the identity half scanned for nothing.
  !! Treat this as NOT RUN, not as clean. See references/topology-check.md.
EOF
  else
    echo
    echo "  identity vocabulary: $vocab ($vocab_terms term(s))"
    while IFS= read -r pat; do
      [[ -z $pat || $pat == \#* ]] && continue
      scan "identity: $pat" "$pat"
    done <"$vocab"
  fi
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
