#!/usr/bin/env bash
# Does tests/menu.sh catch a broken menu.sh? Each mutant must produce at least one
# FAIL. Slower than the suite it checks, so run by hand and not wired into run.sh.
#
#   ENVSCAN_BIN=/path/envscan ./tests/mutants.sh
#
# Exit 0 when every mutant is caught.

set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
MENU="$HERE/../scripts/menu.sh"
W=$(mktemp -d "${TMPDIR:-/tmp}/menu-mutants.XXXXXX")
trap 'rm -rf "$W"' EXIT
caught=0
missed=0

run() {
  name=$1
  shift
  sed "$@" "$MENU" >"$W/menu.sh"
  if cmp -s "$MENU" "$W/menu.sh"; then
    printf 'NOT APPLIED  %s\n' "$name"
    missed=$((missed + 1))
    return
  fi
  MENU_SH="$W/menu.sh" bash "$HERE/menu.sh" >"$W/out" 2>&1
  n=$(grep -c '^FAIL' "$W/out")
  if [ "$n" -gt 0 ]; then
    printf 'CAUGHT (%s)  %s\n' "$n" "$name"
    caught=$((caught + 1))
  else
    printf 'MISSED  %s\n' "$name"
    missed=$((missed + 1))
  fi
}

# A failure on the unmutated script would make every mutant read as caught.
MENU_SH=$MENU bash "$HERE/menu.sh" >"$W/out" 2>&1
n=$(grep -c '^FAIL' "$W/out")
if [ "$n" -gt 0 ] || ! grep -q ' passed, 0 failed' "$W/out"; then
  printf 'BASELINE NOT CLEAN (%s FAIL), so no mutant result means anything\n' "$n"
  grep '^FAIL' "$W/out"
  exit 1
fi

run no-config-overrides -e 's/git -c grep.lineNumber=false -c grep.column=false -c grep.fullName=false/git/' -e 's/grep --no-color/grep/'
run grep-failure-swallowed -e 's/"\$rc" -gt 1/"$rc" -gt 999/'
run no-untracked -e 's/ --untracked//'
run no-recorded-block -e 's/if (H\[i\] == "-" || S\[i\] != "none") blocked\[dirs\[j\]\] = 1/if (H[i] == "-") blocked[dirs[j]] = 1/'
run no-clone-block -e 's/if (H\[i\] == "-" || S\[i\] != "none") blocked\[dirs\[j\]\] = 1/if (S[i] != "none") blocked[dirs[j]] = 1/'
run tree-shows-all -e 's/if (trees > 0) {/if (0) {/'
run off-by-one -e 's/>= min \&\&/> min \&\&/'
run no-trap -e 's/^trap .*/:/'
run default-threshold -e 's/MENU_TREE_MIN:-200/MENU_TREE_MIN:-100/'
run expand-refolds-children -e 's/if (dirs\[j\] in expanded) break/if (0) break/'
run clones-hidden-beside-trees -e 's/if (H\[i\] != "-" || S\[i\] == "recorded") continue/continue/'
run size-not-data -e 's/if (p in large) return "data"/if (0) return "data"/'
run json-escapes-kept -e 's/path = unjson(substr(\$0, 16, length(\$0) - 17))/path = substr($0, 16, length($0) - 17)/'

printf '\n%d caught, %d not\n' "$caught" "$missed"
[ "$missed" -eq 0 ]
