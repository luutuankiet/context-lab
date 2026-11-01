#!/usr/bin/env bash
# Steps 2 and 4 of the promotion route, the mechanical half of the menu: every
# file in a topic folder that is not `recorded`, with what the agent needs to
# judge it. Recorded files are hidden here, never from the leak scan.
#
#   menu.sh <envscan> <topic-folder>
#
# Prints one tab-separated row per file, most-cited first:
#   inbound  state  sha256  kind  path
#
#   inbound  lines in tracked files that cite the path; a cited file is one a
#            doc depends on, and clearing it breaks that doc
#   state    none (never recorded) or changed (recorded, digest differs since)
#   sha256   the digest `promotion add --sha256` takes for this row
#   kind     data (never opened, never snapshot), repo (a nested clone; move it
#            to tmp/refs/<key>/), or text
#
# Exit 0, or 3 when status fails. Written for bash 3.2.
set -euo pipefail

[ "$#" -eq 2 ] || { printf 'usage: menu.sh <envscan> <topic-folder>\n' >&2; exit 3; }
bin=$1
folder=$2
root=$(git -C "$folder" rev-parse --show-toplevel)
abs=$(cd -- "$folder" && pwd -P)
cd "$root"
root=$(pwd -P)
rel=${abs#"$root"/}

json=$("$bin" promotion status "$rel" --json) || exit 3

kind_of() {
  if [ -d "$1" ]; then echo repo; return; fi
  case $(printf '%s' "$1" | tr 'A-Z' 'a-z') in
    *.csv | *.tsv | *.jsonl | *.ndjson | *.xlsx | *.xls | *.parquet | *.sqlite | *.db | \
      *.avro | *.orc | *.hyper | *.twbx | *.tdsx) echo data ;;
    *) echo text ;;
  esac
}

rows=""
path="" sha=""
# The status JSON is printed one key per line; read the three keys a row needs.
while IFS= read -r line; do
  case $line in
    *'"path": "'*) path=${line#*\"path\": \"}; path=${path%\",} ;;
    *'"sha256": "'*) sha=${line#*\"sha256\": \"}; sha=${sha%\",} ;;
    *'"sha256": null'*) sha=- ;;
    *'"state": "'*)
      state=${line#*\"state\": \"}
      state=${state%\",}
      if [ "$state" != recorded ]; then
        # git grep exits 1 on no match; that is a count of 0, not a failure.
        n=$({ git grep -c -F -e "$path" -- . 2>/dev/null || true; } | awk -F: '{s += $NF} END {print s + 0}')
        rows="$rows$n	$state	$sha	$(kind_of "$path")	$path
"
      fi
      ;;
  esac
done <<EOF
$json
EOF

[ -n "$rows" ] || exit 0
printf '%s' "$rows" | sort -t '	' -k1,1nr -k5,5
