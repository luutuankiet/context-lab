#!/usr/bin/env bash
# Tests of scripts/menu.sh in a throwaway repo and throwaway $HOME. Every tree here is
# invented. Skips, passing, when no envscan binary is available.
#
#   ./tests/menu.sh                     binary from ENVSCAN_BIN, PATH or ~/.local/bin
#   ENVSCAN_BIN=/path/envscan ./tests/menu.sh
#   MENU_SH=/path/menu.sh ./tests/menu.sh    test another copy; mutants.sh does

set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
P=${MENU_SH:-$HERE/../scripts/menu.sh}

SRC=${ENVSCAN_BIN:-}
[ -n "$SRC" ] || SRC=$(command -v envscan 2>/dev/null || true)
[ -n "$SRC" ] || { [ -x "$HOME/.local/bin/envscan" ] && SRC="$HOME/.local/bin/envscan"; }
if [ -z "$SRC" ] || [ ! -x "$SRC" ]; then
  printf 'SKIP  menu: no envscan binary (set ENVSCAN_BIN)\n'
  exit 0
fi

W=$(mktemp -d "${TMPDIR:-/tmp}/menu-test.XXXXXX")
trap 'rm -rf "$W"' EXIT
W=$(cd "$W" && pwd -P)
export HOME="$W/home"
mkdir -p "$HOME/.local/bin" "$W/menu-tmp"
cp "$SRC" "$HOME/.local/bin/envscan"
E="$HOME/.local/bin/envscan"
export GIT_CONFIG_GLOBAL="$W/gitconfig" GIT_CONFIG_NOSYSTEM=1
export TMPDIR="$W/menu-tmp"
git config --global user.name test
git config --global user.email test
git config --global init.defaultBranch main

pass=0
fail=0
ok() { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed -n '1,8p' | sed 's/^/      /'; fail=$((fail + 1)); return 0; }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "want: $2
got:  $3"; fi; }
TAB=$(printf '\t')

R="$W/repo"
mkdir -p "$R"
cd "$R" || exit 2
git init -q .
printf 'tmp/\nignored.md\n' >.gitignore
mkdir docs
git add .gitignore
git commit -qm init

# fill <dir> <count>: count small text files in dir.
fill() { mkdir -p "$1"; i=0; while [ "$i" -lt "$2" ]; do printf 'x%s\n' "$i" >"$1/f$i.txt"; i=$((i + 1)); done; }
topic() { T="tmp/20990101/$1"; mkdir -p "$T"; }
menu() { bash "$P" "$E" "$@"; }
rows() { grep -c . || true; }
# The path goes through ENVIRON: BSD awk's -v drops the backslash from one holding \s.
inb() { printf '%s\n' "$1" | INB_PATH=$2 awk -F '\t' '$5 == ENVIRON["INB_PATH"] {print $1}'; }
digest() { "$E" promotion status "$1" --json | awk -v p="$2" 'index($0, "\"path\": \"" p "\"") {f = 1; next} f && /sha256/ {gsub(/[",]/, "", $2); print $2; exit}'; }
record() { "$E" promotion add "$2" --sha256 "$(digest "$1" "$2")" --handling discard >/dev/null; }

# ---- Nothing folds: one row per file, as before folding existed.
topic flat
printf 'a\n' >"$T/a.py"; printf 'r\n' >"$T/rows.csv"; printf 'u\n' >"$T/UP.PARQUET"; printf 'n\n' >"$T/notes.md"
mkdir -p "$T/sub dir"; printf 's\n' >"$T/sub dir/x y.txt"
mkdir -p "$T/repo1"; git -C "$T/repo1" init -q .
printf 'k\n' >"$T/done.txt"
record "$T" "$T/done.txt"
printf 'see %s/a.py\nand %s/a.py\nand %s/sub dir/x y.txt\n' "$T" "$T" "$T" >docs/flat.md
git add docs/flat.md; git commit -qm flat
a=$(menu "$T"); rc=$?
eq "flat: exit 0" 0 "$rc"
eq "flat: a row per unrecorded file and clone" 6 "$(printf '%s\n' "$a" | rows)"
eq "flat: recorded file hidden" 0 "$(printf '%s\n' "$a" | grep -c 'done.txt')"
eq "flat: clone is repo, digest -" "0${TAB}none${TAB}-${TAB}repo${TAB}$T/repo1" "$(printf '%s\n' "$a" | grep repo1)"
eq "flat: file row exact" "2${TAB}none${TAB}$(digest "$T" "$T/a.py")${TAB}text${TAB}$T/a.py" "$(printf '%s\n' "$a" | sed -n 1p)"
eq "flat: csv is data" data "$(printf '%s\n' "$a" | awk -F '\t' '/rows.csv/ {print $4}')"
eq "flat: uppercase extension is data" data "$(printf '%s\n' "$a" | awk -F '\t' '/UP.PARQUET/ {print $4}')"

# ---- A file envscan will not scan for size is data, whatever its extension.
topic large
mkdir -p "$T"
awk 'BEGIN {for (i = 0; i < 200000; i++) print "012345678"}' >"$T/exact.json"
awk 'BEGIN {for (i = 0; i < 199999; i++) print "012345678"; print "01234567"}' >"$T/under.json"
out=$(menu "$T")
eq "large: 2,000,000 bytes with a text extension is data" data "$(printf '%s\n' "$out" | awk -F '\t' '/exact.json/ {print $4}')"
eq "large: one byte under stays text" text "$(printf '%s\n' "$out" | awk -F '\t' '/under.json/ {print $4}')"

# ---- Threshold.
topic t199; fill "$T/d" 199
eq "threshold: one file under the default stays as rows" 199 "$(menu "$T" | rows)"
eq "threshold: MENU_TREE_MIN lowers it" "0${TAB}none${TAB}-${TAB}tree${TAB}$T/d${TAB}199" "$(MENU_TREE_MIN=50 menu "$T")"
topic t200; fill "$T/d" 200
eq "threshold: 200 files fold; tree row exact" "0${TAB}none${TAB}-${TAB}tree${TAB}$T/d${TAB}200" "$(menu "$T")"
eq "threshold: MENU_TREE_MIN raises it" 200 "$(MENU_TREE_MIN=1000000 menu "$T" | rows)"
MENU_TREE_MIN=abc menu "$T" >/dev/null 2>&1; eq "threshold: non-number exits 3" 3 $?
MENU_TREE_MIN=0 menu "$T" >/dev/null 2>&1; eq "threshold: zero exits 3" 3 $?

# ---- The topic folder never folds.
topic self; fill "$T" 210
out=$(menu "$T")
eq "self: files in the folder itself stay rows" 210 "$(printf '%s\n' "$out" | rows)"
eq "self: no tree row" 0 "$(printf '%s\n' "$out" | grep -c "${TAB}tree${TAB}")"

# ---- Shallowest wins; only tree rows print.
topic shallow; fill "$T/big/a" 120; fill "$T/big/b" 3; fill "$T/big/c" 130; printf 'n\n' >"$T/notes.md"
eq "shallowest: folds at big, not its children; notes hidden" "0${TAB}none${TAB}-${TAB}tree${TAB}$T/big${TAB}253" "$(menu "$T")"

# ---- A nested clone blocks its ancestors, not its siblings, and shows beside trees.
topic clone; fill "$T/big/a" 210; fill "$T/big/c" 220; printf 'n\n' >"$T/big/x.txt"; mkdir -p "$T/big/vendor"; git -C "$T/big/vendor" init -q .
printf 'cite %s/big/vendor/lib.py\n' "$T" >docs/cl.md
git add docs/cl.md; git commit -qm cl
out=$(menu "$T")
eq "clone: blocks big, its siblings fold" "$T/big/a 210,$T/big/c 220," "$(printf '%s\n' "$out" | awk -F '\t' '$4 == "tree" {printf "%s %s,", $5, $6}')"
eq "clone: shown beside the trees and searched for citations, first" "1${TAB}none${TAB}-${TAB}repo${TAB}$T/big/vendor" "$(printf '%s\n' "$out" | sed -n 1p)"
eq "clone: x.txt waits for the second menu" 3 "$(printf '%s\n' "$out" | rows)"
out=$(menu "$T" --expand "$T/big/a" --expand "$T/big/c")
eq "clone: declining both prints 430 files, x.txt, the clone" 432 "$(printf '%s\n' "$out" | rows)"
topic cloneonly; fill "$T/d" 5; mkdir -p "$T/d/vendor"; git -C "$T/d/vendor" init -q .
eq "clone: no tree, normal rows with the clone among them" 6 "$(menu "$T" | rows)"

# ---- A recorded or changed file blocks its ancestors.
topic rec; fill "$T/big/s" 219; printf 'one\n' >"$T/big/one.txt"; record "$T" "$T/big/one.txt"
eq "recorded: big descends to big/s" "$T/big/s 219" "$(menu "$T" | awk -F '\t' '{print $5, $6}')"
record "$T" "$T/big/s/f0.txt"
out=$(menu "$T")
eq "recorded: inside big/s too, so no fold" 218 "$(printf '%s\n' "$out" | rows)"
topic chg; fill "$T/big" 220; record "$T" "$T/big/f0.txt"; printf 'edit\n' >>"$T/big/f0.txt"
out=$(menu "$T")
eq "changed: no fold, every row" 220 "$(printf '%s\n' "$out" | rows)"
eq "changed: the changed row is there" 1 "$(printf '%s\n' "$out" | grep -c "${TAB}changed${TAB}")"

# ---- Declining a fold.
topic exp; fill "$T/big" 220; printf 'n\n' >"$T/small.txt"
eq "expand: without it, tree only" 1 "$(menu "$T" | rows)"
eq "expand: equal path gives every row" 221 "$(menu "$T" --expand "$T/big" | rows)"
eq "expand: trailing slash too" 221 "$(menu "$T" --expand "$T/big/" | rows)"
eq "expand: absolute path too" 221 "$(menu "$T" --expand "$R/$T/big" | rows)"
menu "$T" --expand "$T/nope" >/dev/null 2>&1; eq "expand: mistyped dir exits 3" 3 $?
menu "$T" --expand docs >/dev/null 2>&1; eq "expand: outside the folder exits 3" 3 $?
menu "$T" --expand >/dev/null 2>&1; eq "expand: no value exits 3" 3 $?
menu "$T" --nonsense x >/dev/null 2>&1; eq "expand: unknown flag exits 3" 3 $?
topic expdeep; fill "$T/big/s/t" 220; printf 'n\n' >"$T/big/n.txt"
eq "expand: blocks descendants, one flag declines the whole subtree" 221 "$(menu "$T" --expand "$T/big" | rows)"
eq "expand: declining big/s keeps big/s/t as rows, and big stays unfolded" 221 "$(menu "$T" --expand "$T/big/s" | rows)"
eq "expand: the leaf alone blocks its ancestors" 221 "$(menu "$T" --expand "$T/big/s/t" | rows)"
eq "expand: the topic folder itself declines every fold" 221 "$(menu "$T" --expand "$T" | rows)"
topic exptwo; fill "$T/a" 210; fill "$T/b" 220
eq "expand: another tree still folds, and only trees print" "$T/b 220" "$(menu "$T" --expand "$T/a" | awk -F '\t' '{print $5, $6}')"

# ---- Citations.
topic overlap; printf 'a\n' >"$T/f1.py"; printf 'b\n' >"$T/f1.py.bak"
printf 'one %s/f1.py\n' "$T" >docs/ov1.md
printf 'two %s/f1.py.bak\nthree %s/f1.py.bak\n' "$T" "$T" >docs/ov2.md
git add docs/ov1.md docs/ov2.md; git commit -qm overlap
out=$(menu "$T")
eq "overlap: f1.py counts only its own citation" 1 "$(inb "$out" "$T/f1.py")"
eq "overlap: f1.py.bak counts its two" 2 "$(inb "$out" "$T/f1.py.bak")"

topic cites; printf 'a\n' >"$T/u.py"; printf 'b\n' >"$T/ig.py"; printf 'c\n' >"$T/self.py"; printf 'd\n' >"$T/twice.py"
printf 'x %s/u.py\n' "$T" >untracked-doc.md
printf 'x %s/ig.py\n' "$T" >ignored.md
printf 'x %s/self.py\n' "$T" >"$T/selfcite.md"
printf 'x %s/twice.py and %s/twice.py\n' "$T" "$T" >tw.md
out=$(menu "$T")
eq "cites: untracked doc counts" 1 "$(inb "$out" "$T/u.py")"
eq "cites: ignored file does not count" 0 "$(inb "$out" "$T/ig.py")"
eq "cites: citation inside tmp/ does not count" 0 "$(inb "$out" "$T/self.py")"
eq "cites: occurrences, not lines" 2 "$(inb "$out" "$T/twice.py")"
rm -f untracked-doc.md ignored.md tw.md

topic treecite; fill "$T/big/sub" 220
printf 'dir %s/big\nfile %s/big/sub/f1.txt\nslash %s/big/\n' "$T" "$T" "$T" >docs/tc.md
git add docs/tc.md; git commit -qm treecite
eq "tree: counts the dir, a file under it, and dir/" 3 "$(inb "$(menu "$T")" "$T/big")"

# ---- Spaces, backslashes and other awkward names.
topic 'odd'; D="$T/big dir\\x"; fill "$D" 200
printf 'c %s/f1.txt\n' "$D" >docs/sp.md
git add docs/sp.md; git commit -qm sp
out=$(menu "$T")
eq "odd tree path: row keeps the space and one backslash, cited once" "1${TAB}none${TAB}-${TAB}tree${TAB}$D${TAB}200" "$out"
eq "odd tree path: tab-split gives six fields" 6 "$(printf '%s\n' "$out" | awk -F '\t' '{print NF}')"
eq "odd tree path: --expand takes it" 200 "$(menu "$T" --expand "$D" | rows)"
topic names; printf 'a\n' >"$T/we[ird]+(1)&.py"; printf 'b\n' >"$T/a b.py"; printf 'c\n' >"$T/back\\slash.py"; printf 'q\n' >"$T/qu\"ote.py"
printf 'c %s/we[ird]+(1)&.py\nc %s/a b.py\nc %s/back\\slash.py\nc %s/qu"ote.py\n' "$T" "$T" "$T" "$T" >docs/nm.md
git add docs/nm.md; git commit -qm nm
out=$(menu "$T")
eq "names: regex metacharacters taken literally" 1 "$(inb "$out" "$T/we[ird]+(1)&.py")"
eq "names: space in a file name" 1 "$(inb "$out" "$T/a b.py")"
eq "names: backslash in a file name" 1 "$(inb "$out" "$T/back\\slash.py")"
eq "names: quote in a file name" 1 "$(inb "$out" "$T/qu\"ote.py")"

# ---- Empty.
topic empty
out=$(menu "$T"); rc=$?
eq "empty: exit 0 and no output" "0:" "$rc:$out"
topic allrec; printf 'a\n' >"$T/a"; record "$T" "$T/a"
out=$(menu "$T"); rc=$?
eq "all recorded: exit 0 and no output" "0:" "$rc:$out"

# ---- Failures.
printf '#!/bin/sh\nexit 3\n' >"$W/bad-envscan"; chmod +x "$W/bad-envscan"
bash "$P" "$W/bad-envscan" tmp/20990101/flat >/dev/null 2>&1; eq "failure: status failing exits 3" 3 $?
mkdir -p "$W/fakebin"
REALGIT=$(command -v git)
cat >"$W/fakebin/git" <<EOF
#!/bin/sh
for a in "\$@"; do [ "\$a" = grep ] && { echo 'fatal: stub' >&2; exit 128; }; done
exec "$REALGIT" "\$@"
EOF
chmod +x "$W/fakebin/git"
o=$(PATH="$W/fakebin:$PATH" bash "$P" "$E" tmp/20990101/flat 2>/dev/null); rc=$?
eq "failure: git grep above 1 exits 3, not zero counts" "3:" "$rc:$o"
bash "$P" >/dev/null 2>&1; eq "failure: no arguments exits 3" 3 $?
bash "$P" "$E" /nonexistent/x >/dev/null 2>&1; eq "failure: missing folder exits 3" 3 $?

# ---- A user's git config must not change a count.
T=tmp/20990101/flat
plain=$(menu "$T")
git config --global grep.lineNumber true; git config --global grep.column true
git config --global color.ui always; git config --global grep.fullName true
eq "config: grep.lineNumber, grep.column, grep.fullName, color.ui change nothing" "$plain" "$(menu "$T")"
git config --global --unset grep.lineNumber; git config --global --unset grep.column
git config --global --unset color.ui; git config --global --unset grep.fullName

# ---- Leaves nothing behind.
before=$(git status --porcelain)
store() { find "$HOME/.local/state" -type f -exec cksum {} + 2>/dev/null; }
s=$(store)
menu "$T" >/dev/null
eq "clean: repo unchanged" "$before" "$(git status --porcelain)"
eq "clean: record store unchanged" "$s" "$(store)"
eq "clean: nothing left in TMPDIR, successes and failures included" "" "$(ls -A "$W/menu-tmp")"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
printf 'bash %s; awk %s; git %s\n' "$BASH_VERSION" "$(command -v awk)" "$(git --version)"
[ "$fail" -eq 0 ]
