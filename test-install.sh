#!/usr/bin/env bash
# Exercise install.sh against a throwaway $CLAUDE_CONFIG_DIR and $HOME.
# --no-rtk / --no-plugin throughout: `rtk init -g` and `claude plugin install`
# both write to the real ~/.claude regardless of CLAUDE_CONFIG_DIR, so they are
# the two steps that cannot be sandboxed and must be verified by other means.
set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
T="${1:-${TMPDIR:-/tmp}}/context-lab-test.$$"
FLAGS=(--no-rtk --no-plugin)
PASS=0; FAIL=0

banner() { printf '\n======== %s\n' "$1"; }
assert() { # assert <desc> <expected-exit> <actual-exit>
  if [ "$2" = "$3" ]; then printf 'PASS  %s\n' "$1"; PASS=$((PASS+1))
  else printf 'FAIL  %s (wanted exit %s, got %s)\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); fi
}

fresh() {
  rm -rf "$T"; mkdir -p "$T/home/.claude"
  export HOME="$T/home"
  export CLAUDE_CONFIG_DIR="$T/home/.claude"
  export SHELL=/bin/zsh   # pin the login shell so the rc target is deterministic
  # A realistic pre-existing settings.json: rtk owns PreToolUse, the dead
  # enabledMcpjsonServers and agent keys are present, and there is a host-local pref
  # (spinnerTipsEnabled) that we do not own and must not touch. Do not use
  # `verbose` as that canary -- it is owned now.
  printf '%s\n' \
    '{' \
    '  "enabledMcpjsonServers": ["proxy"],' \
    '  "agent": "gsd-lite",' \
    '  "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "/rtk/hook.sh" } ] } ] },' \
    '  "spinnerTipsEnabled": false,' \
    '  "effortLevel": "low"' \
    '}' > "$CLAUDE_CONFIG_DIR/settings.json"
  : > "$HOME/.zshrc"
}

run() { bash "$REPO/install.sh" "${FLAGS[@]}" "$@"; }

# ---------------------------------------------------------------------------
fresh
banner "1. --dry-run writes nothing"
before=$(cat "$CLAUDE_CONFIG_DIR/settings.json")
run --dry-run >/dev/null 2>&1; rc=$?
after=$(cat "$CLAUDE_CONFIG_DIR/settings.json")
assert "dry-run leaves settings.json byte-identical" "$before" "$after"
assert "dry-run creates no CLAUDE.md link" "absent" "$([ -e "$CLAUDE_CONFIG_DIR/CLAUDE.md" ] && echo present || echo absent)"

banner "2. --check on an uninstalled host fails"
run --check >/dev/null 2>&1; assert "--check exits non-zero before install" "1" "$?"

banner "3. install"
run; assert "install exits 0" "0" "$?"

banner "4. post-install invariants"
assert "CLAUDE.md is a real file, not a link" "file" \
  "$([ -f "$CLAUDE_CONFIG_DIR/CLAUDE.md" ] && [ ! -L "$CLAUDE_CONFIG_DIR/CLAUDE.md" ] && echo file || echo no)"
assert "CLAUDE.md imports the marketplace memory block exactly once" "1" \
  "$(awk '/^@.*\/plugins\/marketplaces\/context-lab\/claude\/CLAUDE\.md$/ { n++ } END { print n+0 }' \
     "$CLAUDE_CONFIG_DIR/CLAUDE.md")"
assert "token-tracker.sh is a symlink" "link" "$([ -L "$CLAUDE_CONFIG_DIR/hooks/token-tracker.sh" ] && echo link || echo no)"
assert "dead enabledMcpjsonServers key removed" "false" \
  "$(jq -r 'has("enabledMcpjsonServers")' "$CLAUDE_CONFIG_DIR/settings.json")"
assert "retired agent default removed" "false" \
  "$(jq -r 'has("agent")' "$CLAUDE_CONFIG_DIR/settings.json")"
assert "rtk's PreToolUse hook survived" "/rtk/hook.sh" \
  "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$CLAUDE_CONFIG_DIR/settings.json")"
assert "our UserPromptSubmit hook installed" "1" \
  "$(jq -r '.hooks.UserPromptSubmit | length' "$CLAUDE_CONFIG_DIR/settings.json")"
assert "owned key overwritten (effortLevel low -> high)" "high" \
  "$(jq -r '.effortLevel' "$CLAUDE_CONFIG_DIR/settings.json")"
assert "unowned host-local key preserved (spinnerTipsEnabled)" "false" \
  "$(jq -r '.spinnerTipsEnabled' "$CLAUDE_CONFIG_DIR/settings.json")"
assert "owned key added where the host had none (showThinkingSummaries)" "true" \
  "$(jq -r '.showThinkingSummaries' "$CLAUDE_CONFIG_DIR/settings.json")"
# Counts the vars in shell_exports()'s list; bump both together when it grows.
assert "shell exports appended" "3" \
  "$(grep -c '^export ' "$HOME/.zshrc")"

banner "5. --check now passes"
run --check >/dev/null 2>&1; assert "--check exits 0 after install" "0" "$?"

banner "6. idempotency"
snap=$(jq -S . "$CLAUDE_CONFIG_DIR/settings.json"); rc_snap=$(cat "$HOME/.zshrc")
run >/dev/null 2>&1; assert "second install exits 0" "0" "$?"
assert "settings.json unchanged by re-install" "$snap" "$(jq -S . "$CLAUDE_CONFIG_DIR/settings.json")"
assert "zshrc not duplicated by re-install" "$rc_snap" "$(cat "$HOME/.zshrc")"
run --check >/dev/null 2>&1; assert "--check still passes" "0" "$?"

banner "7. drift: a link replaced by a real file"
rm -f "$CLAUDE_CONFIG_DIR/statusline.sh"; echo 'echo hi' > "$CLAUDE_CONFIG_DIR/statusline.sh"
run --check >/dev/null 2>&1; assert "--check catches the un-linked file" "1" "$?"
run >/dev/null 2>&1
assert "install re-links it" "link" "$([ -L "$CLAUDE_CONFIG_DIR/statusline.sh" ] && echo link || echo no)"
assert "and backed the stray file up" "1" \
  "$(find "$CLAUDE_CONFIG_DIR/backups" -name 'statusline.sh.pre-context-lab.*' | wc -l | tr -d ' ')"

banner "8. drift: an owned key hand-edited"
tmp=$(mktemp); jq '.effortLevel = "low"' "$CLAUDE_CONFIG_DIR/settings.json" > "$tmp"; mv "$tmp" "$CLAUDE_CONFIG_DIR/settings.json"
run --check >/dev/null 2>&1; assert "--check catches the drifted key" "1" "$?"

banner "9. malformed settings.json is never overwritten"
echo '{ this is not json' > "$CLAUDE_CONFIG_DIR/settings.json"
run >/dev/null 2>&1; assert "install refuses (exit 1)" "1" "$?"
assert "malformed file left untouched" "{ this is not json" "$(cat "$CLAUDE_CONFIG_DIR/settings.json")"

banner "10. a genuinely fresh host (no settings.json at all)"
fresh; rm -f "$CLAUDE_CONFIG_DIR/settings.json"
run >/dev/null 2>&1; assert "install exits 0 with no prior settings" "0" "$?"
assert "manifest keys all present" "19" "$(jq -r 'keys | length' "$REPO/claude/settings.owned.json")"
run --check >/dev/null 2>&1; assert "--check passes on the fresh host" "0" "$?"

banner "11. the shipped scripts actually run"
printf '%s' '{"model":{"display_name":"Claude Opus 5"},"context_window":{"used_percentage":42,"context_window_size":1000000,"total_input_tokens":1200,"total_output_tokens":340,"current_usage":{"cache_read_input_tokens":900,"input_tokens":100,"cache_creation_input_tokens":200,"output_tokens":40}}}' \
  | bash "$REPO/claude/statusline.sh" >/dev/null 2>&1
assert "statusline.sh runs without bc" "0" "$?"
printf '%s' '{}' | bash "$REPO/claude/hooks/token-tracker.sh" PostToolUse >/dev/null 2>&1
assert "token-tracker.sh no-ops on an empty payload" "0" "$?"

banner "12. the payload carries no import of its own"
# The payload is imported, never linked, so a relative @import inside it would
# resolve against the marketplace clone rather than $CLAUDE_DIR and silently
# find nothing. rtk's own reference belongs in the host-local file rtk writes.
# awk not rg: the smallest host in the fleet has neither rg nor bc, and this
# suite must run anywhere the installer does.
assert "payload carries no @RTK.md import" "0" \
  "$(awk '/^@RTK\.md$/ { n++ } END { print n+0 }' "$REPO/claude/CLAUDE.md")"

banner "13. the import is idempotent under re-install"
run >/dev/null 2>&1
run >/dev/null 2>&1
assert "three installs leave exactly one import" "1" \
  "$(awk '/^@.*\/plugins\/marketplaces\/context-lab\/claude\/CLAUDE\.md$/ { n++ } END { print n+0 }' \
     "$CLAUDE_CONFIG_DIR/CLAUDE.md")"

banner "14. a hand-written free region survives an install"
printf '\n## host notes\nkeep me\n' >> "$CLAUDE_CONFIG_DIR/CLAUDE.md"
run >/dev/null 2>&1
assert "free region untouched" "1" \
  "$(grep -cx 'keep me' "$CLAUDE_CONFIG_DIR/CLAUDE.md")"
assert "still exactly one import after a free-region edit" "1" \
  "$(awk '/^@.*\/plugins\/marketplaces\/context-lab\/claude\/CLAUDE\.md$/ { n++ } END { print n+0 }' \
     "$CLAUDE_CONFIG_DIR/CLAUDE.md")"

banner "15. a near-miss spelling collapses instead of duplicating"
# The rtk failure, reproduced deliberately: a second import of the same target
# written a different way must collapse to one line, not become a second import.
# A '/./' segment: a different spelling of the same target, which is exactly the
# shape that produced a duplicate rtk import. Matching is on the path tail, so
# any prefix spelling collapses.
printf '@%s/./plugins/marketplaces/context-lab/claude/CLAUDE.md\n' "$CLAUDE_CONFIG_DIR" \
  >> "$CLAUDE_CONFIG_DIR/CLAUDE.md"
run >/dev/null 2>&1
assert "near-miss spelling collapsed to one" "1" \
  "$(awk '/^@.*\/plugins\/marketplaces\/context-lab\/claude\/CLAUDE\.md$/ { n++ } END { print n+0 }' \
     "$CLAUDE_CONFIG_DIR/CLAUDE.md")"
assert "free region still survived the collapse" "1" \
  "$(grep -cx 'keep me' "$CLAUDE_CONFIG_DIR/CLAUDE.md")"

banner "16. the import points at the real payload path, not a doubled one"
# Every assertion above matches the path with a leading '.*', so a prefix built
# wrong -- '<dir>/plugins/marketplaces/context-lab' + a tail that already
# contains it -- satisfies all of them while pointing at nothing. Assert the
# whole line, and assert the target it names actually exists in the payload.
# The sandbox points $HOME at the throwaway tree too, so the installer picks the
# ~-anchored spelling -- the same literal a real host gets, which is the point of
# preferring it.
assert "import line is exactly the expected path" "1" \
  "$(grep -cxF '@~/.claude/plugins/marketplaces/context-lab/claude/CLAUDE.md' \
     "$CLAUDE_CONFIG_DIR/CLAUDE.md")"
assert "the path the import names exists in the repo" "1" \
  "$([ -f "$REPO/claude/CLAUDE.md" ] && echo 1 || echo 0)"

rm -rf "$T"
printf '\n======== %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
