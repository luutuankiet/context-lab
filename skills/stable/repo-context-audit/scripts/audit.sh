#!/usr/bin/env bash
#
# audit.sh -- eight filesystem checks over a repo's own agent context.
#
#   audit.sh [--repo DIR] [--stale-days N] [--notes-dir NAME]...
#
# No model is involved and nothing is written. Every check is a file test, a
# grep for a marker, or an arithmetic date comparison. The output is the whole
# interface: a state, two orthogonal flags, and the route to read next.
#
# State is an ORDERED GATE, not a set:
#
#   cold        check 1 or 2 fails            -- there is no contract to build on
#   structured  1 and 2 pass, 3/4/5 does not  -- the fall-through
#   wired       1 through 5 pass
#
# Checks 6, 7 and 8 never touch state. 6 and 7 set the drift flag; 8 sets the
# notes flag. A fully wired repo accumulates unpromoted notes forever -- that is
# the steady state, not a regression, which is why it is a flag and not a stage.
#
# Written for bash 3.2: no associative arrays, no mapfile, no ${x,,}.

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

REPO=""
STALE_DAYS=180
EXTRA_NOTES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)       REPO="$2"; shift 2 ;;
    --stale-days) STALE_DAYS="$2"; shift 2 ;;
    --notes-dir)  EXTRA_NOTES="$EXTRA_NOTES $2"; shift 2 ;;
    -h|--help)    sed -n '2,20p' "$0"; exit 0 ;;
    *)            echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$REPO" ]; then
  REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
REPO="$(cd -- "$REPO" && pwd)"

# Directory names that hold agent working notes. Name-based on purpose: "every
# ignored directory containing markdown" also matches build output, vendored
# trees and scratch worktrees, and a scanner that cries wolf gets switched off.
NOTE_DIRS="gsd-lite gsd .gsd-lite .gsd .agent .agents agent-notes .ai .notes notes journal .journal memory .memory worklog$EXTRA_NOTES"

SEAM='<!-- Standard block.'
BEGIN_MARK='<!-- BEGIN GENERATED INDEX'
END_MARK='<!-- END GENERATED INDEX -->'
EMITTED_SKILLS=".claude/skills/codebase-map/SKILL.md .claude/skills/repo-maintenance/SKILL.md"

TODAY="$(date +%Y-%m-%d)"

# --------------------------------------------------------------- reporting ---

C1=ok; C2=ok; C3=ok; C4=ok; C5=ok; C6=ok; C7=ok; C8=ok
D1=""; D2=""; D3=""; D4=""; D5=""; D6=""; D7=""; D8=""
DRIFT_COLLECTIONS=""; NOTES_BYTES=0
missing_skills=0; orphans=0; stale=0

# note <n> <line> -- append a detail line to check n's report.
note() {
  case "$1" in
    1) D1="$D1$2
" ;;
    2) D2="$D2$2
" ;;
    3) D3="$D3$2
" ;;
    4) D4="$D4$2
" ;;
    5) D5="$D5$2
" ;;
    6) D6="$D6$2
" ;;
    7) D7="$D7$2
" ;;
    8) D8="$D8$2
" ;;
  esac
}

# drifted <collection> -- record that a collection's schema is worth printing.
drifted() {
  case " $DRIFT_COLLECTIONS " in
    *" $1 "*) ;;
    *) DRIFT_COLLECTIONS="$DRIFT_COLLECTIONS $1" ;;
  esac
}

# days <YYYY-MM-DD> -- a day number, computed in awk so no `date` flag
# portability question arises between GNU and BSD.
days() {
  awk -v d="$1" 'BEGIN {
    n = split(d, p, "-")
    if (n != 3) { print -1; exit }
    y = p[1] + 0; m = p[2] + 0; dd = p[3] + 0
    if (y == 0 || m == 0 || dd == 0) { print -1; exit }
    a = int((14 - m) / 12); yy = y + 4800 - a; mm = m + 12 * a - 3
    print dd + int((153 * mm + 2) / 5) + 365 * yy + int(yy / 4) \
          - int(yy / 100) + int(yy / 400) - 32045
  }'
}

# fmkey <file> <key> -- one flat `key: value` from the leading `---` block.
fmkey() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR == 1                { next }
    $0 == "---"            { exit }
    { i = index($0, ":"); if (i == 0) next
      k = substr($0, 1, i - 1); v = substr($0, i + 1)
      gsub(/^[ \t]+|[ \t]+$/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", v)
      sub(/^"/, "", v); sub(/"$/, "", v)
      if (k == key) { print v; exit } }
  ' "$1" 2>/dev/null
}

collection_pages() {
  [ -d "$REPO/docs/$1" ] || return 0
  find "$REPO/docs/$1" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | LC_ALL=C sort
}

top_level_pages() {
  [ -d "$REPO/docs" ] || return 0
  find "$REPO/docs" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | LC_ALL=C sort
}

TODAY_DAYS="$(days "$TODAY")"

# ------------------------------------------------------- 1. import present ---

if [ -f "$REPO/CLAUDE.md" ] && grep -q '@AGENTS\.md' "$REPO/CLAUDE.md"; then
  note 1 "CLAUDE.md imports @AGENTS.md"
elif [ -f "$REPO/AGENTS.md" ]; then
  C1=FAIL; note 1 "AGENTS.md exists but no CLAUDE.md bridges to it"
else
  C1=FAIL; note 1 "no CLAUDE.md containing @AGENTS.md"
fi

# ------------------------------------------- 2. contract file and its seam ---

if [ ! -f "$REPO/AGENTS.md" ]; then
  C2=FAIL; note 2 "AGENTS.md does not exist"
else
  size=$(wc -c < "$REPO/AGENTS.md" | tr -d ' ')
  if grep -Fq "$SEAM" "$REPO/AGENTS.md"; then
    note 2 "AGENTS.md, $size bytes, appendable seam present"
  else
    C2=FAIL; note 2 "AGENTS.md, $size bytes, no appendable seam marker"
  fi
  if [ "$size" -gt 4096 ]; then
    note 2 "over the 4 KB always-loaded budget by $((size - 4096)) bytes"
  fi
fi

# ------------------------------------------------------- 3. doc collections --

counts=""
for c in architecture traps reference adr; do
  n=$(collection_pages "$c" | grep -c . || true)
  counts="$counts$c $n, "
  if [ ! -d "$REPO/docs/$c" ]; then
    C3=FAIL; note 3 "docs/$c/ does not exist"
  elif [ "$n" -eq 0 ]; then
    C3=FAIL; note 3 "docs/$c/ is empty"
  fi
done
guides=0
for f in $(top_level_pages); do
  [ -n "$(fmkey "$f" title)" ] && guides=$((guides + 1))
done
note 3 "${counts}guides $guides"

# ----------------------------------------------------- 4. index is current ---

if [ ! -f "$REPO/docs/README.md" ]; then
  C4=FAIL; note 4 "docs/README.md does not exist"
elif ! grep -Fq "$BEGIN_MARK" "$REPO/docs/README.md" \
  || ! grep -Fq "$END_MARK"   "$REPO/docs/README.md"; then
  C4=FAIL; note 4 "docs/README.md carries no generated-index markers"
else
  if [ -x "$REPO/scripts/gen-docs-index.sh" ]; then
    genlabel="scripts/gen-docs-index.sh --check"
    if (cd "$REPO" && ./scripts/gen-docs-index.sh --check >/dev/null 2>&1); then
      note 4 "current, per $genlabel"
    else
      C4=FAIL; note 4 "stale -- run $genlabel and commit the result"
    fi
  else
    genlabel="the generator shipped with this skill"
    if "$HERE/gen-docs-index.sh" --check --repo "$REPO" >/dev/null 2>&1; then
      note 4 "current, per $genlabel"
    else
      C4=FAIL; note 4 "stale, and the repo has no generator of its own"
    fi
  fi
fi

# ------------------------------------------------------ 5. emitted skills ----

for s in $EMITTED_SKILLS; do
  if [ ! -f "$REPO/$s" ]; then
    C5=FAIL; missing_skills=$((missing_skills + 1)); note 5 "$s missing"
    continue
  fi
  block=$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    index($0, b) == 1 { on = 1; next }
    index($0, e) == 1 { on = 0 }
    on && NF' "$REPO/$s")
  case "$block" in
    ""|*"_None yet._"*|*"_No pages yet._"*)
      C5=FAIL; missing_skills=$((missing_skills + 1))
      note 5 "$s carries an empty generated index" ;;
    *)
      note 5 "$s ok" ;;
  esac
done

# --------------------------------------------------------- 6. orphan pages ---

for f in $(top_level_pages); do
  if [ -z "$(fmkey "$f" title)" ] || [ -z "$(fmkey "$f" summary)" ]; then
    C6=FAIL; orphans=$((orphans + 1))
    note 6 "docs/$(basename -- "$f") -- claimed by no collection"
    drifted guides
  fi
done
[ "$orphans" -eq 0 ] && note 6 "none"

# --------------------------------------------------------- 7. stale dates ----

for c in architecture traps reference; do
  for f in $(collection_pages "$c"); do
    bad=""
    v=$(fmkey "$f" verified)
    if [ -z "$v" ]; then
      bad="no verified: date"
    else
      d=$(days "$v")
      if [ "$d" -lt 0 ]; then
        bad="unparseable verified: $v"
      elif [ $((TODAY_DAYS - d)) -gt "$STALE_DAYS" ]; then
        bad="verified $v, $((TODAY_DAYS - d)) days ago"
      fi
    fi
    if [ -n "$bad" ]; then
      C7=FAIL; stale=$((stale + 1))
      note 7 "docs/$c/$(basename -- "$f") -- $bad"
      drifted "$c"
    fi
  done
done
[ "$stale" -eq 0 ] && note 7 "none past $STALE_DAYS days"

# ------------------------------------------------------ 8. unpromoted notes --

found_notes=0
for name in $NOTE_DIRS; do
  for d in $(find "$REPO" -maxdepth 3 -type d -name "$name" ! -path '*/.git/*' 2>/dev/null | LC_ALL=C sort); do
    if git -C "$REPO" ls-files --error-unmatch "$d" >/dev/null 2>&1; then
      continue   # already tracked: it is documentation, not working notes
    fi
    kb=$(du -sk "$d" 2>/dev/null | awk '{print $1}')
    [ -z "$kb" ] && continue
    bytes=$((kb * 1024))
    NOTES_BYTES=$((NOTES_BYTES + bytes))
    found_notes=$((found_notes + 1))
    files=$(find "$d" -type f 2>/dev/null | grep -c . || true)
    note 8 "${d#"$REPO"/} -- ~$kb KB across $files files, untracked"
  done
done
if [ "$found_notes" -eq 0 ]; then
  note 8 "none found"
else
  C8=FAIL
fi

# ------------------------------------------------------- state and routing ---

if [ "$C1" = FAIL ] || [ "$C2" = FAIL ]; then
  STATE=cold
elif [ "$C3" = FAIL ] || [ "$C4" = FAIL ] || [ "$C5" = FAIL ]; then
  STATE=structured
else
  STATE=wired
fi

DRIFT=no
[ "$C6" = FAIL ] && DRIFT=yes
[ "$C7" = FAIL ] && DRIFT=yes
NOTES=no
[ "$C8" = FAIL ] && NOTES=yes

# The primary route follows state, with one tie-break: a repo whose emitted
# skills are present and populated is not an authoring job even when it falls
# out of `wired`, because the only thing wrong is the index or a collection.
case "$STATE" in
  cold)       ROUTE=references/route-setup.md ;;
  structured) if [ "$C5" = ok ]; then ROUTE=references/route-repair.md
              else ROUTE=references/route-author-skills.md; fi ;;
  wired)      if [ "$DRIFT" = yes ]; then ROUTE=references/route-repair.md
              else ROUTE=references/route-wrapup.md; fi ;;
esac

THEN=""
if [ "$DRIFT" = yes ] && [ "$ROUTE" != references/route-repair.md ]; then
  THEN="references/route-repair.md"
fi
if [ "$NOTES" = yes ]; then
  [ -n "$THEN" ] && THEN="$THEN, "
  THEN="${THEN}references/route-promote.md"
fi

# ----------------------------------------------------------------- output ----

# row <n> <status> <details> <label>
row() {
  printf '  %s  %-24s %-4s  ' "$1" "$4" "$2"
  printf '%s' "$3" | awk -v pad='                                    ' '
    NF { if (seen++) printf "%s%s\n", pad, $0; else print }
    END { if (!seen) print "" }'
}

printf '\n==> repo-context-audit  %s  (%s)\n\n' "$REPO" "$TODAY"
row 1 "$C1" "$D1" "always-loaded import"
row 2 "$C2" "$D2" "contract file + seam"
row 3 "$C3" "$D3" "doc collections"
row 4 "$C4" "$D4" "generated index"
row 5 "$C5" "$D5" "emitted skills"
row 6 "$C6" "$D6" "orphan pages"
row 7 "$C7" "$D7" "stale verified dates"
row 8 "$C8" "$D8" "unpromoted working notes"

# The drift clause, in the words the summary line uses.
plural() { [ "$1" -eq 1 ] || printf 's'; }

# Parts are joined with commas and a final "and", so that the one-line summary
# reads as a sentence a human would write rather than as a list of flags.
PARTS=""
add_part() {
  if [ -z "$PARTS" ]; then PARTS="$1"
  else PARTS="$PARTS|$1"; fi
}
[ "$missing_skills" -gt 0 ] && add_part "$missing_skills missing emitted skill$(plural "$missing_skills")"
[ "$orphans"        -gt 0 ] && add_part "$orphans orphan page$(plural "$orphans")"
[ "$stale"          -gt 0 ] && add_part "$stale stale page$(plural "$stale")"
[ "$C4" = FAIL ]            && add_part "a stale index"
[ "$C3" = FAIL ]            && add_part "a missing collection"

DRIFT_PARTS=$(printf '%s' "$PARTS" | awk -F'|' '{
  for (i = 1; i <= NF; i++) {
    if (i == 1)       s = $i
    else if (i == NF) s = s " and " $i
    else              s = s ", " $i
  }
  print s
}')

printf '\n%s — %s bytes unpromoted' "$STATE" "$NOTES_BYTES"
if [ -n "$DRIFT_PARTS" ]; then printf ', drift on %s\n' "$DRIFT_PARTS"; else printf ', no drift\n'; fi

# The frontmatter schema for whatever actually drifted, printed here so the
# repair route never has to load the format page to put back a missing key.
if [ -n "$DRIFT_COLLECTIONS" ]; then
  printf '\nfrontmatter expected by the collections that drifted:\n'
  for c in $DRIFT_COLLECTIONS; do
    case "$c" in
      architecture) printf '  docs/architecture/kebab-name.md   title, covers, verified\n' ;;
      traps)        printf '  docs/traps/SCREAMING_SNAKE.md     symptom, area, verified\n' ;;
      reference)    printf '  docs/reference/kebab-name.md      title, summary, verified\n' ;;
      guides)       printf '  docs/kebab-name.md   (guide)      title, summary, verified\n' ;;
    esac
  done
  printf '  covers: and symptom: are search keys — the words someone in trouble would type.\n'
fi

printf '\nroute:  %s\n' "$ROUTE"
[ -n "$THEN" ] && printf 'then:   %s\n' "$THEN"
printf '\n'
exit 0
