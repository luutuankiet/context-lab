#!/bin/bash
# Is the root commit a usable repo identity? Synthetic repo only, in a scratch dir,
# plus a count across local clones that prints no repo name, URL or path.
#   repo_identity_probe.sh SCRATCH_DIR PARENT_OF_CLONES
set -euo pipefail
G=/usr/bin/git
S=$1
PARENT=$2
rm -rf "$S/a" "$S/moved" "$S/full" "$S/shallow" "$S/unborn"
mkdir -p "$S/a" "$S/unborn"
"$G" -C "$S/a" init -q
"$G" -C "$S/a" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m one
"$G" -C "$S/a" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m two
root() { "$G" -C "$1" rev-list --max-parents=0 HEAD 2>/dev/null || echo NONE; }
A=$(root "$S/a")
mv "$S/a" "$S/moved"
[ "$(root "$S/moved")" = "$A" ] && echo "moved clone: same id" || echo "moved clone: DIFFERENT id"
"$G" clone -q "file://$S/moved" "$S/full"
[ "$(root "$S/full")" = "$A" ] && echo "full clone: same id" || echo "full clone: DIFFERENT id"
"$G" clone -q --depth 1 "file://$S/moved" "$S/shallow"
[ "$(root "$S/shallow")" = "$A" ] && echo "shallow clone: same id" || echo "shallow clone: DIFFERENT id"
"$G" -C "$S/moved" remote remove origin 2>/dev/null || true
[ "$(root "$S/moved")" = "$A" ] && echo "no remote: same id" || echo "no remote: DIFFERENT id"
"$G" -C "$S/unborn" init -q
echo "no commits yet: $(root "$S/unborn")"

repos=0; one=0; many=0; none=0; noremote=0
for d in "$PARENT"/*/; do
  [ -d "$d/.git" ] || continue
  repos=$((repos+1))
  n=$("$G" -C "$d" rev-list --max-parents=0 --count HEAD 2>/dev/null || echo 0)
  case "$n" in 0) none=$((none+1));; 1) one=$((one+1));; *) many=$((many+1));; esac
  [ -n "$("$G" -C "$d" remote)" ] || noremote=$((noremote+1))
done
echo "local clones=$repos one_root=$one several_roots=$many no_commits=$none no_remote=$noremote"
