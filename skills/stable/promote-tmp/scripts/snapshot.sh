#!/usr/bin/env bash
# Step 8 of the promotion route, for a snapshot row: copy one file into the
# evidence folder through `envscan dehydrate`, then scan the copy. The copy is
# what gets committed, so it is the copy that has to scan clean.
#
#   snapshot.sh <envscan> <source-file> <evidence/YYYYMMDD-topic/name>
#
# The destination name is the agent's: rename it when the source name holds an
# identifier. The scan also matches file names, so a name that still holds a
# value fails here.
#
# Exit 0 copied and clean; 1 not clean, the copy is left for inspection and must
# not be committed; 3 usage error, or a data file, or dehydrate failed.
# Written for bash 3.2.
set -euo pipefail

die() { printf 'snapshot: %s\n' "$*" >&2; exit 3; }
[ "$#" -eq 3 ] || die "usage: snapshot.sh <envscan> <source-file> <evidence/YYYYMMDD-topic/name>"
bin=$1 src=$2 dest=$3

[ -f "$src" ] || die "$src is not a file"
case $dest in
  evidence/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-?*/?*) ;;
  *) die "$dest is not under evidence/YYYYMMDD-<topic>/" ;;
esac
case $(printf '%s' "$src" | tr 'A-Z' 'a-z') in
  *.csv | *.tsv | *.jsonl | *.ndjson | *.xlsx | *.xls | *.parquet | *.sqlite | *.db | \
    *.avro | *.orc | *.hyper | *.twbx | *.tdsx)
    die "$src is a data file; it is never opened or copied, so it is cache, discard or refuse" ;;
esac

mkdir -p "$(dirname -- "$dest")"
"$bin" dehydrate "$src" >"$dest" || { rm -f "$dest"; die "envscan dehydrate failed on $src"; }
# Keep the source's executable bit: a snapshot is copied because it runs.
if [ -x "$src" ]; then chmod +x "$dest"; fi

set +e
"$bin" scan --no-ignore "$dest"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  printf 'snapshot: %s is not clean (scan exit %s); rewrite it or take the row back to the menu\n' "$dest" "$rc" >&2
  exit 1
fi
printf 'snapshot: %s clean\n' "$dest"
