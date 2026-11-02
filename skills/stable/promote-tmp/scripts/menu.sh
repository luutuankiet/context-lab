#!/usr/bin/env bash
# Steps 2 and 4 of the promotion route, the mechanical half of the menu: what in a
# topic folder still needs a decision, with what the agent needs to judge it.
# Recorded files are hidden here, never from the leak scan.
#
#   menu.sh <envscan> <topic-folder> [--expand <dir>]...
#
# Rows, tab-separated, most-cited first:
#   inbound  state  sha256  kind  path            one file or clone
#   inbound  none   -       tree  path  files     one folded directory
#
#   inbound  citations of the path in tracked and untracked files, gitignored ones
#            excluded. It counts occurrences, not lines, so a line citing a path
#            twice counts 2. A tree's count can run over: sibling `big-notes.md`
#            also matches tree `big`
#   state    none (never recorded) or changed (recorded, digest differs since)
#   sha256   the digest `promotion add --sha256` takes for this row
#   kind     data (never opened, never snapshot), repo (a nested clone; move it to
#            tmp/refs/<key>/), tree (a big directory; move it whole), or text
#
# Walking down from the topic folder (which never folds itself), the shallowest
# directory with at least MENU_TREE_MIN (default 200) unrecorded files folds to one
# row, unless it holds a clone, a recorded file or a changed file; those are descended
# into. --expand keeps that whole subtree row by row, descendants included. If any tree
# row exists, only tree and clone rows are printed: the moves come first.
#
# Exit 0, or 3 when status or the citation search fails. Written for bash 3.2.
set -euo pipefail

usage() {
  printf 'usage: menu.sh <envscan> <topic-folder> [--expand <dir>]...\n' >&2
  exit 3
}

[ "$#" -ge 2 ] || usage
bin=$1
folder=$2
shift 2

min=${MENU_TREE_MIN:-200}
case $min in
  '' | *[!0-9]*) printf 'menu: MENU_TREE_MIN must be a whole number\n' >&2; exit 3 ;;
esac
[ "$min" -ge 1 ] || { printf 'menu: MENU_TREE_MIN must be at least 1\n' >&2; exit 3; }

root=$(git -C "$folder" rev-parse --show-toplevel) || exit 3
abs=$(cd -- "$folder" && pwd -P) || exit 3

W=$(mktemp -d "${TMPDIR:-/tmp}/promote-menu.XXXXXX") || exit 3
trap 'rm -rf "$W"' EXIT

# A mistyped --expand must not read as "declined": it would silently change nothing.
: >"$W/expand"
while [ "$#" -gt 0 ]; do
  [ "$1" = --expand ] || usage
  [ "$#" -ge 2 ] || usage
  dir=$(cd -- "$2" 2>/dev/null && pwd -P) || { printf 'menu: --expand %s: not a directory\n' "$2" >&2; exit 3; }
  case $dir in
    "$abs") printf '.\n' >>"$W/expand" ;;
    "$abs"/*) printf '%s\n' "${dir#"$abs"/}" >>"$W/expand" ;;
    *) printf 'menu: --expand %s: outside the topic folder\n' "$2" >&2; exit 3 ;;
  esac
  shift 2
done

cd "$root"
root=$(pwd -P)
rel=${abs#"$root"/}

"$bin" promotion status "$rel" --json >"$W/status.json" || exit 3

# envscan does not scan a file over its size limit (MAX_FILE_BYTES, 2,000,000 bytes),
# so such a file is data whatever its extension. One find, not a stat per row.
find "$rel" -name .git -prune -o -type f -size +1999999c -print >"$W/large" || exit 3

# Paths reach awk through the environment: -v would process backslashes in them.
MENU_REL=$rel MENU_MIN=$min MENU_EXPAND="$W/expand" MENU_PATTERNS="$W/patterns" MENU_LARGE="$W/large" \
  awk '
  function walk(i,    rest, d, k) {
    # Sets dirs[1..depth] to the proper ancestors of item i, shallowest first.
    rest = (substr(P[i], 1, plen) == prefix) ? substr(P[i], plen + 1) : ""
    d = ""
    depth = 0
    while ((k = index(rest, "/")) > 0) {
      d = (d == "" ? "" : d "/") substr(rest, 1, k - 1)
      rest = substr(rest, k + 1)
      dirs[++depth] = d
    }
  }
  function unjson(s,    out, k) {
    # The status JSON escapes a backslash and a quote; the path on disk has neither.
    out = ""
    while ((k = index(s, "\\")) > 0) {
      out = out substr(s, 1, k - 1) substr(s, k + 1, 1)
      s = substr(s, k + 2)
    }
    return out s
  }
  function kind(p,    low) {
    if (p in large) return "data"
    low = tolower(p)
    if (low ~ /\.(csv|tsv|jsonl|ndjson|xlsx|xls|parquet|sqlite|db|avro|orc|hyper|twbx|tdsx)$/) return "data"
    return "text"
  }
  BEGIN {
    prefix = ENVIRON["MENU_REL"] "/"
    plen = length(prefix)
    min = ENVIRON["MENU_MIN"] + 0
    file = ENVIRON["MENU_LARGE"]
    while ((getline line < file) > 0) large[line] = 1
    close(file)
    file = ENVIRON["MENU_EXPAND"]
    while ((getline line < file) > 0) {
      expanded[line] = 1
      d = ""
      rest = line
      while ((k = index(rest, "/")) > 0) {
        d = (d == "" ? "" : d "/") substr(rest, 1, k - 1)
        rest = substr(rest, k + 1)
        blocked[d] = 1
      }
      blocked[line] = 1
    }
    close(file)
  }
  # The status JSON is printed one key per line, item keys at six spaces.
  /^      "path": "/   { path = unjson(substr($0, 16, length($0) - 17)); next }
  /^      "sha256": null/ { sha = "-"; next }
  /^      "sha256": "/ { sha = substr($0, 18, length($0) - 19); next }
  /^      "state": "/  {
    n++
    P[n] = path
    H[n] = sha
    S[n] = substr($0, 17, length($0) - 18)
  }
  END {
    # A null digest in a status that exited 0 is a clone: an unreadable path exits 3.
    for (i = 1; i <= n; i++) {
      walk(i)
      for (j = 1; j <= depth; j++) {
        if (H[i] == "-" || S[i] != "none") blocked[dirs[j]] = 1
        else count[dirs[j]]++
      }
    }
    trees = 0
    for (i = 1; i <= n; i++) {
      if (H[i] == "-" || S[i] != "none" || ("." in expanded)) continue
      walk(i)
      for (j = 1; j <= depth; j++) {
        # A declined directory keeps its whole subtree, so stop descending here.
        if (dirs[j] in expanded) break
        if (count[dirs[j]] >= min && !(dirs[j] in blocked)) {
          if (!(dirs[j] in tree)) trees++
          tree[dirs[j]] = 1
          folded[i] = 1
          break
        }
      }
    }
    patterns = ENVIRON["MENU_PATTERNS"]
    if (trees > 0) {
      for (d in tree) {
        print "none\t-\ttree\t" prefix d "\t" count[d]
        print prefix d > patterns
      }
      # Clones move too, so they are proposed beside the trees.
      for (i = 1; i <= n; i++) {
        if (H[i] != "-" || S[i] == "recorded") continue
        print S[i] "\t-\trepo\t" P[i]
        print P[i] > patterns
      }
    } else {
      for (i = 1; i <= n; i++) {
        if (S[i] == "recorded") continue
        print S[i] "\t" H[i] "\t" (H[i] == "-" ? "repo" : kind(P[i])) "\t" P[i]
        print P[i] > patterns
      }
    }
  }' "$W/status.json" >"$W/rows"

[ -s "$W/rows" ] || exit 0

# One pass. Exit 1 is no match; anything above is a failed search, never a count of 0.
# The config overrides stop a user setting from decorating the -o output.
rc=0
git -c grep.lineNumber=false -c grep.column=false -c grep.fullName=false \
  grep --no-color --untracked -h -o -F -f "$W/patterns" -- . >"$W/hits" 2>"$W/grep.err" || rc=$?
if [ "$rc" -gt 1 ]; then
  printf 'menu: git grep failed (exit %s)\n' "$rc" >&2
  sed 's/^/  /' "$W/grep.err" >&2
  exit 3
fi

# With -o a matched line holds exactly one pattern, and at one position git keeps the
# longest, so f1.py.bak does not count for f1.py. Anything else (a binary-file notice)
# equals no row's path and is never looked up.
MENU_HITS="$W/hits" awk '
  BEGIN {
    FS = "\t"
    file = ENVIRON["MENU_HITS"]
    while ((getline line < file) > 0) hits[line]++
    close(file)
  }
  { print (($4 in hits) ? hits[$4] : 0) "\t" $0 }' "$W/rows" |
  sort -t '	' -k1,1nr -k5,5
