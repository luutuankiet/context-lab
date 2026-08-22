#!/bin/bash
# Minimal Claude Code statusline — model + token analytics + progress bar
# Replaces cc-statusline v1.4.0

input=$(cat)

# ---- Parse JSON via jq ----
model_full=$(echo "$input" | jq -r '.model.display_name // "Claude"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
win_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
cached=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# ---- Per-turn metrics (current_usage = most recent API call) ----
fresh_in=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
turn_in=$((fresh_in + cache_create))
turn_out=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')

# ---- Mode detection: OpenRouter (cumulative) vs Pro/Max (per-turn) ----
is_openrouter=false
if [ -n "$ANTHROPIC_BASE_URL" ] && echo "$ANTHROPIC_BASE_URL" | grep -qi "openrouter"; then
  is_openrouter=true
fi

# ---- Short model name ----
model=$(echo "$model_full" | sed 's/^Claude //')

# ---- Human-readable token formatter ----
# awk, not bc: bc is not installed on every host (joon has never had it), and a
# statusline that shells out to a missing binary fails silently every render.
fmt() {
  local n="$1"
  if [ "$n" -ge 1000000 ] 2>/dev/null; then
    awk -v n="$n" 'BEGIN { printf "%.1fm", n / 1000000 }'
  elif [ "$n" -ge 1000 ] 2>/dev/null; then
    awk -v n="$n" 'BEGIN { printf "%.1fk", n / 1000 }'
  else
    printf "%s" "$n"
  fi
}

# ---- Totals ----
# tokens_io = just I/O (for line 2 breakdown)
tokens_io=$((total_in + total_out))
win_fmt=$(fmt $win_size)

# ---- Fallback: compute used_pct if null/0 but we have data ----
if [ "$used_pct" = "null" ] || [ "$used_pct" = "0" ]; then
  if [ "$tokens_io" -gt 0 ] && [ "$win_size" -gt 0 ]; then
    used_pct=$((tokens_io * 100 / win_size))
  else
    used_pct=0
  fi
fi
if [ -z "$remaining_pct" ] || [ "$remaining_pct" = "null" ]; then
  remaining_pct=$((100 - used_pct))
fi

# ---- Bar proportions ----
# used_pct ALREADY includes cached. Cached is a subset, not additive.
cached_pct=0
if [ "$win_size" -gt 0 ] && [ "$cached" -gt 0 ] 2>/dev/null; then
  cached_pct=$((cached * 100 / win_size))
fi

# I/O = total used minus cached portion
io_pct=$((used_pct - cached_pct))
[ "$io_pct" -lt 0 ] && io_pct=0
free_pct=$((100 - used_pct))
[ "$free_pct" -lt 0 ] && free_pct=0

# ---- Progress bar (20 chars) ----
BAR_W=20
cached_blocks=$((cached_pct * BAR_W / 100))
io_blocks=$((io_pct * BAR_W / 100))
# Ensure at least 1 block for I/O if there are tokens but rounds to 0
if [ "$io_pct" -gt 0 ] && [ "$io_blocks" -eq 0 ]; then io_blocks=1; fi
free_blocks=$((BAR_W - cached_blocks - io_blocks))
[ "$free_blocks" -lt 0 ] && free_blocks=0

# ---- Colors ----
RST="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

# Bar color based on remaining context
if [ "$remaining_pct" -le 20 ]; then
  USED_CLR="\033[38;5;203m"   # coral red — danger
elif [ "$remaining_pct" -le 40 ]; then
  USED_CLR="\033[38;5;215m"   # peach — caution
else
  USED_CLR="\033[38;5;158m"   # mint green — healthy
fi
CACHE_CLR="\033[38;5;117m"    # sky blue
FREE_CLR="\033[38;5;240m"     # dark gray
MODEL_CLR="\033[38;5;147m"    # light purple
LABEL_CLR="\033[38;5;245m"    # gray
COST_CLR="\033[38;5;220m"    # gold — OpenRouter billing

# Build bar string
bar=""
for ((i=0; i<cached_blocks; i++)); do bar+="▓"; done
bar_cached="$bar"; bar=""
for ((i=0; i<io_blocks; i++)); do bar+="█"; done
bar_io="$bar"; bar=""
for ((i=0; i<free_blocks; i++)); do bar+="░"; done
bar_free="$bar"

# ---- Render ----
# Line 0: working directory, $HOME-relative. Older clients may not send it —
# print nothing rather than an empty row.
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
case "$cwd" in
  "$HOME") cwd="~" ;;
  "$HOME"/*) cwd="~${cwd#$HOME}" ;;
esac
[ -n "$cwd" ] && printf "  %s\n" "$cwd"

# Line 1: model + progress bar + token summary
printf "  ${MODEL_CLR}${BOLD}%s${RST}  " "$model"
# printf "[${CACHE_CLR}%s${RST}${USED_CLR}%s${RST}${FREE_CLR}%s${RST}]" "$bar_cached" "$bar_io" "$bar_free"
# Derive summary from used_pct so number matches bar + percentage
context_used=$((used_pct * win_size / 100))
printf "  %s/%s ${DIM}(%s%%)${RST}" "$(fmt $context_used)" "$win_fmt" "$used_pct"

# # Line 2: breakdown — per-turn (Pro/Max) or cumulative (OpenRouter)
# printf '\n'
# if [ "$is_openrouter" = true ]; then
#   # OpenRouter: cumulative totals (billing visibility)
#   printf "  ${DIM}Σ${RST} ${LABEL_CLR}in:${RST}$(fmt $total_in)"
#   printf "  ${LABEL_CLR}out:${RST}$(fmt $total_out)"
# else
#   # Pro/Max: per-turn metrics (last API call = root agent after response)
#   printf "  ${DIM}↻${RST} ${LABEL_CLR}in:${RST}$(fmt $turn_in)"
#   printf "  ${LABEL_CLR}out:${RST}$(fmt $turn_out)"
# fi
# if [ "$cached" -gt 0 ] 2>/dev/null; then
#   printf "  ${CACHE_CLR}cached:${RST}$(fmt $cached)"
# fi
# printf "  ${LABEL_CLR}remaining:${RST}${remaining_pct}%%"
# printf '\n'

# # Line 3: OpenRouter cost
# if [ "$is_openrouter" = true ]; then
#   cost_fmt=$(printf "%.4f" "$total_cost")
#   printf "  ${LABEL_CLR}openrouter  session:${RST}${COST_CLR}\$%s${RST}\n" "$cost_fmt"
# fi