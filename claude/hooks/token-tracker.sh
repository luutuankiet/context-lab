#!/bin/bash
# Near-real-time token tracker — dual-mode hook script
#
# Fires on:
#   PostToolUse      → additionalContext after every tool call (near real-time)
#   UserPromptSubmit → additionalContext + sessionTitle on each user prompt
#
# Usage in settings.json:
#   "PostToolUse":      [{"hooks":[{"type":"command","command":"bash scripts/token-tracker.sh PostToolUse","timeout":5}]}]
#   "UserPromptSubmit": [{"hooks":[{"type":"command","command":"bash scripts/token-tracker.sh UserPromptSubmit","timeout":5}]}]
#
# Reads transcript JSONL for token usage data, computes:
#   - Current context window usage (from last API response)
#   - Cumulative output tokens (sum across session)
#   - Turn count
#
# State is PER SESSION. All state files are namespaced by a key derived from the
# hook payload's .session_id (falling back to a hash of .transcript_path, then to
# the literal "default"):
#   /tmp/cc-token-<key>-summary.txt      human-readable context line
#   /tmp/cc-token-<key>-cumulative.json  structured totals + incremental scan state
#   /tmp/cc-token-<key>-snapshot         context at last UserPromptSubmit
# Concurrent sessions therefore never clobber one another's delta arithmetic.
#
# Transcript reads are BOUNDED: each invocation only parses the lines appended
# since the previous invocation (watermark persisted as .scan_lines in the
# cumulative file), so cost is proportional to new activity, not session length.
# Cumulative totals stay exact because they are carried forward, not recomputed.
#
# Dependencies: jq, awk, coreutils. (No bc — it is not present on every host.)

set -euo pipefail

HOOK_EVENT="${1:-PostToolUse}"

# How many trailing lines to seed from when a cold start is too expensive to
# backfill fully. Empirically the last assistant `usage` entry sits <= 14 lines
# from EOF across every transcript on this host (~10 usage entries per 50 lines),
# so 400 is ~28x headroom while still parsing only a few MB.
TAIL_LINES=400

# Largest transcript we will fully backfill on a cold start. A streaming jq pass
# over 64 MB measures ~0.75 s here, so 128 MB (~1.5 s) leaves >3 s of the 5 s
# hook timeout as margin. Beyond this we seed from the tail instead and mark
# cumulative_complete=false.
COLD_SCAN_MAX_BYTES=134217728

input=$(cat)

# ---- Human-readable token formatter ----
# Byte-identical to the previous `bc` implementation: bc truncated at scale=1,
# so we truncate (int(n*10/div)/10) rather than round.
fmt() {
  awk -v n="$1" 'BEGIN {
    if (n !~ /^-?[0-9]+$/) { printf "%s", n; exit }
    if (n + 0 >= 1000000)   { printf "%.1fm", int(n * 10 / 1000000) / 10 }
    else if (n + 0 >= 1000) { printf "%.1fk", int(n * 10 / 1000) / 10 }
    else                    { printf "%s", n }
  }'
}

# Read one field out of the hook payload without ever aborting the script
# (empty or malformed stdin must be a silent no-op, not a crash).
payload_field() {
  printf '%s' "$input" | jq -r "$1" 2>/dev/null || true
}

session_id=$(payload_field '.session_id // empty')
transcript_path=$(payload_field '.transcript_path // empty')

# ---- Derive a filesystem-safe, per-session state key ----
# Strip everything outside [A-Za-z0-9._-] so the key can never contain a slash
# and therefore can never escape /tmp; cap the length to stay under NAME_MAX.
state_key=$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)
if [ -z "$state_key" ] && [ -n "$transcript_path" ]; then
  if command -v sha256sum >/dev/null 2>&1; then
    state_key=$(printf '%s' "$transcript_path" | sha256sum | tr -cd 'a-f0-9' | cut -c1-16)
  else
    state_key=$(printf '%s' "$transcript_path" | cksum | tr -cd '0-9' | cut -c1-16)
  fi
fi
[ -z "$state_key" ] && state_key="default"

SUMMARY_FILE="/tmp/cc-token-${state_key}-summary.txt"
CUMULATIVE_FILE="/tmp/cc-token-${state_key}-cumulative.json"
SNAPSHOT_FILE="/tmp/cc-token-${state_key}-snapshot"
LOCK_FILE="/tmp/cc-token-${state_key}.lock"

# ---- Get transcript path ----
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  exit 0
fi

# ---- Serialise concurrent invocations within one session ----
# Parallel tool calls fire PostToolUse concurrently; without this the
# read-modify-write of the cumulative watermark could double-count. Best effort:
# if the lock cannot be taken quickly we proceed anyway rather than time out.
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE" 2>/dev/null || true
  flock -w 2 9 2>/dev/null || true
fi

total_lines=$(wc -l < "$transcript_path" 2>/dev/null || echo 0)
total_lines=$(printf '%s' "$total_lines" | tr -cd '0-9')
[ -z "$total_lines" ] && total_lines=0

file_bytes=$(wc -c < "$transcript_path" 2>/dev/null || echo 0)
file_bytes=$(printf '%s' "$file_bytes" | tr -cd '0-9')
[ -z "$file_bytes" ] && file_bytes=0

# Cheap fingerprint of the file head: if the transcript is rewritten in place
# (rewind/compaction) rather than appended to, this changes and we rescan.
head_sig=$(head -c 2048 "$transcript_path" 2>/dev/null | cksum | tr -cd '0-9 ' | tr -d ' ' || true)
[ -z "$head_sig" ] && head_sig="0"

# ---- Load carried-forward state (bounded-read requires exact carry-forward) ----
have_prev=0
prev_lines=0
base_input=0
base_output=0
base_cache_create=0
base_cache_read=0
base_turns=0
prev_context=0
cum_complete=true

if [ -f "$CUMULATIVE_FILE" ]; then
  prev_row=$(jq -r --arg tp "$transcript_path" --arg sig "$head_sig" --argjson tl "$total_lines" '
      select(.scan_lines != null and .current_context != null
             and .transcript_path == $tp and .head_sig == $sig
             and .scan_lines <= $tl)
      | [ .scan_lines, .cumulative_input // 0, .cumulative_output // 0,
          .cumulative_cache_create // 0, .cumulative_cache_read // 0,
          .turn_count // 0, .current_context // 0,
          (if .cumulative_complete == false then "false" else "true" end) ]
      | @tsv' "$CUMULATIVE_FILE" 2>/dev/null || true)
  if [ -n "$prev_row" ]; then
    IFS=$'\t' read -r prev_lines base_input base_output base_cache_create \
      base_cache_read base_turns prev_context cum_complete <<<"$prev_row"
    have_prev=1
  fi
fi

# ---- Decide where this scan starts ----
if [ "$have_prev" -eq 1 ]; then
  scan_start=$prev_lines
elif [ "$file_bytes" -le "$COLD_SCAN_MAX_BYTES" ]; then
  scan_start=0
  cum_complete=true
else
  # Too big to backfill inside the hook timeout: seed from the tail and be
  # honest about it via cumulative_complete=false.
  scan_start=$(( total_lines - TAIL_LINES ))
  [ "$scan_start" -lt 0 ] && scan_start=0
  cum_complete=false
fi

delta_lines=$(( total_lines - scan_start ))
[ "$delta_lines" -lt 0 ] && delta_lines=0

# ---- Stream only the new lines (never slurps the whole transcript) ----
# `head -n "$delta_lines"` also drops any partial trailing line the writer may
# still be flushing, which keeps the watermark on a complete-line boundary.
delta_data=""
if [ "$delta_lines" -gt 0 ]; then
  delta_data=$( { tail -n "+$(( scan_start + 1 ))" "$transcript_path" \
      | head -n "$delta_lines" \
      | jq -n -c '
          reduce inputs as $e (
            {count: 0, in: 0, out: 0, cc: 0, cr: 0, last: null};
            if ($e.type == "assistant" and $e.message.usage != null) then
                .count += 1
              | .in    += ($e.message.usage.input_tokens // 0)
              | .out   += ($e.message.usage.output_tokens // 0)
              | .cc    += ($e.message.usage.cache_creation_input_tokens // 0)
              | .cr    += ($e.message.usage.cache_read_input_tokens // 0)
              | .last   = $e.message.usage
            else . end)'; } 2>/dev/null || true)
fi

if [ -z "$delta_data" ] || [ "$delta_data" = "null" ]; then
  # Scan produced nothing usable. With no prior state there is nothing to
  # report — stay silent, exactly as the original did on a jq failure.
  if [ "$have_prev" -eq 0 ]; then
    exit 0
  fi
  delta_data='{"count":0,"in":0,"out":0,"cc":0,"cr":0,"last":null}'
fi

d_row=$(printf '%s' "$delta_data" | jq -r '
  [ .count // 0, .in // 0, .out // 0, .cc // 0, .cr // 0,
    (.last.input_tokens // 0), (.last.output_tokens // 0),
    (.last.cache_creation_input_tokens // 0), (.last.cache_read_input_tokens // 0)
  ] | @tsv' 2>/dev/null || true)
if [ -z "$d_row" ]; then
  [ "$have_prev" -eq 0 ] && exit 0
  d_row=$'0\t0\t0\t0\t0\t0\t0\t0\t0'
fi
IFS=$'\t' read -r d_count d_in d_out d_cc d_cr \
  last_input last_output last_cache_create last_cache_read <<<"$d_row"

# ---- Parse current context (from last API response) ----
if [ "$d_count" -gt 0 ]; then
  # Current context = what the last API call consumed (≈ context window fill)
  current_context=$(( last_input + last_cache_create + last_cache_read + last_output ))
else
  # No new assistant turn since the previous invocation — carry the last known
  # value forward instead of re-reading the transcript.
  current_context=$prev_context
fi

# ---- Cumulative totals: carried forward, so they stay exact under a bounded read ----
cum_input=$(( base_input + d_in ))
cum_output=$(( base_output + d_out ))
cum_cache_create=$(( base_cache_create + d_cc ))
cum_cache_read=$(( base_cache_read + d_cr ))
turn_count=$(( base_turns + d_count ))

# Total tokens across session (all API calls combined)
total_session=$(( cum_input + cum_output + cum_cache_create + cum_cache_read ))

# ---- Turn delta tracking ----
# UserPromptSubmit snapshots current context; PostToolUse computes delta
if [ "$HOOK_EVENT" = "UserPromptSubmit" ]; then
  echo "$current_context" > "$SNAPSHOT_FILE"
fi

turn_delta=""
if [ -f "$SNAPSHOT_FILE" ]; then
  snapshot=$(cat "$SNAPSHOT_FILE" 2>/dev/null || echo "0")
  snapshot=$(printf '%s' "$snapshot" | tr -cd '0-9')
  [ -z "$snapshot" ] && snapshot=0
  delta=$((current_context - snapshot))
  if [ "$delta" -gt 0 ] 2>/dev/null; then
    turn_delta=" (+$(fmt $delta))"
  fi
fi

# ---- Build context line ----
context_line="Context: $(fmt $current_context)${turn_delta}"

# ---- Write summary file (for external consumers) ----
echo "$context_line" > "$SUMMARY_FILE"

# Also write structured data for programmatic access.
# .scan_lines / .transcript_path / .head_sig / .cumulative_complete are the
# incremental-scan watermark; the rest is the published contract.
jq -n \
  --argjson current_context "$current_context" \
  --argjson cum_output "$cum_output" \
  --argjson cum_input "$cum_input" \
  --argjson cum_cache_create "$cum_cache_create" \
  --argjson cum_cache_read "$cum_cache_read" \
  --argjson total_session "$total_session" \
  --argjson turn_count "$turn_count" \
  --argjson scan_lines "$total_lines" \
  --argjson cumulative_complete "$cum_complete" \
  --arg transcript_path "$transcript_path" \
  --arg head_sig "$head_sig" \
  --arg session_key "$state_key" \
  '{
    current_context: $current_context,
    cumulative_output: $cum_output,
    cumulative_input: $cum_input,
    cumulative_cache_create: $cum_cache_create,
    cumulative_cache_read: $cum_cache_read,
    total_session: $total_session,
    turn_count: $turn_count,
    cumulative_complete: $cumulative_complete,
    session_key: $session_key,
    transcript_path: $transcript_path,
    head_sig: $head_sig,
    scan_lines: $scan_lines,
    timestamp: now | todate
  }' > "$CUMULATIVE_FILE"

# ---- Return hook output ----
# On UserPromptSubmit (once per user turn) the context line carries a standing
# instruction to surface the running weight back to the user. On PostToolUse
# (many times per turn) it stays terse — the directive is already in context,
# and repeating it on every tool call would cost more than it reports.
if [ "$HOOK_EVENT" = "UserPromptSubmit" ]; then
  payload="${context_line}
STANDING INSTRUCTION — report the running context to the user at the end of every
response in this session, as the final line, in exactly this form:

    ⏱ context <value>

Use the most recent value you have seen from this hook. Nothing else on the line.
Do not omit it, do not editorialise about it, and do not repeat it mid-response."
else
  payload="$context_line"
fi

jq -n \
  --arg ctx "$payload" \
  --arg event "$HOOK_EVENT" \
  '{
    hookSpecificOutput: {
      hookEventName: $event,
      additionalContext: $ctx
    }
  }'
