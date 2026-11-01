#!/usr/bin/env bash
# The launcher against the real release, on this machine: a throwaway $HOME
# with no binary, a real download from GitHub, then the installed binary run on
# a tiny fixture whose `.env` value is invented. Needs the network, so it is not
# part of tests/run.sh, which serves a fake release from loopback.
#
#   /bin/bash ./tests/live-install.sh            run under a specific bash
#   ./tests/live-install.sh <dest>               also copy the binary to <dest>
#
# The launcher runs under the same bash as this file. CI runs it with /bin/bash
# on macOS (bash 3.2), ARM Linux and x86_64 Linux; see .github/workflows/.

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$HERE/../scripts/envscan"
SH_BASH="${BASH:-bash}"
KEEP="${1:-}"

pass=0
fail=0
ok() { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL  %s\n' "$1"; fail=$((fail + 1)); [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; return 0; }

MIN=$(sed -n 's/^ENVSCAN_MIN_VERSION="\(.*\)"$/\1/p' "$LAUNCHER")
[ -n "$MIN" ] || { echo "cannot read ENVSCAN_MIN_VERSION from the launcher"; exit 2; }

printf 'bash under test: %s (%s)\n' "$SH_BASH" "$BASH_VERSION"
printf 'machine: %s %s\n' "$(uname -s)" "$(uname -m)"

W=$(mktemp -d "${TMPDIR:-/tmp}/envscan-live-install.XXXXXX")
trap 'rm -rf "$W"' EXIT
H="$W/home"
mkdir -p "$H"
BIN="$H/.local/bin/envscan"

# 0 when $1 >= $2, dotted numbers.
ge() {
  local -a a b
  IFS=. read -r -a a <<<"$1"
  IFS=. read -r -a b <<<"$2"
  local i
  for i in 0 1 2; do
    if [ "${a[i]:-0}" -gt "${b[i]:-0}" ]; then return 0; fi
    if [ "${a[i]:-0}" -lt "${b[i]:-0}" ]; then return 1; fi
  done
  return 0
}

# 1. Empty HOME: the launcher downloads, verifies and installs, and prints the path.
out=$(HOME="$H" "$SH_BASH" "$LAUNCHER" 2>"$W/err"); rc=$?
err=$(cat "$W/err")
printf '%s\n' "$err"
if [ $rc -eq 0 ] && [ "$out" = "$BIN" ] && [ -x "$BIN" ]; then
  ok "empty HOME: launcher installs at \$HOME/.local/bin/envscan and prints that path"
else no "launcher install" "rc=$rc out=$out err=$err"; fi

# 2. The installed binary runs here and is at or above the floor.
ver=$("$BIN" --version 2>&1); rc=$?
printf 'installed: %s\n' "$ver"
num=${ver##* }
case $num in
  [0-9]*.[0-9]*.[0-9]*) shape=ok ;;
  *) shape=bad ;;
esac
if [ $rc -eq 0 ] && [ "${ver%% *}" = envscan ] && [ $shape = ok ] && ge "${num%%-*}" "$MIN"; then
  ok "installed binary runs and reports envscan $num (floor $MIN)"
else no "installed binary version" "rc=$rc out=$ver"; fi

# 3. A second launcher run with the network made useless keeps the binary.
out=$(HOME="$H" ENVSCAN_RELEASE_BASE=http://127.0.0.1:1 "$SH_BASH" "$LAUNCHER" --version 2>&1); rc=$?
if [ $rc -eq 0 ] && [ "$out" = "$ver" ]; then
  ok "second run, unreachable release base: uses the installed binary, no download"
else no "second run offline" "rc=$rc out=$out"; fi

# 4. Known-value scan on a fixture with an invented value: exit 1 and a hit by key.
F="$W/fixture"
mkdir -p "$F/src"
printf 'CLIENT_A=zorblaxcorp\n' >"$F/.env"
printf 'row 1 for zorblaxcorp\n' >"$F/src/notes.txt"
printf 'nothing to see\n' >"$F/src/clean.txt"
scan=$(cd "$F" && "$BIN" scan --known-only --env "$F/.env" --json src 2>"$W/err"); rc=$?
if [ $rc -eq 1 ] && [[ $scan == *'"key": "CLIENT_A"'* ]] && [[ $scan == *"notes.txt"* ]]; then
  ok "scan --known-only finds CLIENT_A in the fixture and exits 1"
else no "scan finds the planted value" "rc=$rc out=$scan err=$(cat "$W/err")"; fi

# 5. The same scan over the clean file alone: exit 0.
(cd "$F" && "$BIN" scan --known-only --env "$F/.env" src/clean.txt >/dev/null 2>&1); rc=$?
[ $rc -eq 0 ] && ok "scan --known-only on a clean file exits 0" || no "clean scan" "rc=$rc"

if [ -n "$KEEP" ] && [ -x "$BIN" ]; then
  mkdir -p "$(dirname "$KEEP")" && cp "$BIN" "$KEEP" && printf 'binary kept at %s\n' "$KEEP"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
