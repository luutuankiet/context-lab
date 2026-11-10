#!/usr/bin/env bash
# Step 1 of the promotion route: every condition that must hold before a menu is
# drawn. Stops at the first failure with one line naming it.
#
#   preflight.sh <topic-folder>
#
# On success prints key=value lines the later steps use:
#   envscan=<absolute path to the binary>   $HOME/.local/bin may be off PATH
#   root=<repo root>
#   folder=tmp/YYYYMMDD/<topic>             relative to the root
#   default=<branch the promote branch starts from>
#
# Exit 0 ready; 1 a condition failed; 2 the pre-push hook was refused (another
# hook is there; its message is printed); 3 the binary is unavailable.
#
# Written for bash 3.2 under set -euo pipefail: no timeout(1), no GNU coreutils.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fail() {
  printf 'preflight: %s\n' "$*" >&2
  exit 1
}

[ "$#" -eq 1 ] || fail "usage: preflight.sh <topic-folder>"
[ -d "$1" ] || fail "$1 is not a directory"

root=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || fail "$1 is not inside a git repo"
root=$(cd -- "$root" && pwd -P)
abs=$(cd -- "$1" && pwd -P)
cd "$root"

git rev-parse --verify -q 'HEAD^{commit}' >/dev/null || fail "the repo has no commit yet; make a first commit"
[ "$(git rev-parse --is-shallow-repository)" = false ] || fail "the clone is shallow; run git fetch --unshallow"

# The folder, relative to the root, must be tmp/YYYYMMDD/<topic>.
case $abs in
  "$root"/*) rel=${abs#"$root"/} ;;
  *) fail "$1 is not under the repo root" ;;
esac
# tmp/projects/ holds private project folders. They are maintained in place and
# never promoted, so they are refused by name before the form check.
case $rel in
  tmp/projects | tmp/projects/*) fail "$rel is a private project folder, not a topic folder; projects are never promoted" ;;
esac
case $rel in
  tmp/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/?*) ;;
  *) fail "$rel is not a topic folder of the form tmp/YYYYMMDD/<topic>/" ;;
esac
topic=${rel#tmp/????????/}
case $topic in */*) fail "$rel is below a topic folder; name tmp/YYYYMMDD/<topic>/ itself" ;; esac

git check-ignore -q .env || fail ".env is not ignored; add .env to .gitignore"
git check-ignore -q tmp/ || fail "tmp/ is not ignored; add tmp/ to .gitignore"
git check-ignore -q "$rel" || fail "$rel is not ignored; an ignore rule re-includes it"

# The binary, through the launcher; exit 3 with its own message when unavailable.
set +e
bin=$(bash "$HERE/envscan")
rc=$?
set -e
[ "$rc" -eq 0 ] || exit 3

# .env discovery, as the scanner does it: the root, else the main checkout of a
# worktree, which is the parent of the common git directory.
env_file=""
if [ -f "$root/.env" ]; then
  env_file="$root/.env"
else
  common=$(cd -- "$(git rev-parse --git-common-dir)" && pwd -P)
  if [ -f "$(dirname -- "$common")/.env" ]; then env_file="$(dirname -- "$common")/.env"; fi
fi
[ -n "$env_file" ] || fail "no .env: the scanner has no values to dehydrate or block; set up .env and .env.example first"

set +e
"$bin" gate install
rc=$?
set -e
case $rc in
  0) ;;
  2) printf 'preflight: the pre-push hook was refused; add the line above to the existing hook, then rerun\n' >&2; exit 2 ;;
  *) fail "envscan gate install exited $rc" ;;
esac

default=""
if ref=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null); then
  default=${ref#origin/}
elif git rev-parse --verify -q refs/heads/main >/dev/null; then
  default=main
elif git rev-parse --verify -q refs/heads/master >/dev/null; then
  default=master
fi
[ -n "$default" ] || fail "no default branch: origin/HEAD, main and master are all absent"

printf 'envscan=%s\nroot=%s\nfolder=%s\ndefault=%s\n' "$bin" "$root" "$rel" "$default"
