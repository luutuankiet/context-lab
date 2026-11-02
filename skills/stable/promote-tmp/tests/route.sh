#!/usr/bin/env bash
# End-to-end test of the promotion route in SKILL.md, on a synthetic topic folder
# in a throwaway repo and a throwaway $HOME. The values in its `.env` are
# invented. The test stands in for the operator twice: it approves the menu, and
# it merges the promote branch locally so `status` can turn true. The skill
# itself always stops at the menu.
#
#   ./tests/route.sh                     binary from ENVSCAN_BIN, PATH or ~/.local/bin
#   ENVSCAN_BIN=/path/envscan ./tests/route.sh
#
# Skips, passing, when no envscan binary is available; the launcher is not asked
# to download one.

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"

pass=0
fail=0
ok() { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL  %s\n' "$1"; fail=$((fail + 1)); [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; return 0; }

src_bin="${ENVSCAN_BIN:-}"
[ -n "$src_bin" ] || src_bin=$(command -v envscan 2>/dev/null || true)
[ -n "$src_bin" ] || { [ -x "$HOME/.local/bin/envscan" ] && src_bin="$HOME/.local/bin/envscan"; }
if [ -z "$src_bin" ] || [ ! -x "$src_bin" ]; then
  printf 'SKIP  route: no envscan binary (set ENVSCAN_BIN)\n'
  exit 0
fi

W=$(mktemp -d "${TMPDIR:-/tmp}/promote-route-test.XXXXXX")
trap 'rm -rf "$W"' EXIT
W=$(cd "$W" && pwd -P)

# A throwaway $HOME holding the binary where the launcher looks, so preflight
# finds it offline and the promotion record starts empty.
export HOME="$W/home"
mkdir -p "$HOME/.local/bin"
cp "$src_bin" "$HOME/.local/bin/envscan"
export PATH="$HOME/.local/bin:$PATH"
unset TYPESAFE_API_KEY || true
export GIT_CONFIG_GLOBAL="$W/gitconfig" GIT_CONFIG_NOSYSTEM=1
git config --global user.name test
git config --global user.email test
git config --global init.defaultBranch main

R="$W/repo"
T=tmp/20261101/demo
mkdir -p "$R"
cd "$R"
git init -q .
printf '.env\ntmp/\n' >.gitignore
cat >.env.example <<'EOF'
# what: invented client for this test | group: clients
CLIENT_A=
# what: invented host for this test | group: hosts
HOST_A=
EOF
printf 'CLIENT_A=zorblaxcorp\nHOST_A=quintar.example.net\n' >.env
mkdir -p docs
printf '# Demo\n\nThe fixture comes from `%s/make_fixture.sh`.\n' "$T" >docs/demo.md
git add .gitignore .env.example docs/demo.md
git commit -qm init

# The synthetic topic folder: one of each handling.
mkdir -p "$T"
cat >"$T/make_fixture.sh" <<'EOF'
#!/usr/bin/env bash
for i in 1 2 3; do printf 'row %s for zorblaxcorp\n' "$i"; done
EOF
chmod +x "$T/make_fixture.sh"
bash "$T/make_fixture.sh" >"$T/fixture.txt"
printf '# Notes\n\nThe service on quintar.example.net answered in 40 ms.\n' >"$T/notes.md"
printf 'started\nfinished\n' >"$T/run.log"
printf 'name,amount\nzorblaxcorp,12\n' >"$T/rows.csv"

E="$HOME/.local/bin/envscan"

# ---- Step 1: preflight, its refusals first.
out=$(bash "$SCRIPTS/preflight.sh" tmp/20261101 2>&1); rc=$?
[ $rc -eq 1 ] && [[ $out == *"not a topic folder"* ]] && ok "preflight refuses a folder that is not tmp/YYYYMMDD/<topic>" || no "preflight folder form" "rc=$rc $out"

mkdir -p "$W/bare"; (cd "$W/bare" && git init -q . && mkdir -p tmp/20261101/x && printf '.env\ntmp/\n' >.gitignore)
out=$(bash "$SCRIPTS/preflight.sh" "$W/bare/tmp/20261101/x" 2>&1); rc=$?
[ $rc -eq 1 ] && [[ $out == *"no commit"* ]] && ok "preflight refuses a repo with no commit" || no "preflight no commit" "rc=$rc $out"

(cd "$W/bare" && printf 'x\n' >f && git add f && git commit -qm f && printf '.env\n' >.gitignore)
out=$(bash "$SCRIPTS/preflight.sh" "$W/bare/tmp/20261101/x" 2>&1); rc=$?
[ $rc -eq 1 ] && [[ $out == *"tmp/ is not ignored"* ]] && ok "preflight refuses when tmp/ is not ignored" || no "preflight tmp ignore" "rc=$rc $out"

(cd "$W/bare" && printf '.env\ntmp/\n' >.gitignore)
out=$(bash "$SCRIPTS/preflight.sh" "$W/bare/tmp/20261101/x" 2>&1); rc=$?
[ $rc -eq 1 ] && [[ $out == *"no .env"* ]] && ok "preflight refuses when there is no .env" || no "preflight no .env" "rc=$rc $out"

(cd "$W/bare" && cp "$R/.env" . && printf '#!/bin/sh\nexit 0\n' >.git/hooks/pre-push && chmod +x .git/hooks/pre-push)
out=$(bash "$SCRIPTS/preflight.sh" "$W/bare/tmp/20261101/x" 2>&1); rc=$?
[ $rc -eq 2 ] && [[ $out == *"refused"* ]] && ok "preflight stops with exit 2 when another pre-push hook is there" || no "preflight hook refused" "rc=$rc $out"

out=$(bash "$SCRIPTS/preflight.sh" "$T" 2>&1); rc=$?
if [ $rc -eq 0 ] && [[ $out == *"envscan=$E"* ]] && [[ $out == *"folder=$T"* ]] && [[ $out == *"default=main"* ]] && [ -x .git/hooks/pre-push ]; then
  ok "preflight passes, prints the binary path, and installs pre-push"
else no "preflight pass" "rc=$rc $out"; fi

# ---- Step 2: the menu's mechanical half.
menu=$(bash "$SCRIPTS/menu.sh" "$E" "$T"); rc=$?
first=$(printf '%s\n' "$menu" | sed -n 1p)
count=$(printf '%s\n' "$menu" | grep -c .)
if [ $rc -eq 0 ] && [ "$count" -eq 5 ] && [[ $first == "1	none	"*"	text	$T/make_fixture.sh" ]] && [[ $menu == *"	data	$T/rows.csv"* ]]; then
  ok "menu lists all 5 files, the cited script first, the csv as data"
else no "menu first render" "rc=$rc
$menu"; fi
digest() { printf '%s\n' "$menu" | awk -F '	' -v p="$1" '$5 == p {print $3}'; }

# ---- Step 3: the whole-folder scan finds both values, including in the csv.
scan=$("$E" scan --known-only --no-ignore --json "$T" 2>/dev/null); rc=$?
if [ $rc -eq 1 ] && [[ $scan == *'"key": "CLIENT_A"'* ]] && [[ $scan == *'"key": "HOST_A"'* ]] && [[ $scan == *"$T/rows.csv"* ]]; then
  ok "folder scan reports CLIENT_A and HOST_A by key, the csv included"
else no "folder scan" "rc=$rc"; fi
"$E" scan --json "$T/make_fixture.sh" "$T/notes.md" "$T/fixture.txt" >/dev/null 2>&1; rc=$?
[ $rc -eq 1 ] && ok "judgement scan on named menu files runs (exit 1, leaks)" || no "judgement scan" "rc=$rc"

# ---- Step 5: the operator approves the menu (this test stands in). Before
# writing, step 2 is rerun; a file edited after the menu was drawn changes a
# digest and the menu is drawn again.
printf '\nA late line.\n' >>"$T/notes.md"
menu2=$(bash "$SCRIPTS/menu.sh" "$E" "$T")
old=$(digest "$T/notes.md")
new=$(printf '%s\n' "$menu2" | awk -F '	' -v p="$T/notes.md" '$5 == p {print $3}')
[ -n "$old" ] && [ "$old" != "$new" ] && ok "a file edited after approval shows a new digest, so the menu re-renders" || no "re-render on change" "$old $new"
menu=$menu2

# ---- Step 6: discard and refuse.
"$E" promotion add "$T/run.log" --sha256 "$(digest "$T/run.log")" --handling discard >/dev/null 2>&1; r1=$?
"$E" promotion add "$T/rows.csv" --sha256 "$(digest "$T/rows.csv")" --handling refuse >/dev/null 2>&1; r2=$?
[ $r1 -eq 0 ] && [ $r2 -eq 0 ] && ok "discard and refuse rows recorded" || no "discard/refuse" "$r1 $r2"

# ---- Step 7: branch.
git switch -q -c promote/demo main && ok "promote/demo branched from main" || no "branch"

# ---- Step 8: snapshot, write-up, cache, README, citation.
EV=evidence/20261101-demo
out=$(bash "$SCRIPTS/snapshot.sh" "$E" "$T/make_fixture.sh" "$EV/make_fixture.sh" 2>&1); rc=$?
if [ $rc -eq 0 ] && grep -q 'row %s for \$CLIENT_A' "$EV/make_fixture.sh" && [ -x "$EV/make_fixture.sh" ]; then
  ok "snapshot dehydrates the copy to \$CLIENT_A and scans it clean"
else no "snapshot" "rc=$rc $out"; fi

out=$(bash "$SCRIPTS/snapshot.sh" "$E" "$T/rows.csv" "$EV/rows.csv" 2>&1); rc=$?
[ $rc -eq 3 ] && [ ! -e "$EV/rows.csv" ] && ok "snapshot refuses a data file" || no "snapshot data file" "rc=$rc $out"

# A copy whose name still holds a value is not clean: the scan matches names.
out=$(bash "$SCRIPTS/snapshot.sh" "$E" "$T/make_fixture.sh" "$EV/zorblaxcorp-fixture.sh" 2>&1); rc=$?
[ $rc -eq 1 ] && [[ $out == *"not clean"* ]] && ok "snapshot stops when the copy's name still holds a value" || no "snapshot dirty name" "rc=$rc $out"
rm -f "$EV/zorblaxcorp-fixture.sh"

printf '# Demo service latency\n\nThe service on `$HOST_A` answered in 40 ms.\n' >docs/demo-latency.md
"$E" scan docs/demo-latency.md >/dev/null 2>&1; rc=$?
[ $rc -eq 0 ] && ok "write-up page authored fresh scans clean" || no "write-up scan" "rc=$rc"

cat >"$EV/README.md" <<EOF
# demo: snapshot, not maintained

Promoted from the 20261101/demo topic folder. Frozen when committed; read it as
evidence, never as current truth.

## make_fixture.sh
- was: \`make_fixture.sh\` in the 20261101/demo topic folder
- handling: snapshot
- pin: sha256 \`$(digest "$T/make_fixture.sh")\`
- captured: 2026-11-01T12:00:00Z
- rebuild: \`envscan hydrate $EV/make_fixture.sh | bash -s\`

## fixture.txt
- was: \`fixture.txt\` in the 20261101/demo topic folder
- handling: cache
- pin: sha256 \`$(digest "$T/fixture.txt")\`
- captured: 2026-11-01T12:00:00Z
- rebuild: \`envscan hydrate $EV/make_fixture.sh | bash -s\`
EOF
printf '# Demo\n\nThe fixture comes from `%s/make_fixture.sh`.\n' "$EV" >docs/demo.md
"$E" scan --no-ignore "$EV" docs >/dev/null 2>&1; rc=$?
[ $rc -eq 0 ] && ok "everything to be committed scans clean" || no "pre-commit scan" "rc=$rc"

# ---- Step 9: commit named paths only.
git add -- "$EV" docs/demo-latency.md docs/demo.md
git commit -qm "Promote the demo topic folder"
SHA=$(git rev-parse HEAD)
left=$(git ls-files --others --exclude-standard)
[ -z "$left" ] && ! git ls-files | grep -q '^tmp/' && ok "commit holds the named paths, nothing from tmp/" || no "commit scope" "$left"
cites=$(git grep -nE 'tmp/[0-9]{8}/' || true)
[ -z "$cites" ] && ok "no tracked text cites a tmp/ topic folder" || no "tmp citations" "$cites"

# ---- Step 10: record, after the commit.
r=0
"$E" promotion add "$T/make_fixture.sh" --sha256 "$(digest "$T/make_fixture.sh")" --handling snapshot --ref "$SHA" >/dev/null 2>&1 || r=1
"$E" promotion add "$T/notes.md" --sha256 "$(digest "$T/notes.md")" --handling write-up --ref "$SHA" >/dev/null 2>&1 || r=1
"$E" promotion add "$T/fixture.txt" --sha256 "$(digest "$T/fixture.txt")" --handling cache --ref "$SHA" >/dev/null 2>&1 || r=1
[ $r -eq 0 ] && ok "snapshot, write-up and cache rows recorded with the commit SHA" || no "record rest"

# ---- Step 11: the verdict, false until merged.
st=$("$E" promotion status "$T"); rc=$?
printf '%s\n' "$st" | sed 's/^/      | /'
if [ $rc -eq 0 ] && [[ $st == *"safe_to_clear: false"* ]]; then
  ok "status is false while the commit is only on promote/demo"
else no "status before merge" "$st"; fi
m=$(bash "$SCRIPTS/menu.sh" "$E" "$T"); rc=$?
[ $rc -eq 0 ] && [ -z "$m" ] && ok "menu is empty once every file is recorded" || no "menu empty"

# The operator merges (this test stands in).
git switch -q main && git merge -q --no-ff -m "Merge promote/demo" promote/demo
st=$("$E" promotion status "$T" --json)
[[ $st == *'"safe_to_clear": true'* ]] && [[ $st == *"$T/rows.csv"* ]] && ok "status turns true after the merge, listing the refused csv for deletion" || no "status after merge" "$st"

# ---- A changed file comes back to the menu.
printf 'One more line.\n' >>"$T/notes.md"
menu=$(bash "$SCRIPTS/menu.sh" "$E" "$T")
if [ "$(printf '%s\n' "$menu" | grep -c .)" -eq 1 ] && [[ $menu == *"	changed	"*"$T/notes.md" ]]; then
  ok "the changed file, and only it, is back on the menu as changed"
else no "changed file on menu" "$menu"; fi
st=$("$E" promotion status "$T" --json)
[[ $st == *'"safe_to_clear": false'* ]] && ok "status is false again while a file is changed" || no "status after change" "$st"
[ -n "$old" ] && "$E" promotion add "$T/notes.md" --sha256 "$old" --handling write-up --ref "$SHA" >/dev/null 2>&1; rc=$?
[ $rc -eq 3 ] && ok "promotion add with the menu's stale digest exits 3" || no "stale digest" "rc=$rc"

# ---- Rebuild check: a fresh checkout, one snapshot's rebuild command runs.
git clone -q "$R" "$W/fresh"
cp "$R/.env" "$W/fresh/.env"   # the operator rebuilds .env from .env.example
cd "$W/fresh"
cites=$(git grep -nE 'tmp/[0-9]{8}/' || true)
[ -z "$cites" ] && ok "fresh checkout: git grep finds no tmp/ citation" || no "fresh tmp citations" "$cites"
cmd=$(sed -n '/^## make_fixture.sh/,/^## /s/^- rebuild: `\(.*\)`$/\1/p' "$EV/README.md")
out=$(bash -c "$cmd" 2>&1); rc=$?
if [ $rc -eq 0 ] && [ "$out" = "$(cat "$R/$T/fixture.txt")" ]; then
  ok "fresh checkout: the snapshot's rebuild command reproduces the cached fixture"
else no "rebuild" "cmd=$cmd rc=$rc out=$out"; fi

# ---- Folded trees: moved whole before the scan, then the normal route. Each case has
# its own topic folder, so the row counts above stay as they are. Past the operator's
# merge above, so every case runs on main.
cd "$R"
SKILL="$HERE/../SKILL.md"
fill() { mkdir -p "$1"; i=0; while [ "$i" -lt "$2" ]; do printf 'x%s\n' "$i" >"$1/f$i.txt"; i=$((i + 1)); done; }
rows() { grep -c .; }
# The move SKILL.md prescribes. The guard is load-bearing: mv into an existing directory
# succeeds and nests the tree one level down.
move_tree() { [ ! -e "tmp/refs/$2" ] && mkdir -p tmp/refs && mv "$1" "tmp/refs/$2"; }

grep -qF '[ ! -e tmp/refs/<key> ] && mkdir -p tmp/refs && mv <dir> tmp/refs/<key>' "$SKILL" \
  && ok "the move tested here is the one SKILL.md prescribes" || no "SKILL.md move command"

M=tmp/20261101/mixed
fill "$M/image" 200
ln -s f0.txt "$M/image/link"
mkdir "$M/image/empty"
printf '# Loose notes\n' >"$M/notes.md"
m=$(bash "$SCRIPTS/menu.sh" "$E" "$M"); rc=$?
[ $rc -eq 0 ] && [ "$m" = "0	none	-	tree	$M/image	200" ] \
  && ok "first menu shows only the tree row, with its file count" || no "first menu tree row" "rc=$rc
$m"
n=$(bash "$SCRIPTS/menu.sh" "$E" "$M" --expand "$M/image" | rows)
[ "$n" -eq 201 ] && ok "--expand declines the fold: every file is a row" || no "expand declines" "$n"

mkdir -p tmp/refs/taken
move_tree "$M/image" taken; rc=$?
[ $rc -ne 0 ] && [ -d "$M/image" ] && [ ! -e tmp/refs/taken/image ] \
  && ok "the move refuses a target that exists, and nothing moved" || no "target exists" "rc=$rc"

git check-ignore -q tmp/refs/img-m && ok "tmp/refs/ is ignored" || no "tmp/refs ignored"
move_tree "$M/image" img-m; rc=$?
if [ $rc -eq 0 ] && [ ! -e "$M/image" ] && [ -f tmp/refs/img-m/f199.txt ] && [ -L tmp/refs/img-m/link ] && [ -d tmp/refs/img-m/empty ]; then
  ok "the tree moves whole, its symlink and empty directory included"
else no "whole move" "rc=$rc"; fi

m=$(bash "$SCRIPTS/menu.sh" "$E" "$M"); rc=$?
if [ $rc -eq 0 ] && [ "$(printf '%s\n' "$m" | rows)" -eq 1 ] && [[ $m == "0	none	"*"	text	$M/notes.md" ]]; then
  ok "re-run after the move gives the normal route: the loose file, with its digest"
else no "menu after move" "rc=$rc
$m"; fi

O=tmp/20261101/onlytree
fill "$O/image" 200
move_tree "$O/image" img-o
st=$("$E" promotion status "$O" --json); rc=$?
if [ $rc -eq 0 ] && [[ $st == *'"files": []'* ]] && [[ $st == *'"safe_to_clear": false'* ]] && [[ $st == *'the folder holds no regular files'* ]]; then
  ok "a folder that held only a tree: exit 0, no files, not safe to clear, and the reason"
else no "only-tree status" "rc=$rc $st"; fi
m=$(bash "$SCRIPTS/menu.sh" "$E" "$O"); rc=$?
[ $rc -eq 0 ] && [ -z "$m" ] && ok "that folder's menu is empty" || no "only-tree menu" "rc=$rc $m"
rmdir "$O"
err=$("$E" promotion status "$O" --json 2>&1 >/dev/null); rc=$?
[ $rc -eq 3 ] && [[ $err == *"No such file or directory"* ]] \
  && ok "the folder gone too: status exits 3, No such file or directory" || no "gone status" "rc=$rc $err"

# Citations of a moved tree. The sibling is the case a prefix rewrite breaks.
C=tmp/20261101/cited
fill "$C/tree" 200
printf 'n\n' >"$C/tree-notes.md"
printf 'dir %s/tree\nfile %s/tree/f1.txt\nslash %s/tree/\n' "$C" "$C" "$C" >docs/c.md
printf 'sibling %s/tree-notes.md\n' "$C" >docs/c2.md
printf 'draft %s/tree/f2.txt\n' "$C" >untracked.md
git add docs/c.md docs/c2.md
git commit -qm cites
m=$(bash "$SCRIPTS/menu.sh" "$E" "$C")
[ "$m" = "5	none	-	tree	$C/tree	200" ] \
  && ok "a tree's citations count untracked citers, and the sibling as the documented over-count" || no "tree inbound" "$m"
move_tree "$C/tree" img-c
n=$(git grep --untracked -n -F -e "$C/tree" -- . | rows)
[ "$n" -eq 5 ] && ok "the search finds the citations with their locations, untracked included" || no "citation search" "$n"

cp docs/c2.md "$W/c2.before"
sed -E "s#$C/tree#tmp/refs/img-c#g" docs/c2.md >docs/c2-blind.md
# Directory followed by / or a non-path character, per SKILL.md step 8.
for f in docs/c.md docs/c2.md untracked.md; do
  sed -E -e "s#$C/tree/([^[:space:]]+)#\$IMAGE_C@sha256:beef:\\1:1#g" \
    -e "s#$C/tree/?([^[:alnum:]._/-]|\$)#\$IMAGE_C\\1#g" "$f" >"$W/rewritten"
  cat "$W/rewritten" >"$f"
done
cmp -s docs/c2.md "$W/c2.before" && ok "the rewrite leaves sibling tree-notes.md alone" || no "sibling rewritten" "$(cat docs/c2.md)"
grep -qF '$IMAGE_C@sha256:beef:f1.txt:1' docs/c.md && ! grep -q "$C/tree/\|$C/tree\$" docs/c.md \
  && ok "the rewrite turns the tree's citations into the keyed form" || no "keyed citations" "$(cat docs/c.md)"

# Step 9's two commands: only rebuild commands on the reference page may name tmp/refs.
mkdir -p docs/reference
printf '| `IMAGE_C` | synthetic | `tar -xf image.tar -C tmp/refs/img-c` |\n' >docs/reference/reference-clones.md
git add docs/c2-blind.md docs/reference/reference-clones.md
step9() {
  git grep -nE 'tmp/([0-9]{8}|refs)/' -- . ':!docs/reference/reference-clones.md'
  git grep -nE 'tmp/([0-9]{8}/|refs/[^[:space:]`]+/)' -- docs/reference/reference-clones.md
}
hits=$(step9)
if [[ $hits == *"docs/c2-blind.md"*"tmp/refs/img-c-notes.md"* ]] && [[ $hits != *"reference-clones.md"* ]]; then
  ok "step 9 fails the blind rewrite's citation and allows the rebuild command"
else no "step 9 blind rewrite" "$hits"; fi
printf 'see `tmp/refs/img-c/f1.txt`\n' >>docs/reference/reference-clones.md
hits=$(step9)
[[ $hits == *"reference-clones.md"*"tmp/refs/img-c/f1.txt"* ]] \
  && ok "step 9 fails a path inside a tree, even on the reference page" || no "step 9 on the page" "$hits"
git reset -q
rm -f docs/c2-blind.md untracked.md

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
