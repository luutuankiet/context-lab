#!/usr/bin/env bash
#
# Assert the invariant this repo publishes: it contains zero third-party bytes.
#
#   ./scripts/third-party-gate.sh           check, exit non-zero on a finding
#   ./scripts/third-party-gate.sh --verbose  also print what was compared
#
# Third-party skills are subscribed to, never copied in -- see
# docs/third-party-skills.md. This script is what makes that claim checkable.
#
# The comparison corpus is the upstream package as already cached on this host
# by `claude plugin install`, so the check needs no network and vendors nothing.
# Every version present in the cache is compared, not just the newest: a copy
# taken from an older release is still a copy.
#
# On a host with no cached copy the script SKIPS loudly (exit 0) rather than
# passing quietly. A check that cannot see its corpus has not verified anything,
# and saying so is the whole point.
#
# Not wired into CI by design. The methodology this repo publishes is one an
# agent applies at authoring time; a repo that fails somebody's build to teach
# them a practice has announced the practice.

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
VERBOSE=0
[ "${1:-}" = "--verbose" ] && VERBOSE=1

# Share of a file's substantial lines that must also appear upstream before it
# is called a partial copy, and the minimum number of substantial lines a file
# needs before the ratio means anything at all.
OVERLAP_PCT=30
MIN_LINES=10
LONG_LINE=60

RED=''; GRN=''; YLW=''; DIM=''; RST=''
if [ -t 1 ]; then RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'; fi
ok()   { printf '%s  ok%s   %s\n' "$GRN" "$RST" "$1"; }
bad()  { printf '%s fail%s   %s\n' "$RED" "$RST" "$1"; FAILED=1; }
warn() { printf '%s skip%s   %s\n' "$YLW" "$RST" "$1"; }
note() { [ "$VERBOSE" -eq 1 ] && printf '%s       %s%s\n' "$DIM" "$1" "$RST" || true; }

FAILED=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# sha256sum on Linux, shasum -a 256 on Darwin. m3 is a Mac.
if command -v sha256sum >/dev/null 2>&1; then hash_stdin() { sha256sum | cut -c1-16; }
elif command -v shasum   >/dev/null 2>&1; then hash_stdin() { shasum -a 256 | cut -c1-16; }
else echo "no sha256 tool on PATH" >&2; exit 2; fi

# A file's comparable content: YAML frontmatter dropped, trailing whitespace
# stripped, blank lines removed. Frontmatter is excluded deliberately -- the one
# copy this repo actually shipped was upstream prose with fresh frontmatter
# bolted on, which any byte-exact check would have called clean.
norm() {
  awk '
    BEGIN { fm = 0 }
    NR == 1 && $0 == "---" { fm = 1; next }
    fm == 1 && $0 == "---" { fm = 2; next }
    fm == 1 { next }
    { sub(/[ \t]+$/, ""); if (length($0) > 0) print }
  ' "$1"
}

long_lines() {
  awk -v n="$LONG_LINE" '{ sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); if (length($0) > n) print }' "$1" | sort -u
}

# ------------------------------------------------------ build the corpus -----

UPSTREAMS=0
: > "$TMP/up.norm"
: > "$TMP/up.lines.raw"

for d in "$CLAUDE_DIR"/plugins/cache/*/mattpocock-skills/*/; do
  [ -d "$d" ] || continue
  UPSTREAMS=$((UPSTREAMS + 1))
  note "corpus: ${d#$CLAUDE_DIR/plugins/cache/}"
  # -print0 would be safer, but no upstream path has ever contained a space and
  # bash 3.2 has no readarray to consume it with.
  find "$d" -type f -name '*.md' | while read -r f; do
    printf '%s\t%s\n' "$(norm "$f" | hash_stdin)" "${f#$d}"
  done >> "$TMP/up.norm"
  find "$d" -type f -name '*.md' -exec cat {} + >> "$TMP/up.lines.raw"
done

if [ "$UPSTREAMS" -eq 0 ]; then
  warn "no upstream cached under $CLAUDE_DIR/plugins/cache -- nothing to compare against"
  echo
  echo "    Install it first, then re-run:"
  echo "      claude plugin install mattpocock-skills@claude-plugins-official"
  exit 0
fi

long_lines "$TMP/up.lines.raw" > "$TMP/up.lines"
note "$(wc -l < "$TMP/up.norm" | tr -d ' ') upstream files, $(wc -l < "$TMP/up.lines" | tr -d ' ') distinct substantial lines, from $UPSTREAMS cached version(s)"

# ------------------------------------------------------------ the checks -----

cd "$REPO"

# Tracked files AND untracked-but-not-ignored ones. Tracked alone would clear a
# copy that has been pasted in but not yet `git add`ed -- which is exactly the
# moment you want to hear about it, rather than one commit later.
if git rev-parse --git-dir >/dev/null 2>&1; then
  list_files() { git ls-files --cached --others --exclude-standard; }
else
  list_files() { find . -type f | sed 's|^\./||'; }
fi

list_files | while read -r f; do
  case "$f" in *.md) ;; *) continue ;; esac
  [ -f "$f" ] || continue

  h="$(norm "$f" | hash_stdin)"
  m="$(awk -F'\t' -v h="$h" '$1 == h { print $2; exit }' "$TMP/up.norm")"
  if [ -n "$m" ]; then
    echo "COPY|$f|$m" >> "$TMP/findings"
    continue
  fi

  long_lines "$f" > "$TMP/f.lines"
  tot=$(wc -l < "$TMP/f.lines" | tr -d ' ')
  [ "$tot" -lt "$MIN_LINES" ] && continue
  shared=$(comm -12 "$TMP/f.lines" "$TMP/up.lines" | wc -l | tr -d ' ')
  pct=$((shared * 100 / tot))
  [ "$pct" -ge "$OVERLAP_PCT" ] && echo "PARTIAL|$f|$shared/$tot lines ($pct%)" >> "$TMP/findings"
done

# The loop above runs in a subshell (pipe), so findings come back through the
# file rather than through a variable.
if [ -f "$TMP/findings" ]; then
  while IFS='|' read -r kind file detail; do
    case "$kind" in
      COPY)    bad "$file is upstream/$detail, republished" ;;
      PARTIAL) bad "$file shares $detail with upstream" ;;
    esac
  done < "$TMP/findings"
else
  ok "zero third-party bytes across $(list_files | grep -c '\.md$' | tr -d ' ') markdown files"
fi

# The plugin id is hardcoded in install.sh, at the point where it is used. This
# asserts the record in docs/ names the same one, so the two cannot drift apart
# without anyone noticing -- a consistency check, deliberately not a parser.
PLUGIN_ID="$(awk -F'"' '/local plugin=/ { print $2; exit }' "$REPO/install.sh")"
if [ -z "$PLUGIN_ID" ]; then
  bad "could not read the plugin id out of install.sh"
elif grep -F -q "$PLUGIN_ID" "$REPO/docs/third-party-skills.md"; then
  ok "install.sh and docs/third-party-skills.md name the same upstream ($PLUGIN_ID)"
else
  bad "install.sh installs $PLUGIN_ID, which docs/third-party-skills.md does not record"
fi

echo
[ "$FAILED" -eq 0 ] || { echo "See docs/third-party-skills.md for what this invariant is and why."; exit 1; }
