#!/bin/bash
# Outbound gate: PreToolUse shim in front of `envscan gate`.
#
# Bound in hooks/hooks.json to `Bash|mcp__.*gh-cli__.*`. Exit 0 allows the call,
# exit 2 blocks it and shows stderr to the agent. Any other exit code, and a
# timeout, let the call through, so every failure here must become exit 2:
# that is what the ERR trap is for.
#
# Order:
#   1. Repo not opted in (no `.env`, and no `.env.example` holding a `# what:`
#      line, at the checkout root or the main checkout of a worktree): exit 0.
#   2. envscan found (PATH, then $HOME/.local/bin/envscan): hand it the hook
#      JSON unchanged; it parses the call, scans, and decides. Its exit 3
#      (IO error) is mapped to 2 here.
#   3. envscan missing: a Bash command with no `git` and no `gh` word passes;
#      anything else, including every MCP GitHub call that writes, is denied
#      with the way to install envscan. Never the launcher here: a download
#      could outlast the hook timeout, and a timeout passes.
#
# No jq: the hook JSON is read with sed only to find `cwd`, `tool_name` and
# `command`, and only on the paths where the binary cannot read it itself.

set -euo pipefail
trap 'exit 2' ERR

input=$(cat)
flat=$(printf '%s' "$input" | LC_ALL=C tr '\n\r' '  ')

# The string value of "key": "value". An occurrence inside another string is
# escaped (\"key\") and never matches, so only a real key is found.
json_string() {
  printf '%s' "$flat" |
    LC_ALL=C sed -n -E 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p'
}

deny() {
  printf 'outbound gate: denied: %s\n' "$1" >&2
  exit 2
}

# --- 1. is this repo opted in? -------------------------------------------
cwd=$(json_string cwd || true)
if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
  cwd=$PWD
fi

roots=$(git -C "$cwd" rev-parse --show-toplevel --git-common-dir 2>/dev/null || true)
[ -n "$roots" ] || exit 0
top=$(printf '%s\n' "$roots" | sed -n 1p)
common=$(printf '%s\n' "$roots" | sed -n 2p)
case "$common" in
  /*) ;;
  *) common="$cwd/$common" ;;
esac
main=$(dirname "$common")

gated=0
for dir in "$top" "$main"; do
  if [ -f "$dir/.env" ]; then
    gated=1
  elif [ -f "$dir/.env.example" ] && grep -q '^# what:' "$dir/.env.example"; then
    gated=1
  fi
done
[ "$gated" = 1 ] || exit 0

# --- 2. hand it to envscan -----------------------------------------------
bin=$(command -v envscan 2>/dev/null || true)
if [ -z "$bin" ] && [ -x "$HOME/.local/bin/envscan" ]; then
  bin="$HOME/.local/bin/envscan"
fi
if [ -n "$bin" ]; then
  if printf '%s' "$input" | "$bin" gate; then
    exit 0
  fi
  exit 2
fi

# --- 3. no binary: let only what cannot post through ------------------------
root=$(cd "$(dirname "$0")/../.." && pwd)
install_hint="envscan is not installed, so this repo's outbound calls cannot be checked. Install it with the launcher, bash \"$root/skills/stable/promote-tmp/scripts/envscan\" --version, or place a build of luutuankiet/envscan at \$HOME/.local/bin/envscan. Then retry."

tool=$(json_string tool_name || true)
case "$tool" in
  Bash)
    cmd=$(json_string command || true)
    [ -n "$cmd" ] || deny "the hook input has no command to judge. $install_hint"
    # Escapes such as \n would glue a word to the letter n; split them first.
    # No grep -q on a pipe: its early exit is a SIGPIPE, which would read as
    # "no match" under pipefail and let the call through.
    words=" $(printf '%s' "$cmd" | LC_ALL=C sed -E 's/\\[nrt]/ /g' | LC_ALL=C tr -c 'A-Za-z0-9_' ' ') "
    case "$words" in
      *" git "* | *" gh "*) deny "$install_hint" ;;
    esac
    exit 0
    ;;
  mcp__*gh-cli__read_files | mcp__*gh-cli__grep | mcp__*gh-cli__directory_tree)
    exit 0
    ;;
  mcp__*gh-cli__*)
    deny "$install_hint"
    ;;
  "")
    deny "the hook input is not a tool call this gate can read. $install_hint"
    ;;
  *)
    exit 0
    ;;
esac
