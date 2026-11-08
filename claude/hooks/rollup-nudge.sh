#!/bin/bash
# Rollup nudge: a UserPromptSubmit hook.
#
# When a background task (subagent or background shell) finishes, Claude Code
# delivers its result as a turn whose hook payload contains the
# `<task-notification>` tag. On exactly those turns this prints rollup-nudge.txt,
# a short reminder of the idle-rollup rule in claude/CLAUDE.md section V.
# Every other turn prints nothing.
#
# Plain stdout from a UserPromptSubmit hook is added to the model's context,
# so no JSON envelope (and no jq) is needed.
#
# Never fails the prompt: every error path exits 0 with no output.

set -euo pipefail
trap 'exit 0' ERR

input=$(cat 2>/dev/null || true)

case "$input" in
  *"<task-notification>"*) ;;
  *) exit 0 ;;
esac

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || exit 0
txt="$dir/rollup-nudge.txt"
[ -r "$txt" ] || exit 0

cat "$txt" 2>/dev/null || true
exit 0
