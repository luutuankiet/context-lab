#!/usr/bin/env bash
# Regression tests for both scripts this skill ships that have behaviour worth
# pinning: scripts/topology-check.sh and scripts/audit.sh.
#
# The topology numbers below — 7 / 9 / 0 — were a claim in the build that script
# was ported from, with no fixtures behind them. They are a test now.
#
# The audit fixtures pin the ordered state gate and the two orthogonal flags. The
# `verified:` dates in them are fixed at 2020-01-01 and the threshold is passed
# per fixture, so no assertion here rots as the calendar moves.
#
#   ./tests/run.sh

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../scripts/topology-check.sh"
AUDIT="$HERE/../scripts/audit.sh"
FIX="$HERE/fixtures"

pass=0
fail=0

ok() {
  printf 'PASS  %s\n' "$1"
  pass=$((pass + 1))
}
no() {
  printf 'FAIL  %s\n' "$1"
  fail=$((fail + 1))
}

# Count the hits the check reports. "no hits." is zero.
hits_in() {
  local out="$1"
  if [[ $out == *"no hits."* ]]; then
    echo 0
  else
    sed -n 's/^\([0-9]\{1,\}\) hit(s).*/\1/p' <<<"$out" | tail -1
  fi
}

echo "======== the three fixtures"

out=$(TOPOLOGY_VOCAB=/nonexistent "$CHECK" "$FIX/dirty.md")
n=$(hits_in "$out")
[[ $n == 7 ]] && ok "dirty, generic classes only: 7 hits" || no "dirty: expected 7, got ${n:-none}"

out=$("$CHECK" --vocab "$FIX/vocab.txt" "$FIX/dirty-with-vocabulary.md")
n=$(hits_in "$out")
[[ $n == 9 ]] && ok "dirty with vocabulary: 9 hits" || no "dirty-with-vocabulary: expected 9, got ${n:-none}"

out=$("$CHECK" --vocab "$FIX/vocab.txt" "$FIX/clean.md")
n=$(hits_in "$out")
[[ $n == 0 ]] && ok "clean: 0 hits" || no "clean: expected 0, got ${n:-none}"

echo
echo "======== a missing vocabulary is loud, not clean"

out=$(TOPOLOGY_VOCAB=/nonexistent "$CHECK" "$FIX/dirty-with-vocabulary.md")
[[ $out == *"NO IDENTITY VOCABULARY FOUND"* ]] \
  && ok "missing vocabulary warns" || no "missing vocabulary did not warn"
n=$(hits_in "$out")
[[ $n == 7 ]] \
  && ok "and the two identity lines go unseen (7, not 9)" || no "expected 7 without vocabulary, got ${n:-none}"

echo
echo "======== an empty vocabulary is NOT RUN, not a pass"

empty="${TMPDIR:-/tmp}/topology-vocab-empty.$$"
printf '# only a comment\n\n' >"$empty"
out=$("$CHECK" --vocab "$empty" "$FIX/dirty-with-vocabulary.md")
rm -f "$empty"
[[ $out == *"IDENTITY VOCABULARY IS EMPTY"* ]] \
  && ok "empty vocabulary is reported as not run" || no "empty vocabulary was reported as clean"

echo
echo "======== resolution order: --vocab beats \$TOPOLOGY_VOCAB"

out=$(TOPOLOGY_VOCAB=/nonexistent "$CHECK" --vocab "$FIX/vocab.txt" "$FIX/dirty-with-vocabulary.md")
n=$(hits_in "$out")
[[ $n == 9 ]] && ok "--vocab wins over the environment" || no "--vocab did not win, got ${n:-none}"

echo
echo "======== it reports, it never refuses"

TOPOLOGY_VOCAB=/nonexistent "$CHECK" "$FIX/dirty.md" >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "exit 0 even with hits" || no "non-zero exit on hits — this check must not block"

echo
echo "======== audit.sh: the ordered state gate"

# summary <fixture> <stale-days> -- the one-line summary the scanner ends on.
summary() {
  "$AUDIT" --repo "$FIX/$1" --stale-days "$2" | grep -E '^(cold|structured|wired) '
}

out=$(summary cold 100000)
[[ $out == cold* ]] \
  && ok "no contract file -> cold" || no "cold fixture reported: $out"

out=$(summary structured 100000)
[[ $out == structured* ]] \
  && ok "contract + collections, no emitted skills -> structured" || no "structured fixture reported: $out"
[[ $out == *"2 missing emitted skills"* ]] \
  && ok "and it names both missing skills" || no "structured fixture did not name the missing skills"

out=$(summary wired 100000)
[[ $out == wired* ]] \
  && ok "all five checks pass -> wired" || no "wired fixture reported: $out"
[[ $out == *"no drift"* ]] \
  && ok "and it is clean" || no "wired fixture reported drift: $out"

echo
echo "======== audit.sh: the two flags never change the state"

out=$(summary drifted 1)
[[ $out == wired* ]] \
  && ok "an orphan page and stale dates leave the state wired" || no "drifted fixture reported: $out"
[[ $out == *"1 orphan page"* && $out == *"stale page"* ]] \
  && ok "and both drift causes are named" || no "drifted fixture summary was: $out"

out=$("$AUDIT" --repo "$FIX/drifted" --stale-days 1)
[[ $out == *"route:  references/route-repair.md"* ]] \
  && ok "drift on a wired repo routes to repair" || no "drifted fixture did not route to repair"

out=$("$AUDIT" --repo "$FIX/structured" --stale-days 100000)
[[ $out == *"route:  references/route-author-skills.md"* ]] \
  && ok "missing skills route to authoring" || no "structured fixture did not route to authoring"

echo
echo "======== audit.sh: it reports, it never fails"

for f in cold structured wired drifted; do
  "$AUDIT" --repo "$FIX/$f" --stale-days 1 >/dev/null 2>&1 \
    && ok "exit 0 on the $f fixture" || no "non-zero exit on $f — the scanner must not block"
done

echo
echo "======== audit.sh: the drifted collection's frontmatter is printed"

out=$("$AUDIT" --repo "$FIX/drifted" --stale-days 1)
[[ $out == *"title, summary, verified"* ]] \
  && ok "the guide schema is printed for the orphan page" \
  || no "no frontmatter schema printed for the drifted collection"

echo
echo "======== gen-docs-index.sh: every fixture index is current"

for f in structured wired drifted; do
  "$HERE/../scripts/gen-docs-index.sh" --check --repo "$FIX/$f" >/dev/null 2>&1 \
    && ok "$f index is current" || no "$f index is stale — regenerate the fixture"
done

echo
echo "======== projects.sh: private projects under tmp/projects/"

PROJECTS="$HERE/../scripts/projects.sh"
GEN="$HERE/../scripts/gen-docs-index.sh"
W=$(mktemp -d "${TMPDIR:-/tmp}/projects-test.XXXXXX")
trap 'rm -rf "$W"' EXIT
W=$(cd "$W" && pwd -P)

# A host repo that ignores tmp/, holding two projects with fixed file times.
# Times are set with `touch -t`, so no assertion depends on today's date.
H="$W/host"
mkdir -p "$H/tmp/projects/alpha/raw" "$H/tmp/projects/beta"
(cd "$H" && git init -q . && printf 'tmp/\n' >.gitignore)
printf '@AGENTS.md\n' >"$H/tmp/projects/alpha/CLAUDE.md"
printf '# Alpha\n\nAgent contract for alpha.\n' >"$H/tmp/projects/alpha/AGENTS.md"
printf '# Alpha\n\nWarehouse move for the alpha client.\n' >"$H/tmp/projects/alpha/README.md"
printf 'capture\n' >"$H/tmp/projects/alpha/raw/cap.txt"
printf '# Beta\n\nPricing study, internal only.\n' >"$H/tmp/projects/beta/AGENTS.md"
touch -t 202001010000 "$H/tmp/projects/alpha/CLAUDE.md" "$H/tmp/projects/alpha/AGENTS.md" "$H/tmp/projects/alpha/README.md"
touch -t 202003050000 "$H/tmp/projects/alpha/raw/cap.txt"
touch -t 202002020000 "$H/tmp/projects/beta/AGENTS.md"

out=$("$PROJECTS" --repo "$H" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "the listing exits 0" || no "the listing exited $rc: $out"
a=$(grep -n '^alpha ' <<<"$out" | cut -d: -f1)
b=$(grep -n '^beta ' <<<"$out" | cut -d: -f1)
[[ -n $a && -n $b && $a -lt $b ]] \
  && ok "newest project first: alpha before beta" || no "listing order was: $out"
row=$(grep '^alpha ' <<<"$out")
[[ $row == *"2020-03-05"* ]] \
  && ok "the date is the newest file anywhere in the project" || no "alpha row was: $row"
[[ $row =~ [[:space:]]4[[:space:]] ]] \
  && ok "the file count covers the whole project" || no "alpha row was: $row"
[[ $row == *"Warehouse move for the alpha client."* ]] \
  && ok "scope comes from README.md when there is one" || no "alpha row was: $row"
row=$(grep '^beta ' <<<"$out")
[[ $row == *"Pricing study, internal only."* ]] \
  && ok "scope falls back to AGENTS.md" || no "beta row was: $row"

mkdir -p "$H/tmp/projects/gamma"
printf '# Gamma\n\nFresh today.\n' >"$H/tmp/projects/gamma/AGENTS.md"
out=$("$PROJECTS" --repo "$H" --since 2 2>&1)
[[ $out == *gamma* && $out != *alpha* && $out != *beta* ]] \
  && ok "--since keeps only projects touched within that many days" || no "--since 2 printed: $out"
before=$(cd "$H" && find . -type f ! -path './.git/*' | LC_ALL=C sort | cksum)
"$PROJECTS" --repo "$H" >/dev/null 2>&1
after=$(cd "$H" && find . -type f ! -path './.git/*' | LC_ALL=C sort | cksum)
[[ $before == "$after" ]] && ok "the listing writes nothing" || no "the listing changed the tree"

echo
echo "======== projects.sh --init"

cp "$H/.git/info/exclude" "$W/exclude.before" 2>/dev/null || : >"$W/exclude.before"
out=$("$PROJECTS" --repo "$H" --init delta 2>&1); rc=$?
P="$H/tmp/projects/delta"
[[ $rc -eq 0 && -f $P/CLAUDE.md && -f $P/AGENTS.md ]] \
  && ok "--init creates CLAUDE.md and AGENTS.md" || no "--init delta: rc=$rc $out"
grep -q '@AGENTS\.md' "$P/CLAUDE.md" 2>/dev/null \
  && ok "CLAUDE.md imports @AGENTS.md" || no "CLAUDE.md does not import the contract"
grep -q 'a line in `TRACK.md`' "$P/AGENTS.md" 2>/dev/null \
  && ok "AGENTS.md carries the private wrap-up block" || no "AGENTS.md has no private block"
[[ ! -e $P/docs && ! -e $P/.claude && ! -e $P/.git ]] \
  && ok "nothing else is created: no docs/, no skills, no git" || no "--init created more than two files"
{ cmp -s "$H/.git/info/exclude" "$W/exclude.before" || [[ ! -e $H/.git/info/exclude && ! -s $W/exclude.before ]]; } \
  && ok "tmp/ already ignored: .git/info/exclude is untouched" || no ".git/info/exclude changed in a repo that ignores tmp/"
grep -q 'Point, do not copy' "$P/AGENTS.md" 2>/dev/null \
  && ok "AGENTS.md tells the reader to cite repository paths, not copy" || no "AGENTS.md has no point-do-not-copy rule"
row=$("$PROJECTS" --repo "$H" | grep '^delta ')
[[ $row == *delta && $row != *Indexed* ]] \
  && ok "an unfilled project's scope is its heading, not the standard block" || no "delta row was: $row"

printf 'mine\n' >>"$P/AGENTS.md"
sum=$(cksum <"$P/AGENTS.md")
out=$("$PROJECTS" --repo "$H" --init delta 2>&1); rc=$?
[[ $rc -ne 0 && $(cksum <"$P/AGENTS.md") == "$sum" ]] \
  && ok "--init refuses an existing slug and overwrites nothing" || no "second --init delta: rc=$rc $out"
out=$("$PROJECTS" --repo "$H" --init 'Not A Slug' 2>&1); rc=$?
[[ $rc -ne 0 && ! -e "$H/tmp/projects/Not A Slug" ]] \
  && ok "--init refuses a slug that is not kebab-case" || no "--init accepted a bad slug: $out"

# A host repo that does not ignore tmp/.
O="$W/open"
mkdir -p "$O" && (cd "$O" && git init -q .)
out=$("$PROJECTS" --repo "$O" --init epsilon 2>&1); rc=$?
[[ $rc -eq 0 ]] && grep -q '^tmp/projects/$' "$O/.git/info/exclude" 2>/dev/null \
  && ok "tmp/ not ignored: the guard appends to .git/info/exclude" || no "guard did not write the exclude: rc=$rc $out"
(cd "$O" && git check-ignore -q tmp/projects/epsilon/AGENTS.md) \
  && ok "and git now ignores the project" || no "the project is still visible to git"
[[ ! -e $O/.gitignore ]] \
  && ok "and no committed ignore file is written" || no "the guard wrote a .gitignore"
"$PROJECTS" --repo "$O" --init zeta >/dev/null 2>&1
[[ $(grep -c '^tmp/projects/$' "$O/.git/info/exclude") == 1 ]] \
  && ok "the guard appends once, not per project" || no "the exclude line was appended twice"

# Outside any git repository.
N="$W/plain"
mkdir -p "$N"
out=$(GIT_CEILING_DIRECTORIES="$W" "$PROJECTS" --repo "$N" --init eta 2>&1); rc=$?
[[ $rc -eq 0 && -f $N/tmp/projects/eta/AGENTS.md ]] \
  && ok "outside a git repository --init carries on" || no "--init outside git: rc=$rc $out"

echo
echo "======== projects.sh --reindex"

mkdir -p "$P/docs/traps"
printf -- '---\nsymptom: the export is empty on Mondays\narea: export\nverified: 2020-01-01\n---\n\n# Empty export\n' \
  >"$P/docs/traps/EMPTY_EXPORT.md"
touch -t 202001010000 "$P/AGENTS.md" "$H/tmp/projects/beta/AGENTS.md"
: >"$W/stamp"; touch -t 202101010000 "$W/stamp"
out=$("$PROJECTS" --repo "$H" --reindex 2>&1); rc=$?
[[ $rc -eq 0 ]] && grep -q 'EMPTY_EXPORT' "$P/docs/README.md" 2>/dev/null \
  && ok "--reindex generates the index of a project that has pages" || no "--reindex: rc=$rc $out"
[[ $P/AGENTS.md -nt $W/stamp ]] \
  && ok "and touches its AGENTS.md" || no "AGENTS.md was not touched"
[[ ! -e $H/tmp/projects/beta/docs && ! $H/tmp/projects/beta/AGENTS.md -nt $W/stamp ]] \
  && ok "a project with no pages is left alone" || no "--reindex touched a project with no pages"
"$GEN" --check --repo "$P" >/dev/null 2>&1 \
  && ok "the generator's --check passes on a project with one collection" || no "--check fails on a partial project"
touch -t 202001010000 "$P/AGENTS.md"
"$PROJECTS" --repo "$H" --reindex beta >/dev/null 2>&1
[[ ! $P/AGENTS.md -nt $W/stamp ]] \
  && ok "--reindex <slug> touches only the project named" || no "--reindex beta touched delta"
out=$("$PROJECTS" --repo "$H" --reindex no-such-project 2>&1); rc=$?
[[ $rc -ne 0 ]] && ok "--reindex of an unknown slug fails" || no "--reindex accepted an unknown slug"

echo
echo "======== audit.sh and projects"

out=$("$AUDIT" --repo "$P" --stale-days 100000 2>&1); rc=$?
[[ $rc -eq 0 ]] && grep -Eq '^structured ' <<<"$out" \
  && ok "a non-git project with one collection has a defined state: structured" || no "audit on a project: rc=$rc $out"
out=$(GIT_CEILING_DIRECTORIES="$W" "$AUDIT" --repo "$N/tmp/projects/eta" 2>&1); rc=$?
[[ $rc -eq 0 ]] && grep -Eq '^structured ' <<<"$out" \
  && ok "and so does a fresh project outside any git repository" || no "audit outside git: rc=$rc $out"

mkdir -p "$H/tmp/projects/notes"
printf 'x\n' >"$H/tmp/projects/notes/AGENTS.md"
out=$("$AUDIT" --repo "$H" 2>&1)
[[ $out == *" 0 bytes unpromoted"* && $out != *"tmp/projects/notes"* ]] \
  && ok "the root scanner does not count a notes-named folder under tmp/projects/" \
  || no "root audit counted a project: $(grep -E 'unpromoted' <<<"$out")"
mkdir -p "$H/tmp/notes"; printf 'x\n' >"$H/tmp/notes/a.md"
out=$("$AUDIT" --repo "$H" 2>&1)
[[ $out == *"tmp/notes -- "* ]] \
  && ok "while a notes folder elsewhere under tmp/ still counts" || no "check 8 stopped seeing tmp/notes"

echo
echo "======== $pass passed, $fail failed"
[[ $fail -eq 0 ]]
