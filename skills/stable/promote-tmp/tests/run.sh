#!/usr/bin/env bash
# Regression tests for scripts/envscan, the launcher. Each case runs the launcher
# with a throwaway $HOME against a fake release served from a loopback HTTP
# server, and controls PATH so a case can take away curl, the checksum tools, or
# change what uname reports. The fake binary is a shell script that prints the
# target it was packaged for, so a case can tell which asset was installed.
#
#   ./tests/run.sh                  run with the bash on PATH
#   /bin/bash ./tests/run.sh        run with a specific bash (3.2 on macOS)
#
# Needs python3 for the server. The launcher runs under the same bash as this
# file, so running this file under bash 3.2 tests the launcher under 3.2.

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$HERE/../scripts/envscan"
SH_BASH="${BASH:-bash}"

pass=0
fail=0
skip=0
ok() { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL  %s\n' "$1"; fail=$((fail + 1)); [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; return 0; }
skp() { printf 'SKIP  %s\n' "$1"; skip=$((skip + 1)); }

printf 'bash under test: %s (%s)\n' "$SH_BASH" "$BASH_VERSION"

command -v python3 >/dev/null 2>&1 || { echo "python3 is needed for the fake release server"; exit 2; }

MIN=$(sed -n 's/^ENVSCAN_MIN_VERSION="\(.*\)"$/\1/p' "$LAUNCHER")
[ -n "$MIN" ] || { echo "cannot read ENVSCAN_MIN_VERSION from the launcher"; exit 2; }
TAG="v$MIN"

W=$(mktemp -d "${TMPDIR:-/tmp}/envscan-launcher-test.XXXXXX")
SERVER_PID=""
finish() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$W"
}
trap finish EXIT

sha_line() {
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$(dirname "$1")" && sha256sum "$(basename "$1")")
  else
    (cd "$(dirname "$1")" && shasum -a 256 "$(basename "$1")")
  fi
}

# A fake binary that reports a version and the target it was packaged for.
fake_bin() { # path version target
  cat >"$1" <<EOF
#!/bin/sh
case "\${1:-}" in
  --version) echo "envscan $2" ;;
  *) echo "target=$3 args=\$*"; exit \${FAKE_EXIT:-0} ;;
esac
EOF
  chmod 755 "$1"
}

TARGETS="x86_64-unknown-linux-musl aarch64-unknown-linux-musl aarch64-apple-darwin"

# Releases: good, a wrong checksum, a sums file missing the entry, and an asset
# whose binary cannot run on this machine.
build_release() { # name kind
  local d="$W/www/$1/$TAG" t
  mkdir -p "$d" "$W/pkg"
  : >"$d/SHA256SUMS"
  for t in $TARGETS; do
    rm -rf "$W/pkg/$t" && mkdir -p "$W/pkg/$t"
    if [ "$2" = badbin ]; then
      printf '\177ELF not really\n' >"$W/pkg/$t/envscan"
    else
      fake_bin "$W/pkg/$t/envscan" "$MIN" "$t"
    fi
    tar -czf "$d/envscan-$TAG-$t.tar.gz" -C "$W/pkg/$t" envscan
    case $2 in
      badsum) echo "0000000000000000000000000000000000000000000000000000000000000000  envscan-$TAG-$t.tar.gz" >>"$d/SHA256SUMS" ;;
      noentry) ;;
      *) sha_line "$d/envscan-$TAG-$t.tar.gz" >>"$d/SHA256SUMS" ;;
    esac
  done
}
build_release good good
build_release badsum badsum
build_release noentry noentry
build_release badbin badbin

python3 -u -m http.server 0 --bind 127.0.0.1 --directory "$W/www" >"$W/server.log" 2>&1 &
SERVER_PID=$!
PORT=""
i=0
while [ $i -lt 100 ]; do
  PORT=$(sed -n 's/.* port \([0-9][0-9]*\).*/\1/p' "$W/server.log" | head -1)
  [ -n "$PORT" ] && break
  sleep 0.1
  i=$((i + 1))
done
[ -n "$PORT" ] || { echo "fake release server did not start"; cat "$W/server.log"; exit 2; }
URL="http://127.0.0.1:$PORT"
DEAD="http://127.0.0.1:1" # nothing listens on port 1

# A PATH holding only the named tools, plus a fake uname and optional fakes that
# record any attempt to reach the network.
toolbox() { # dir "tool tool ..." [fake-net]
  local d="$1" t p
  mkdir -p "$d"
  for t in $2; do
    p=$(command -v "$t" 2>/dev/null) || continue
    ln -sf "$p" "$d/$t"
  done
  cat >"$d/uname" <<'EOF'
#!/bin/sh
case "$1" in
  -s) echo "${FAKE_S:-Linux}" ;;
  -m) echo "${FAKE_M:-x86_64}" ;;
  *) echo "${FAKE_S:-Linux}" ;;
esac
EOF
  chmod 755 "$d/uname"
  if [ "${3:-}" = fake-net ]; then
    for t in curl wget; do
      # shellcheck disable=SC2016 # $0 and $* belong to the fake, not to this file
      printf '#!/bin/sh\necho "$0 $*" >>"%s/net-calls"\nexit 7\n' "$W" >"$d/$t"
      chmod 755 "$d/$t"
    done
  fi
}
BASE_TOOLS="sh cat mkdir mktemp rm tar gzip chmod mv tr sed sleep"
toolbox "$W/path-full" "$BASE_TOOLS curl wget sha256sum shasum"
toolbox "$W/path-nosum" "$BASE_TOOLS curl wget"
toolbox "$W/path-shasum" "$BASE_TOOLS curl shasum"
toolbox "$W/path-wget" "$BASE_TOOLS wget sha256sum shasum"
toolbox "$W/path-nonet" "$BASE_TOOLS sha256sum shasum" fake-net

# run <case> <path-dir> <base-url> [args...]: fresh-ish HOME per case name.
run() {
  local c="$1" p="$2" b="$3"
  shift 3
  H="$W/home-$c"
  mkdir -p "$H"
  HOME="$H" PATH="$p" ENVSCAN_RELEASE_BASE="$b" "$SH_BASH" "$LAUNCHER" "$@" >"$W/out" 2>"$W/err"
  RC=$?
  OUT=$(cat "$W/out")
  ERR=$(cat "$W/err")
}
installed_version() { "$H/.local/bin/envscan" --version 2>/dev/null; }
# How many install temp directories were left behind.
leftovers() {
  local n=0 f
  for f in "$H/.local/bin"/.envscan-install.*; do
    [ -e "$f" ] && n=$((n + 1))
  done
  echo "$n"
}

# 1. Missing: installs, prints the absolute path, leaves no temp directory.
run missing "$W/path-full" "$URL/good"
if [ $RC -eq 0 ] && [ "$OUT" = "$H/.local/bin/envscan" ] && [ "$(installed_version)" = "envscan $MIN" ] && [ "$(leftovers)" = 0 ]; then
  ok "missing binary is installed at \$HOME/.local/bin/envscan and its path printed"
else no "missing binary is installed" "rc=$RC out=$OUT err=$ERR"; fi

# 2. Arguments and exit code pass through to the binary.
FAKE_EXIT=1 run missing "$W/path-full" "$URL/good" scan some/path
if [ $RC -eq 1 ] && [ "$OUT" = "target=x86_64-unknown-linux-musl args=scan some/path" ]; then
  ok "arguments and exit code pass through to the binary"
else no "arguments pass through" "rc=$RC out=$OUT err=$ERR"; fi

# 3. Older than the floor: upgraded.
mkdir -p "$W/home-older/.local/bin"
fake_bin "$W/home-older/.local/bin/envscan" 0.0.9 old
run older "$W/path-full" "$URL/good"
if [ $RC -eq 0 ] && [ "$(installed_version)" = "envscan $MIN" ]; then
  ok "binary older than ENVSCAN_MIN_VERSION ($MIN) is upgraded"
else no "older binary upgraded" "rc=$RC out=$OUT err=$ERR"; fi

# 4. Present and current, network unusable two ways: an unreachable base URL
#    and curl/wget replaced by fakes that record any call. Nothing is called.
rm -f "$W/net-calls"
mkdir -p "$W/home-current/.local/bin"
fake_bin "$W/home-current/.local/bin/envscan" "$MIN" local
run current "$W/path-nonet" "$DEAD" scan x
if [ $RC -eq 0 ] && [ "$OUT" = "target=local args=scan x" ] && [ ! -e "$W/net-calls" ]; then
  ok "present and current: runs with no network call (unreachable base, curl/wget never invoked)"
else no "present and current makes no network call" "rc=$RC out=$OUT err=$ERR calls=$(cat "$W/net-calls" 2>/dev/null)"; fi

# 5. Newer than the floor is kept as it is.
mkdir -p "$W/home-newer/.local/bin"
fake_bin "$W/home-newer/.local/bin/envscan" 9.10.0 newer
run newer "$W/path-nonet" "$DEAD"
if [ $RC -eq 0 ] && [ "$(installed_version)" = "envscan 9.10.0" ] && [ ! -e "$W/net-calls" ]; then
  ok "newer binary is kept, no network"
else no "newer binary kept" "rc=$RC out=$OUT err=$ERR"; fi

# 6. Offline with no binary: non-zero, names what is missing, leaves nothing.
run offline "$W/path-full" "$DEAD"
if [ $RC -eq 3 ] && [[ $ERR == *"envscan $MIN is not installed at $H/.local/bin/envscan"* ]] && [[ $ERR == *"failed"* ]] && [ ! -e "$H/.local/bin/envscan" ] && [ "$(leftovers)" = 0 ]; then
  ok "offline without a binary exits 3 naming what is missing"
else no "offline without binary" "rc=$RC err=$ERR"; fi

# 7. Checksum mismatch: refused, no binary, no temp directory.
run badsum "$W/path-full" "$URL/badsum"
if [ $RC -eq 3 ] && [[ $ERR == *"checksum mismatch"* ]] && [ ! -e "$H/.local/bin/envscan" ] && [ "$(leftovers)" = 0 ]; then
  ok "checksum mismatch refuses and leaves no binary"
else no "checksum mismatch refused" "rc=$RC err=$ERR"; fi

# 8. Checksum mismatch with an older binary present: the old file is untouched.
mkdir -p "$W/home-badsum-old/.local/bin"
fake_bin "$W/home-badsum-old/.local/bin/envscan" 0.0.9 old
run badsum-old "$W/path-full" "$URL/badsum"
if [ $RC -eq 3 ] && [ "$(installed_version)" = "envscan 0.0.9" ] && [ "$(leftovers)" = 0 ]; then
  ok "checksum mismatch during an upgrade leaves the old binary untouched and exits 3"
else no "checksum mismatch during upgrade" "rc=$RC err=$ERR"; fi

# 9. No entry for this asset in SHA256SUMS: refused.
run noentry "$W/path-full" "$URL/noentry"
if [ $RC -eq 3 ] && [[ $ERR == *"has no entry"* ]] && [ ! -e "$H/.local/bin/envscan" ]; then
  ok "SHA256SUMS without this asset refuses"
else no "missing sums entry refused" "rc=$RC err=$ERR"; fi

# 10. No checksum tool: refused before downloading anything.
run nosum "$W/path-nosum" "$URL/good"
if [ $RC -eq 3 ] && [[ $ERR == *"neither sha256sum nor shasum"* ]] && [ ! -e "$H/.local/bin/envscan" ]; then
  ok "no checksum tool refuses and leaves no binary"
else no "no checksum tool refused" "rc=$RC err=$ERR"; fi

# 11. shasum alone (macOS has no sha256sum) verifies.
if command -v shasum >/dev/null 2>&1; then
  run shasum "$W/path-shasum" "$URL/good"
  if [ $RC -eq 0 ] && [ "$(installed_version)" = "envscan $MIN" ]; then
    ok "shasum -a 256 alone verifies the download"
  else no "shasum alone" "rc=$RC err=$ERR"; fi
else skp "shasum alone (no shasum on this machine)"; fi

# 12. wget alone (no curl) downloads.
if command -v wget >/dev/null 2>&1; then
  run wget "$W/path-wget" "$URL/good"
  if [ $RC -eq 0 ] && [ "$(installed_version)" = "envscan $MIN" ]; then
    ok "wget alone downloads"
  else no "wget alone" "rc=$RC err=$ERR"; fi
else skp "wget alone (no wget on this machine)"; fi

# 13. A downloaded binary that cannot run here is refused.
run badbin "$W/path-full" "$URL/badbin"
if [ $RC -eq 3 ] && [[ $ERR == *"does not run on this machine"* ]] && [ ! -e "$H/.local/bin/envscan" ] && [ "$(leftovers)" = 0 ]; then
  ok "a downloaded binary that does not run is refused"
else no "unrunnable download refused" "rc=$RC err=$ERR"; fi

# 14. A present binary that cannot run is replaced.
mkdir -p "$W/home-broken/.local/bin"
printf 'garbage\n' >"$W/home-broken/.local/bin/envscan"
chmod 755 "$W/home-broken/.local/bin/envscan"
run broken "$W/path-full" "$URL/good"
if [ $RC -eq 0 ] && [ "$(installed_version)" = "envscan $MIN" ]; then
  ok "a present binary that does not run is reinstalled"
else no "broken binary reinstalled" "rc=$RC err=$ERR"; fi

# 15. Architecture mapping: arm64 and aarch64 both reach the aarch64 assets.
arch_case() { # os machine expected-target
  FAKE_S="$1" FAKE_M="$2" run "arch-$1-$2" "$W/path-full" "$URL/good" probe
  if [ $RC -eq 0 ] && [ "$OUT" = "target=$3 args=probe" ]; then
    ok "uname $1 $2 installs $3"
  else no "uname $1 $2 -> $3" "rc=$RC out=$OUT err=$ERR"; fi
}
export FAKE_S FAKE_M
arch_case Darwin arm64 aarch64-apple-darwin
arch_case Darwin aarch64 aarch64-apple-darwin
arch_case Linux aarch64 aarch64-unknown-linux-musl
arch_case Linux arm64 aarch64-unknown-linux-musl
arch_case Linux x86_64 x86_64-unknown-linux-musl
arch_case Linux amd64 x86_64-unknown-linux-musl

# 16. No release for this machine: refused with the reason.
FAKE_S=Darwin FAKE_M=x86_64 run arch-none "$W/path-full" "$URL/good"
if [ $RC -eq 3 ] && [[ $ERR == *"no release is built for Darwin x86_64"* ]] && [ ! -e "$H/.local/bin/envscan" ]; then
  ok "a machine with no release (Intel macOS) is refused with the reason"
else no "no release for machine" "rc=$RC err=$ERR"; fi

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
