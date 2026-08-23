#!/usr/bin/env bash
#
# Compose one statusline out of several independent contributors.
#
# Claude Code renders exactly one statusline, from exactly one settings value.
# This script owns that value. It discovers contributors by scanning
# `statusline.d/` directories, runs each as its own process under a shared
# budget, and joins what they print.
#
#   statusline-dispatch.sh            read the session JSON on stdin, render
#   statusline-dispatch.sh --list     print the contributors, in render order
#   statusline-dispatch.sh --version  print this file's version marker
#
# Contributors are discovered, never registered:
#
#   $CLAUDE_DIR/plugins/marketplaces/<marketplace>/statusline.d/*
#   $CLAUDE_DIR/statusline.d/*
#
# A repo contributes by committing an executable file to its own
# `statusline.d/`. Nothing is written at install time and no repo names any
# other. The scan is gated on `enabledPlugins`, because merely *adding* a
# marketplace must never be enough to run its code on every render.
#
# Ordering is the basename, so position is a property of the name rather than
# of which marketplace a file arrived from. `00`-`19` is the primary line,
# `20`-`79` ordinary contributors, `80`-`99` warnings and alerts.
#
# Four failure modes, and each renders the line without the contributor rather
# than blanking it:
#
#   prints nothing         nothing on screen; silence is a valid answer
#   exits non-zero/stderr  `! statusline:<name>` on screen, detail in the log
#   runs past the budget   nothing on screen, a line in the log
#   is not executable      skipped at discovery, nothing anywhere
#
# The split between the middle two is deliberate. A timeout is transient and
# the next render recovers it, so raising an alarm would train the reader to
# ignore the line. A contributor that is genuinely broken would otherwise fail
# silently forever, which is the worse failure.
#
# This file is byte-identical in every repo that ships it, and is written to a
# host path by whichever installer runs. The `dispatcher-version` marker below
# is what makes that convergent: an installer replaces an older copy, leaves a
# newer one alone, and rewrites a same-version copy whose bytes have drifted.
#
# Written for bash 3.2 with no `timeout(1)` and no GNU coreutils, because the
# oldest host in the fleet has none of them and a mechanism that silently does
# nothing on one machine is the failure this exists to refuse.
#
# dispatcher-version: 1

set -u

DISPATCHER_VERSION=1

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
LOG="$CLAUDE_DIR/statusline-dispatch.log"

# Seconds, not milliseconds: bash 3.2's `read -t` has no fractional form and
# `sleep` is the only portable clock here. One second is the working default
# because a cold start -- the first render after the contributor files are new
# -- was measured over a second on the slowest host, and a tighter budget turns
# an ordinary cold start into a visible flicker.
BUDGET="${CLAUDE_STATUSLINE_BUDGET:-1}"

# Between contributors. Three spaces reads as one line with gaps rather than as
# columns, which is what the segments were designed against.
SEP="${CLAUDE_STATUSLINE_SEP:-   }"

MODE=render
case "${1:-}" in
  --version) printf '%s\n' "$DISPATCHER_VERSION"; exit 0 ;;
  --list)    MODE=list ;;
  '')        ;;
  *)         printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
esac

# The log is the only place a timeout is ever reported, so a permanently
# over-budget contributor would grow it without bound. Trim on write, not on
# read: the cost is paid only when something is actually wrong.
log() {
  printf '%s dispatch: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" >> "$LOG" 2>/dev/null || return 0
  local lines
  lines=$(wc -l < "$LOG" 2>/dev/null) || return 0
  [ "${lines:-0}" -gt 400 ] || return 0
  local keep="$LOG.trim.$$"
  if tail -n 200 "$LOG" > "$keep" 2>/dev/null; then mv -- "$keep" "$LOG" 2>/dev/null || rm -f -- "$keep"; fi
}

# Marketplaces the human has already said yes to. `enabledPlugins` is keyed
# `plugin@marketplace`, and one enabled plugin is enough to enrol the
# marketplace it came from. Absent settings, absent jq or unparseable JSON all
# mean "nothing is enabled" -- the host-local directory still contributes.
enabled_marketplaces() {
  [ -f "$CLAUDE_DIR/settings.json" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r '(.enabledPlugins // {}) | to_entries[]
         | select(.value == true) | .key | sub("^[^@]*@"; "")' \
     "$CLAUDE_DIR/settings.json" 2>/dev/null
}

# Emits `<basename><TAB><path>`, sorted. Sorting the pair sorts on the basename
# first and breaks a tie by full path -- stable, and arbitrary by design, since
# two repos claiming the same number is a naming collision to resolve by
# talking rather than by mechanism.
#
# The executable bit is enrolment. A file that is present but not executable is
# skipped here and never appears anywhere else, which is what lets a repo park
# a shared colour palette or a README beside its contributors.
discover() {
  {
    local mkt dir file
    for mkt in $(enabled_marketplaces | sort -u); do
      dir="$CLAUDE_DIR/plugins/marketplaces/$mkt/statusline.d"
      [ -d "$dir" ] || continue
      for file in "$dir"/*; do
        [ -f "$file" ] && [ -x "$file" ] && printf '%s\t%s\n' "${file##*/}" "$file"
      done
    done
    dir="$CLAUDE_DIR/statusline.d"
    if [ -d "$dir" ]; then
      for file in "$dir"/*; do
        [ -f "$file" ] && [ -x "$file" ] && printf '%s\t%s\n' "${file##*/}" "$file"
      done
    fi
  } | sort
}

if [ "$MODE" = list ]; then
  discover | while IFS="$(printf '\t')" read -r base path; do
    [ -n "${path:-}" ] && printf '%s\n' "$path"
  done
  exit 0
fi

payload=$(cat)

work=$(mktemp -d "${TMPDIR:-/tmp}/statusline-dispatch.XXXXXX" 2>/dev/null) || exit 0
trap 'rm -rf -- "$work"' EXIT INT TERM

# Start every contributor at once. Concurrency turns the budget from a sum into
# a wall clock: one hung contributor costs one budget, not one budget each.
#
# A here-document, not a pipe. A piped `while read` runs in a subshell, and the
# child pids started inside it would not be this shell's children to `wait` on.
n=0
while IFS="$(printf '\t')" read -r base path; do
  [ -n "${path:-}" ] || continue
  n=$((n + 1))
  printf '%s' "$base" > "$work/$n.name"
  printf '%s' "$payload" | "$path" > "$work/$n.out" 2> "$work/$n.err" &
  printf '%s' "$!" > "$work/$n.pid"
done <<EOF
$(discover)
EOF

if [ "$n" -gt 0 ]; then
  # One watchdog for all of them, not a poll loop. Enforcing the budget by
  # looping on `kill -0` with a short `sleep` forks a process per tick, and on
  # the slowest host in the fleet a fork costs more than the tick it is
  # measuring -- a 400 ms budget was measured at 2.2 s of wall clock, a 5x
  # divergence between the counter and reality. One `sleep` forks once.
  #
  # The marker file, not the exit status, is what names a timeout: a killed
  # process reports 143 and so could an ordinary contributor.
  (
    sleep "$BUDGET"
    i=1
    while [ "$i" -le "$n" ]; do
      p=$(cat "$work/$i.pid" 2>/dev/null)
      if [ -n "${p:-}" ] && kill -0 "$p" 2>/dev/null; then
        : > "$work/$i.timeout"
        kill -TERM "$p" 2>/dev/null
      fi
      i=$((i + 1))
    done
  ) &
  watchdog=$!

  i=1
  while [ "$i" -le "$n" ]; do
    p=$(cat "$work/$i.pid" 2>/dev/null)
    if [ -n "${p:-}" ]; then
      wait "$p" 2>/dev/null
      printf '%s' "$?" > "$work/$i.rc"
    fi
    i=$((i + 1))
  done

  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
fi

# Compose. The only byte this dispatcher ever removes from a contributor is the
# trailing newline, which is the join itself; it never truncates and never
# looks inside. Cutting a string that carries ANSI escapes mid-sequence
# corrupts the colour state of everything after it, so width belongs to the
# contributor, which has COLUMNS in its environment for exactly that.
#
# A contributor is free to print more than one row. Because the join does not
# insert a newline, a multi-row contributor followed by a segment puts that
# segment on the right of its last row -- which is how a compact alert rides an
# existing row instead of claiming one of its own.
line=""
alerts=""
i=1
while [ "$i" -le "$n" ]; do
  name=$(cat "$work/$i.name" 2>/dev/null)
  rc=$(cat "$work/$i.rc" 2>/dev/null)
  fragment=$(cat "$work/$i.out" 2>/dev/null)
  stderrtext=$(cat "$work/$i.err" 2>/dev/null)

  if [ -f "$work/$i.timeout" ]; then
    log "timeout after ${BUDGET}s: $name"
  elif [ "${rc:-0}" != "0" ] || [ -n "$stderrtext" ]; then
    log "failed (exit ${rc:-0}): $name"
    [ -n "$stderrtext" ] && log "  $name: $stderrtext"
    alerts="$alerts ! statusline:$name"
  elif [ -n "$fragment" ]; then
    [ -n "$line" ] && line="$line$SEP"
    line="$line$fragment"
  fi
  i=$((i + 1))
done

[ -n "$line$alerts" ] && printf '%s%s\n' "$line" "$alerts"
exit 0
