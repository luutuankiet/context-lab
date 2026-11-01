#!/usr/bin/env bash
# Refresh marketplaces and update every installed plugin on each host named in
# .env, all hosts at once. Open sessions still need /reload-plugins or a restart.
#   DEPLOY_HOST_1=alias-one              one SSH alias per key, numeric order
#   DEPLOY_HOST_2="alias-two"            gaps are fine; comment a line to retire it
# Reads only those keys, never the rest of .env, which holds unrelated secrets.
set -euo pipefail

env_file="$(cd "$(dirname "$0")/.." && pwd)/.env"

hosts="$(sed -n 's/^DEPLOY_HOST_\([0-9][0-9]*\)="\{0,1\}\([^"]*\)"\{0,1\}$/\1 \2/p' "$env_file" | sort -n | cut -d' ' -f2-)"
case "$hosts" in
  *' '*|*$'\t'*)
    echo "A DEPLOY_HOST_<number> key holds more than one value: use one host per key" >&2
    exit 2
    ;;
esac
set -- $hosts
if [ "$#" -eq 0 ]; then
  echo "No DEPLOY_HOST_<number>=<ssh-alias> keys with a value in $env_file" >&2
  if grep -q '^DEPLOY_HOSTS=' "$env_file"; then
    echo "DEPLOY_HOSTS is no longer read: split it into numbered keys, one host each" >&2
  fi
  exit 2
fi

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  red=$'\033[31m' green=$'\033[32m' yellow=$'\033[33m' bold=$'\033[1m' dim=$'\033[2m' off=$'\033[0m'
else
  red='' green='' yellow='' bold='' dim='' off=''
fi

# Runs under the host's login shell, zsh or bash, so it avoids word splitting.
# A non-interactive SSH shell does not have ~/.local/bin on PATH.
# No -y on plugin update: a changed install command fails here rather than being
# accepted unseen.
remote='
export PATH="$HOME/.local/bin:$PATH"
rc=0
claude plugins marketplace update </dev/null || { echo "FAILED marketplaces"; rc=1; }
ids="$(claude plugin list --json </dev/null | sed -n "s/^ *\"id\": \"\(.*\)\",\$/\1/p")"
[ -n "$ids" ] || { echo "FAILED no plugins listed"; rc=1; }
while IFS= read -r id; do
  [ -n "$id" ] || continue
  claude plugin update "$id" </dev/null || { echo "FAILED plugin: $id"; rc=1; }
done <<IDS
$ids
IDS
exit $rc
'

logs="$(mktemp -d)"
trap 'rm -rf "$logs"' EXIT

count() { # pattern file: prints the number of matching lines
  grep -c "$1" "$2" || true
}

printf '%sDeploying to %s hosts at once...%s\n' "$bold" "$#" "$off"

pids=""
for host in $hosts; do
  (
    start=$SECONDS
    rc=0
    ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$host" "$remote" >"$logs/$host" 2>&1 || rc=$?
    secs=$((SECONDS - start))
    echo "$rc" >"$logs/$host.rc"
    echo "$secs" >"$logs/$host.secs"
    if [ "$rc" -eq 0 ]; then
      printf '  %s✔%s %s finished in %ss\n' "$green" "$off" "$host" "$secs"
    else
      printf '  %s✘%s %s finished with problems in %ss\n' "$red" "$off" "$host" "$secs"
    fi
  ) &
  pids="$pids $!"
done
wait $pids || true

# Details per host, in numeric key order. Only what changed or broke is listed.
for host in $hosts; do
  log="$logs/$host"
  printf '\n%s%s%s\n' "$bold" "$host" "$off"
  sed -n 's/^.*✔ Plugin \(.*\)$/\1/p' "$log" | while IFS= read -r line; do
    printf '  %s↑ %s%s\n' "$yellow" "$line" "$off"
  done
  grep '✘' "$log" | while IFS= read -r line; do
    printf '  %s%s%s\n' "$red" "$line" "$off"
  done || true
  if [ "$(cat "$log.rc")" -ne 0 ] && ! grep -q '✘' "$log"; then
    # Nothing recognisable, such as an unreachable host: show it all.
    sed "s/^/  /" "$log"
  fi
  printf '  %s%s already current%s\n' "$dim" "$(count 'already at the latest' "$log")" "$off"
done

# Summary table. Cells are padded before colouring, because colour codes have width.
row() { printf '%-14s %-8s %8s %8s %8s %6s\n' "$@"; }
cell() { # colour width text
  printf '%s%-*s%s' "$1" "$2" "$3" "$off"
}

printf '\n%s' "$bold"
row HOST STATUS UPDATED CURRENT FAILED TIME
printf '%s' "$off"

failed=""
for host in $hosts; do
  log="$logs/$host"
  updated="$(count '✔ Plugin ' "$log")"
  current="$(count 'already at the latest' "$log")"
  bad="$(count '^FAILED' "$log")"
  rc="$(cat "$log.rc")"
  if [ "$rc" -eq 0 ]; then
    status="$(cell "$green" 8 ok)"
  else
    status="$(cell "$red" 8 FAILED)"
    failed="$failed $host"
    [ "$bad" -gt 0 ] || bad='-'
  fi
  printf '%-14s %s %8s %8s %8s %5ss\n' "$host" "$status" "$updated" "$current" "$bad" "$(cat "$log.secs")"
done

echo
if [ -n "$failed" ]; then
  printf '%sFAILED:%s%s\n' "$red" "$failed" "$off" >&2
  exit 1
fi
printf '%sAll hosts updated.%s Reload open sessions with /reload-plugins.\n' "$green" "$off"
