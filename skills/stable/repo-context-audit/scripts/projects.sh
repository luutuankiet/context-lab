#!/usr/bin/env bash
#
# projects.sh -- list and maintain private project folders under tmp/projects/.
#
#   projects.sh [--repo DIR] [--since DAYS]     one row per project, newest first
#   projects.sh [--repo DIR] --reindex [SLUG]   regenerate indexes, then touch AGENTS.md
#   projects.sh [--repo DIR] --init SLUG        create tmp/projects/SLUG/
#
# A project is a plain, gitignored folder that holds context which is not ready
# to publish. It uses the same layout as a repo root, built lazily, so audit.sh
# and gen-docs-index.sh work on it with --repo tmp/projects/SLUG.
#
# The listing writes nothing. Each row is the slug, the date of the newest file
# anywhere in the project, the file count, and the first line of its scope,
# taken from README.md or else AGENTS.md.
#
# --reindex runs the index generator on every project that has pages (or only
# the one named) and touches its AGENTS.md, so that file's modified time shows
# when the project was last worked on. A project with no pages is left alone.
#
# --init writes CLAUDE.md and an AGENTS.md skeleton and nothing else. It refuses
# an existing slug. Before writing it checks that git ignores tmp/projects; if
# not, it appends the path to .git/info/exclude, which is local and never
# committed. Outside a git repository it carries on.
#
# Written for bash 3.2: no associative arrays, no mapfile, no ${x,,}.

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

REPO=""
MODE=list
SINCE=""
SLUG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)    [ $# -ge 2 ] || { echo "--repo needs a directory" >&2; exit 2; }
               REPO="$2"; shift 2 ;;
    --since)   [ $# -ge 2 ] || { echo "--since needs a number of days" >&2; exit 2; }
               SINCE="$2"; shift 2 ;;
    --init)    [ $# -ge 2 ] || { echo "--init needs a slug" >&2; exit 2; }
               MODE=init; SLUG="$2"; shift 2 ;;
    --reindex) MODE=reindex; shift
               if [ $# -gt 0 ]; then
                 case "$1" in -*) ;; *) SLUG="$1"; shift ;; esac
               fi ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *)         echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$SINCE" in
  *[!0-9]*) echo "--since takes a whole number of days, got: $SINCE" >&2; exit 2 ;;
esac

if [ -z "$REPO" ]; then
  REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
REPO="$(cd -- "$REPO" && pwd)"
ROOT="$REPO/tmp/projects"

# ---------------------------------------------------------------- helpers ---

# GNU and BSD stat share no flag for a modified time. `stat -c` is tried first
# because BSD rejects it outright, while GNU reads `stat -f` as "file system".
if stat -c %Y / >/dev/null 2>&1; then STAT=gnu; else STAT=bsd; fi

# newest <dir> -- "<epoch> <YYYY-MM-DD>" of the newest file, or nothing.
newest() {
  if [ "$STAT" = gnu ]; then
    find "$1" -name .git -prune -o -type f -exec stat -c '%Y %y' {} + 2>/dev/null
  else
    find "$1" -name .git -prune -o -type f -exec stat -f '%m %Sm' -t '%Y-%m-%d' {} + 2>/dev/null
  fi | LC_ALL=C sort -n | awk 'END { if (NR) print $1, substr($2, 1, 10) }'
}

# days <YYYY-MM-DD> -- a day number, in awk so no `date` flag is needed.
days() {
  awk -v d="$1" 'BEGIN {
    n = split(d, p, "-")
    if (n != 3) { print -1; exit }
    y = p[1] + 0; m = p[2] + 0; dd = p[3] + 0
    a = int((14 - m) / 12); yy = y + 4800 - a; mm = m + 12 * a - 3
    print dd + int((153 * mm + 2) / 5) + 365 * yy + int(yy / 4) \
          - int(yy / 100) + int(yy / 400) - 32045
  }'
}

# scope <project> -- the first line of prose in README.md, else AGENTS.md, else
# the first heading. Headings, comments, imports and frontmatter are skipped.
scope() {
  local f
  for f in "$1/README.md" "$1/AGENTS.md"; do
    [ -f "$f" ] || continue
    awk '
      NR == 1 && $0 == "---" { fm = 1; next }
      fm { if ($0 == "---") fm = 0; next }
      # Below this marker is the pointer every project carries, never its scope.
      /Standard block\./ { exit }
      incomment { if (index($0, "-->")) incomment = 0; next }
      /^[ \t]*<!--/ { if (!index($0, "-->")) incomment = 1; next }
      /^[ \t]*$/ || /^@/ || /^[|>`]/ { next }
      /^#/ { if (head == "") { head = $0; sub(/^#+[ \t]*/, "", head) } next }
      { print; found = 1; exit }
      END { if (!found && head != "") print head }
    ' "$f" | cut -c1-80
    return 0
  done
}

# slugs -- every project folder name, one per line.
slugs() {
  local d
  [ -d "$ROOT" ] || return 0
  for d in "$ROOT"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"; printf '%s\n' "${d##*/}"
  done
}

# has_pages <project> -- true once any page other than an index exists in docs/.
has_pages() {
  [ -d "$1/docs" ] || return 1
  find "$1/docs" -maxdepth 2 -type f -name '*.md' ! -name 'README.md' 2>/dev/null | grep -q .
}

# ignore_guard -- make sure git never sees tmp/projects. A local exclude is
# used, not .gitignore, so nothing about private work is ever committed.
ignore_guard() {
  local exclude
  git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  if git -C "$REPO" check-ignore -q "$ROOT/.probe" 2>/dev/null; then return 0; fi
  exclude="$(cd -- "$REPO" && git rev-parse --git-path info/exclude)"
  case "$exclude" in /*) ;; *) exclude="$REPO/$exclude" ;; esac
  mkdir -p -- "$(dirname -- "$exclude")"
  # The path is anchored to where git resolves the exclude file from: the top
  # of the work tree, which may sit above --repo.
  local top rel
  top="$(cd -- "$REPO" && git rev-parse --show-toplevel)"
  top="$(cd -- "$top" && pwd)"
  rel="${ROOT#"$top"/}"
  printf '%s/\n' "$rel" >> "$exclude"
  echo "ignore guard: added $rel/ to ${exclude#"$REPO"/}"
}

# ------------------------------------------------------------------- init ---

if [ "$MODE" = init ]; then
  case "$SLUG" in
    ""|-*|*-|*[!a-z0-9-]*)
      echo "not a slug: '$SLUG' -- use short kebab-case, such as acme-migration" >&2; exit 2 ;;
  esac
  P="$ROOT/$SLUG"
  if [ -e "$P" ]; then
    echo "tmp/projects/$SLUG already exists; nothing was written. Reuse it." >&2
    exit 1
  fi
  BLOCK="$HERE/../templates/AGENTS-private-block.md"
  [ -f "$BLOCK" ] || { echo "template missing: $BLOCK" >&2; exit 1; }

  ignore_guard

  if [ -x "$REPO/scripts/gen-docs-index.sh" ]; then
    GENCMD="scripts/gen-docs-index.sh --repo tmp/projects/$SLUG"
  else
    GENCMD="gen-docs-index.sh --repo tmp/projects/$SLUG"
  fi

  mkdir -p -- "$P"
  printf '@AGENTS.md\n' > "$P/CLAUDE.md"
  {
    printf '# %s\n\n' "$SLUG"
    printf '<!-- Replace this comment with one short paragraph: what this project is,\n'
    printf '     who it is for, and what is in and out of scope. -->\n\n'
    printf '## Hard constraints\n\n'
    printf '<!-- The few facts that shape most decisions here. -->\n\n'
    # The first comment of the template is a note to whoever appends it, not
    # part of the block; the block starts at its seam marker.
    awk -v gen="$GENCMD" '
      index($0, "<!-- Standard block.") == 1 { on = 1 }
      on {
        i = index($0, "<the repo" "\047" "s index generator>")
        if (i) $0 = substr($0, 1, i - 1) gen substr($0, i + 28)
        print
      }' "$BLOCK"
  } > "$P/AGENTS.md"

  echo "created tmp/projects/$SLUG/CLAUDE.md"
  echo "created tmp/projects/$SLUG/AGENTS.md"
  exit 0
fi

# ---------------------------------------------------------------- reindex ---

if [ "$MODE" = reindex ]; then
  if [ -n "$SLUG" ]; then
    [ -d "$ROOT/$SLUG" ] || { echo "no such project: tmp/projects/$SLUG" >&2; exit 1; }
    LIST="$SLUG"
  else
    LIST="$(slugs)"
  fi
  [ -n "$LIST" ] || { echo "no projects under tmp/projects/"; exit 0; }
  ignore_guard
  rc=0
  # Slugs are kebab-case, so splitting the list on whitespace is safe; a folder
  # that is not kebab-case was not made by --init and is skipped by the glob
  # only if it holds a space.
  for s in $LIST; do
    P="$ROOT/$s"
    if ! has_pages "$P"; then
      echo "skip  $s -- no pages to index"
      continue
    fi
    if "$HERE/gen-docs-index.sh" --repo "$P" >/dev/null; then
      [ -f "$P/AGENTS.md" ] && touch "$P/AGENTS.md"
      echo "ok    $s -- index regenerated"
    else
      echo "FAIL  $s -- the generator reported a problem" >&2
      rc=1
    fi
  done
  exit "$rc"
fi

# ------------------------------------------------------------------- list ---

ROWS=""
TODAY_DAYS="$(days "$(date +%Y-%m-%d)")"
while IFS= read -r s; do
  [ -n "$s" ] || continue
  P="$ROOT/$s"
  n="$(newest "$P")"
  if [ -z "$n" ]; then epoch=0; day="-"; else epoch="${n%% *}"; day="${n#* }"; fi
  if [ -n "$SINCE" ]; then
    [ "$day" = "-" ] && continue
    [ $((TODAY_DAYS - $(days "$day"))) -le "$SINCE" ] || continue
  fi
  files=$(find "$P" -name .git -prune -o -type f -print 2>/dev/null | grep -c . || true)
  ROWS="$ROWS$epoch	$s	$day	$files	$(scope "$P")
"
done <<LIST_EOF
$(slugs)
LIST_EOF

if [ -z "$ROWS" ]; then
  if [ -n "$SINCE" ]; then echo "no projects under tmp/projects/ touched in the last $SINCE days"
  else echo "no projects under tmp/projects/"; fi
  exit 0
fi

printf '%-24s %-10s %5s  %s\n' project newest files scope
printf '%s' "$ROWS" | LC_ALL=C sort -t '	' -k1,1nr -k2,2 |
  awk -F '\t' '{ printf "%-24s %-10s %5s  %s\n", $2, $3, $4, $5 }'
exit 0
