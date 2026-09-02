#!/usr/bin/env bash
#
# The statusline dispatcher, exercised against a throwaway config directory.
#
# Every failure mode here is *run*, not asserted about. The four rows of the
# isolation table -- a contributor that prints nothing, one that exits
# non-zero, one that hangs past the budget, one that is not executable -- are
# each a real contributor doing the real thing, because the value of this
# mechanism is entirely in what it does when a contributor misbehaves, and a
# test that only reads the source proves none of it.
#
# Nothing here touches the real config directory.

set -uo pipefail

REPO=$(cd -- "$(dirname -- "$0")/../.." && pwd)
DISPATCH="$REPO/claude/statusline-dispatch.sh"

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

is()      { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (want [$3], got [$2])"; fi; }
has()     { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (missing [$3] in [$2])" ;; esac; }
hasnt()   { case "$2" in *"$3"*) fail "$1 (found [$3] in [$2])" ;; *) pass "$1" ;; esac; }
file_has(){ if grep -Fq -- "$3" "$2" 2>/dev/null; then pass "$1"; else fail "$1 (missing [$3])"; fi; }

# A statusline payload with the fields any contributor may rely on.
PAYLOAD='{"session_id":"t","transcript_path":"/nonexistent/t.jsonl","cwd":"/tmp",
  "model":{"id":"m","display_name":"Claude Opus 5"},
  "workspace":{"current_dir":"/tmp","project_dir":"/tmp"},
  "version":"2.1.241","output_style":{"name":"default"},
  "cost":{"total_cost_usd":0},
  "context_window":{"total_input_tokens":800,"total_output_tokens":200,
    "context_window_size":200000,"used_percentage":8,"remaining_percentage":92,
    "current_usage":{"cache_read_input_tokens":0}}}'

# A config directory with two marketplaces the human has enabled, one they have
# not, and a host-local drop-in.
sandbox() {
  local d; d=$(mktemp -d)
  mkdir -p "$d/.claude/statusline.d"
  mkdir -p "$d/.claude/plugins/marketplaces/pub/statusline.d"
  mkdir -p "$d/.claude/plugins/marketplaces/priv/statusline.d"
  mkdir -p "$d/.claude/plugins/marketplaces/off/statusline.d"
  cat > "$d/.claude/settings.json" <<'JSON'
{"enabledPlugins":{"a@pub":true,"b@priv":true,"c@off":false}}
JSON
  printf '%s\n' "$d"
}

# contrib <sandbox> <pub|priv|off|host> <name> <body>
contrib() {
  local d="$1" where="$2" name="$3" body="$4" dir
  case "$where" in
    host) dir="$d/.claude/statusline.d" ;;
    *)    dir="$d/.claude/plugins/marketplaces/$where/statusline.d" ;;
  esac
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$dir/$name"
  chmod +x "$dir/$name"
}

render() { # render <sandbox> [budget]
  local d="$1"
  printf '%s' "$PAYLOAD" | \
    HOME="$d" CLAUDE_CONFIG_DIR="$d/.claude" COLUMNS=120 \
    CLAUDE_STATUSLINE_BUDGET="${2:-1}" bash "$DISPATCH" 2>/dev/null
}

printf '\n== nothing installed ==\n'
D=$(sandbox)
OUT=$(render "$D"); is "exit 0" "$?" "0"
is "renders nothing" "$OUT" ""

printf '\n== one contributor renders its own bytes ==\n'
D=$(sandbox)
contrib "$D" pub 20-hello 'printf "hello"'
is "its output is the line" "$(render "$D")" "hello"

printf '\n== contributors interleave by basename, not by marketplace ==\n'
D=$(sandbox)
contrib "$D" priv 80-late  'printf "LATE"'
contrib "$D" pub  20-early 'printf "EARLY"'
contrib "$D" host 40-mid   'printf "MID"'
OUT=$(render "$D")
is "sorted by basename across all three sources" "$OUT" "EARLY   MID   LATE"
LIST=$(HOME="$D" CLAUDE_CONFIG_DIR="$D/.claude" bash "$DISPATCH" --list)
is "--list agrees, in render order" \
   "$(printf '%s\n' "$LIST" | sed 's#.*/##' | tr '\n' ' ')" "20-early 40-mid 80-late "

printf '\n== a marketplace that is not enabled contributes nothing ==\n'
D=$(sandbox)
contrib "$D" off 20-sneaky 'printf "SNEAKY"'
contrib "$D" pub 30-fine   'printf "FINE"'
OUT=$(render "$D")
hasnt "code from an un-enabled marketplace never runs" "$OUT" "SNEAKY"
is "the enabled one still renders" "$OUT" "FINE"

printf '\n== isolation row 1: a contributor that prints nothing ==\n'
D=$(sandbox)
contrib "$D" pub  20-silent 'exit 0'
contrib "$D" priv 30-loud   'printf "LOUD"'
OUT=$(render "$D")
is "the line renders without it, and with no stray separator" "$OUT" "LOUD"
hasnt "silence raises no alarm" "$OUT" "!"

printf '\n== isolation row 2: a contributor that exits non-zero ==\n'
D=$(sandbox)
contrib "$D" pub  20-broken 'printf "PARTIAL"; echo "boom" >&2; exit 3'
contrib "$D" priv 30-loud   'printf "LOUD"'
OUT=$(render "$D")
hasnt "its output is dropped, not shown" "$OUT" "PARTIAL"
is "the healthy contributor still renders" "${OUT%% !*}" "LOUD"
has "the failure is named on screen" "$OUT" "! statusline:20-broken"
file_has "and the detail is in the log" "$D/.claude/statusline-dispatch.log" "failed (exit 3): 20-broken"
file_has "including what it wrote to stderr" "$D/.claude/statusline-dispatch.log" "boom"

printf '\n== a contributor that exits zero but writes to stderr is still an error ==\n'
D=$(sandbox)
contrib "$D" pub 20-noisy 'printf "OUT"; echo "warning" >&2'
has "named on screen" "$(render "$D")" "! statusline:20-noisy"

printf '\n== isolation row 3: a contributor that hangs past the budget ==\n'
D=$(sandbox)
contrib "$D" pub  20-hung 'sleep 30; printf "NEVER"'
contrib "$D" priv 30-loud 'printf "LOUD"'
START=$(date +%s)
OUT=$(render "$D" 0.3)
ELAPSED=$(( $(date +%s) - START ))
is "the line renders without it" "$OUT" "LOUD"
hasnt "a timeout is NOT named on screen -- it is transient" "$OUT" "!"
file_has "it is named in the log instead" "$D/.claude/statusline-dispatch.log" "timeout after 0.3s: 20-hung"
if [ "$ELAPSED" -le 5 ]; then pass "the budget is enforced (${ELAPSED}s, not 30s)"
else fail "the budget is enforced (took ${ELAPSED}s)"; fi

printf '\n== one budget for all of them, not one budget each ==\n'
D=$(sandbox)
contrib "$D" pub  20-hung-a 'sleep 30'
contrib "$D" pub  21-hung-b 'sleep 30'
contrib "$D" priv 30-loud   'printf "LOUD"'
START=$(date +%s)
OUT=$(render "$D" 1)
ELAPSED=$(( $(date +%s) - START ))
is "the line renders" "$OUT" "LOUD"
if [ "$ELAPSED" -le 4 ]; then pass "two hangs cost one budget (${ELAPSED}s)"
else fail "two hangs cost one budget (took ${ELAPSED}s)"; fi

printf '\n== isolation row 4: a contributor that is not executable ==\n'
D=$(sandbox)
contrib "$D" pub 20-armed 'printf "ARMED"'
printf '#!/usr/bin/env bash\nprintf "DISARMED"\n' > "$D/.claude/plugins/marketplaces/pub/statusline.d/21-disarmed"
chmod -x "$D/.claude/plugins/marketplaces/pub/statusline.d/21-disarmed"
OUT=$(render "$D")
is "it is skipped at discovery" "$OUT" "ARMED"
hasnt "and raises no alarm" "$OUT" "!"
LIST=$(HOME="$D" CLAUDE_CONFIG_DIR="$D/.claude" bash "$DISPATCH" --list)
hasnt "it does not appear in --list either" "$LIST" "21-disarmed"

printf '\n== the dispatcher never edits a contributor bytes ==\n'
D=$(sandbox)
# 300 columns of ANSI-coloured text through an 80-column terminal. Truncation
# here would cut mid-escape and corrupt the colour of the whole rest of the
# line, which is why width is the contributor job and never the dispatcher.
contrib "$D" pub 20-wide 'printf "\033[38;5;215m"; i=0; while [ $i -lt 30 ]; do printf "0123456789"; i=$((i+1)); done; printf "\033[0m"'
OUT=$(COLUMNS=80; render "$D")
is "300 columns arrive intact" "${#OUT}" "$((300 + 11 + 4))"
has "the closing escape survives" "$OUT" "$(printf '\033[0m')"

printf '\n== a multi-row contributor keeps an alert on its last row ==\n'
D=$(sandbox)
contrib "$D" pub  10-rows  'printf "  ~/dev/repo\n  Opus 5   80.0k/1.0m (8%%)"'
contrib "$D" priv 80-alert 'printf "GLYPH"'
OUT=$(render "$D")
is "two rows in, two rows out" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "2"
is "the alert rides the last row" "$(printf '%s\n' "$OUT" | sed -n 2p)" "  Opus 5   80.0k/1.0m (8%)   GLYPH"

printf '\n== the version marker is readable without running a render ==\n'
V=$(bash "$DISPATCH" --version)
is "--version prints a bare integer" "$(printf '%s' "$V" | tr -d '0-9')" ""
file_has "and the file carries the same marker as a comment" "$DISPATCH" "dispatcher-version: $V"

printf '\n== the host-local directory works with no settings.json at all ==\n'
D=$(sandbox)
rm -f "$D/.claude/settings.json"
contrib "$D" host 40-solo 'printf "SOLO"'
is "no settings means no marketplaces, not no statusline" "$(render "$D")" "SOLO"


# ---------------------------------------------------------------------------
# This repo's own contributor. Everything above is the dispatcher and is
# byte-identical wherever it ships; below is what this half contributes.

printf '\n== this repo primary contributor ==\n'
SEG="$REPO/statusline.d/10-context"
if [ -x "$SEG" ]; then pass "10-context is executable"; else fail "10-context is executable"; fi

context() { # context <payload> [columns]
  printf '%s' "$1" | COLUMNS="${2:-120}" HOME=/nonexistent bash "$SEG" 2>/dev/null
}
plain() { printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g'; }

OUT=$(plain "$(context "$PAYLOAD")")
is "two rows: the directory, then model and context" \
   "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "2"
is "the working directory gets its own row" "$(printf '%s\n' "$OUT" | sed -n 1p)" "  /tmp"
is "model, usage and window on the second" \
   "$(printf '%s\n' "$OUT" | sed -n 2p)" "  Opus 5    16.0k/200.0k (8%)"

printf '\n== the row names the project, not wherever the session wandered ==\n'
# A session that enters a worktree moves `current_dir` and leaves `project_dir`
# where it was. The row exists to say which project this window belongs to, so
# it follows the one that does not move -- otherwise two windows on the same
# repo become indistinguishable at exactly the moment there are two checkouts.
WANDERED='{"cwd":"/repo/tmp/worktrees/wt","model":{"display_name":"Claude Opus 5"},
  "workspace":{"current_dir":"/repo/tmp/worktrees/wt","project_dir":"/repo"},
  "context_window":{"context_window_size":200000,"used_percentage":8}}'
is "project_dir wins over a current_dir inside a worktree" \
   "$(printf '%s\n' "$(plain "$(context "$WANDERED")")" | sed -n 1p)" "  /repo"

# Older clients send no `project_dir` at all; the row must not vanish for them.
LEGACYDIR='{"cwd":"/fallback","model":{"display_name":"Claude Opus 5"},
  "workspace":{"current_dir":"/legacy"},
  "context_window":{"context_window_size":200000,"used_percentage":8}}'
is "current_dir still carries the row when project_dir is absent" \
   "$(printf '%s\n' "$(plain "$(context "$LEGACYDIR")")" | sed -n 1p)" "  /legacy"

# And with no workspace at all, the top-level `cwd` is the last resort.
BARE='{"cwd":"/bare","model":{"display_name":"Claude Opus 5"},
  "context_window":{"context_window_size":200000,"used_percentage":8}}'
is "top-level cwd is the last resort" \
   "$(printf '%s\n' "$(plain "$(context "$BARE")")" | sed -n 1p)" "  /bare"

printf '\n== no trailing newline, so an alert can ride the last row ==\n'
RAW=$(printf '%s' "$PAYLOAD" | COLUMNS=120 bash "$SEG" 2>/dev/null; printf 'X')
NL=$'\n'   # never `$(printf '\n')` -- command substitution strips exactly the
           # byte this is looking for, and the test then passes on anything.
case "$RAW" in *"$NL"X) fail "the last row does not end in a newline" ;;
                    *) pass "the last row does not end in a newline" ;; esac

printf '\n== the two moments the platform sends null instead of a number ==\n'
# `used_percentage` is null before the first API call of a session and again
# after a compaction -- the two occasions a human is most likely to be looking.
NULLS='{"cwd":"/tmp","model":{"display_name":"Claude Opus 5"},
  "workspace":{"current_dir":"/tmp"},
  "context_window":{"context_window_size":200000,"used_percentage":null,
    "total_input_tokens":null,"total_output_tokens":null,"current_usage":null}}'
OUT=$(plain "$(context "$NULLS")")
is "renders a real line rather than arithmetic wreckage" \
   "$(printf '%s\n' "$OUT" | sed -n 2p)" "  Opus 5    0/200.0k (0%)"

printf '\n== it recovers a percentage the platform did not send ==\n'
NOPCT='{"cwd":"/tmp","model":{"display_name":"Claude Opus 5"},
  "workspace":{"current_dir":"/tmp"},
  "context_window":{"context_window_size":200000,
    "total_input_tokens":40000,"total_output_tokens":10000}}'
is "from the token totals" \
   "$(printf '%s\n' "$(plain "$(context "$NOPCT")")" | sed -n 2p)" "  Opus 5    50.0k/200.0k (25%)"

printf '\n== width is this contributor job, and it does it before any escape ==\n'
LONGDIR="/tmp/$(printf 'a%.0s' 1 2 3 4 5 6 7 8 9 0)/$(printf 'b%.0s' 1 2 3 4 5 6 7 8 9 0)/$(printf 'c%.0s' 1 2 3 4 5 6 7 8 9 0)/leaf"
LONGPAY=$(printf '%s' "$PAYLOAD" | jq --arg d "$LONGDIR" '.workspace.project_dir = $d')
ROW1=$(printf '%s\n' "$(plain "$(context "$LONGPAY" 40)")" | sed -n 1p)
if [ "${#ROW1}" -le 40 ]; then pass "a long path is trimmed to COLUMNS (${#ROW1} <= 40)"
else fail "a long path is trimmed to COLUMNS (got ${#ROW1})"; fi
has "and it keeps the leaf, which is what identifies it" "$ROW1" "leaf"
is "a short path is left exactly alone" \
   "$(printf '%s\n' "$(plain "$(context "$PAYLOAD" 40)")" | sed -n 1p)" "  /tmp"

printf '\n== a missing working directory costs no row, not an empty one ==\n'
NOCWD='{"model":{"display_name":"Claude Opus 5"},"workspace":{},
  "context_window":{"context_window_size":200000,"used_percentage":8}}'
is "one row, not two" "$(printf '%s\n' "$(plain "$(context "$NOCWD")")" | wc -l | tr -d ' ')" "1"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
