#!/usr/bin/env bash
#
# Generate docs/README.md from the frontmatter on each page.
#
#   scripts/gen-docs-index.sh            write the index
#   scripts/gen-docs-index.sh --check    exit 1 if the index is stale
#
# One source of truth (the frontmatter), one render (the block between the two
# marker comments in docs/README.md). Everything outside those markers is hand
# written and is preserved.
#
# Never hand-maintain an index. A hand-written one silently orphans pages: the
# page still exists, nothing links to it, and nobody notices for a year.
#
# Dependency-free bash + awk on purpose -- this repo has no Node toolchain, and
# reaching for a static site generator to render one list would be absurd.

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS="$REPO/docs"
INDEX="$DOCS/README.md"
BEGIN_MARK="<!-- BEGIN GENERATED INDEX -- edit the pages, not this block -->"
END_MARK="<!-- END GENERATED INDEX -->"

MODE=write
case "${1-}" in
  --check) MODE=check ;;
  "")      ;;
  *)       echo "unknown argument: $1" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------- helpers ---

# fm <file> <key> -- read one flat `key: value` out of the leading `---` block.
fm() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR == 1                { next }
    $0 == "---"            { exit }
    {
      i = index($0, ":"); if (i == 0) next
      k = substr($0, 1, i - 1); v = substr($0, i + 1)
      gsub(/^[ \t]+|[ \t]+$/, "", k)
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      sub(/^"/, "", v); sub(/"$/, "", v)
      if (k == key) { print v; exit }
    }
  ' "$1"
}

# heading <file> -- the first `# ` line, for pages that carry no frontmatter.
heading() { awk '/^# / { sub(/^# +/, ""); print; exit }' "$1"; }

# cell <text> -- make a string safe inside a markdown table cell.
cell() { printf '%s' "${1//|/\\|}"; }

# pages <dir> -- sorted page paths, or nothing at all if the directory is empty.
pages() {
  [ -d "$DOCS/$1" ] || return 0
  find "$DOCS/$1" -maxdepth 1 -name '*.md' ! -name 'README.md' | LC_ALL=C sort
}

# ----------------------------------------------------------------- render ---

render() {
  local f n

  printf '%s\n' "$BEGIN_MARK"

  printf '\n## Where things live\n\n'
  printf 'One page per area of the system. Read before going looking for where\n'
  printf 'something is implemented.\n\n'
  n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ "$n" -eq 0 ]; then printf '| page | covers | verified |\n|---|---|---|\n'; fi
    n=$((n + 1))
    printf '| [%s](architecture/%s) | %s | %s |\n' \
      "$(cell "$(fm "$f" title)")" "$(basename -- "$f")" \
      "$(cell "$(fm "$f" covers)")" "$(fm "$f" verified)"
  done <<EOF
$(pages architecture)
EOF
  if [ "$n" -eq 0 ]; then printf '_No pages yet._\n'; fi

  printf '\n## Traps\n\n'
  printf 'Failure modes that produce no error message, indexed by the symptom you\n'
  printf 'would observe. Read before debugging behaviour that is wrong but not\n'
  printf 'crashing.\n\n'
  n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ "$n" -eq 0 ]; then printf '| symptom | page | area | verified |\n|---|---|---|---|\n'; fi
    n=$((n + 1))
    printf '| %s | [%s](traps/%s) | %s | %s |\n' \
      "$(cell "$(fm "$f" symptom)")" "$(basename -- "$f" .md)" "$(basename -- "$f")" \
      "$(cell "$(fm "$f" area)")" "$(fm "$f" verified)"
  done <<EOF
$(pages traps)
EOF
  if [ "$n" -eq 0 ]; then printf '_No pages yet._\n'; fi

  printf '\n## Reference\n\n'
  printf 'Simply true, and expensive to re-derive.\n\n'
  n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ "$n" -eq 0 ]; then printf '| page | summary | verified |\n|---|---|---|\n'; fi
    n=$((n + 1))
    printf '| [%s](reference/%s) | %s | %s |\n' \
      "$(cell "$(fm "$f" title)")" "$(basename -- "$f")" \
      "$(cell "$(fm "$f" summary)")" "$(fm "$f" verified)"
  done <<EOF
$(pages reference)
EOF
  if [ "$n" -eq 0 ]; then printf '_No pages yet._\n'; fi

  printf '\n## Decisions\n\n'
  printf 'Why the repo is the way it is. A merged decision is immutable -- supersede\n'
  printf 'it with a new one rather than editing it.\n\n'
  n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    printf -- '- [%s](adr/%s)\n' "$(cell "$(heading "$f")")" "$(basename -- "$f")"
  done <<EOF
$(pages adr)
EOF
  if [ "$n" -eq 0 ]; then printf '_No decisions recorded yet._\n'; fi

  printf '\n%s\n' "$END_MARK"
}

# ------------------------------------------------------------------- main ---

if [ ! -f "$INDEX" ]; then
  if [ "$MODE" = check ]; then
    echo "FAIL  $INDEX does not exist" >&2
    exit 1
  fi
  mkdir -p -- "$DOCS"
  { printf '# Documentation\n\n'
    printf 'Every page here is written for a maintainer six months from now who opened\n'
    printf 'exactly this file from a search result and has nothing else loaded.\n\n'
    printf 'This index is generated. Run `scripts/gen-docs-index.sh` after adding or\n'
    printf 'renaming a page; `--check` fails if it is stale.\n\n'
    printf '%s\n%s\n' "$BEGIN_MARK" "$END_MARK"
  } > "$INDEX"
fi

grep -Fq "$BEGIN_MARK" "$INDEX" || { echo "FAIL  begin marker missing from $INDEX" >&2; exit 1; }
grep -Fq "$END_MARK"   "$INDEX" || { echo "FAIL  end marker missing from $INDEX" >&2; exit 1; }

tmp_block=$(mktemp); tmp_out=$(mktemp)
trap 'rm -f -- "$tmp_block" "$tmp_out"' EXIT

render > "$tmp_block"

awk -v begin="$BEGIN_MARK" -v end="$END_MARK" -v block="$tmp_block" '
  index($0, begin) == 1 { while ((getline line < block) > 0) print line; skip = 1; next }
  index($0, end)   == 1 { skip = 0; next }
  !skip
' "$INDEX" > "$tmp_out"

if cmp -s "$tmp_out" "$INDEX"; then
  if [ "$MODE" = check ]; then echo "ok    docs index is current"; else echo "ok    docs index unchanged"; fi
  exit 0
fi

if [ "$MODE" = check ]; then
  echo "FAIL  docs/README.md is stale -- run scripts/gen-docs-index.sh" >&2
  diff -u "$INDEX" "$tmp_out" | sed 's/^/      /' >&2 || true
  exit 1
fi

cat -- "$tmp_out" > "$INDEX"
echo "ok    wrote $INDEX"
