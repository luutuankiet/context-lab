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
  #
  # PostToolUse is the legacy token-tracker binding, seeded deliberately: it is
  # what a real host looks like before this install, and the whole point of the
  # nested unset is that it goes while PreToolUse beside it stays.
  printf '%s\n' \
    '{' \
    '  "enabledMcpjsonServers": ["proxy"],' \
    '  "agent": "gsd-lite",' \
    '  "hooks": {' \
    '    "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "/rtk/hook.sh" } ] } ],' \
    '    "PostToolUse": [ { "hooks": [ { "type": "command", "command": "bash ~/.claude/hooks/token-tracker.sh PostToolUse" } ] } ]' \
    '  },' \
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
assert "nothing is symlinked into the config dir any more" "absent" \
  "$([ -e "$CLAUDE_CONFIG_DIR/hooks/token-tracker.sh" ] || [ -e "$CLAUDE_CONFIG_DIR/statusline.sh" ] && echo present || echo absent)"
assert "dead enabledMcpjsonServers key removed" "false" \
  "$(jq -r 'has("enabledMcpjsonServers")' "$CLAUDE_CONFIG_DIR/settings.json")"
assert "retired agent default removed" "false" \
  "$(jq -r 'has("agent")' "$CLAUDE_CONFIG_DIR/settings.json")"
assert "rtk's PreToolUse hook survived" "/rtk/hook.sh" \
  "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$CLAUDE_CONFIG_DIR/settings.json")"
# The nested unset. These two now ship as plugin hooks; left in settings they
# would merge with the plugin's copy and fire the tracker twice per event.
assert "legacy PostToolUse hook removed from settings" "null" \
  "$(jq -r '.hooks.PostToolUse // "null"' "$CLAUDE_CONFIG_DIR/settings.json")"
assert "no UserPromptSubmit hook in settings" "null" \
  "$(jq -r '.hooks.UserPromptSubmit // "null"' "$CLAUDE_CONFIG_DIR/settings.json")"
assert "owned key overwritten (effortLevel low -> medium)" "medium" \
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

banner "7. drift: the legacy hook comes back"
# A host that re-runs an old installer, or hand-restores a backup, gets the
# settings binding again. --check must see it, and install must take it out
# without touching the PreToolUse entry sitting next to it.
tmp=$(mktemp)
jq '.hooks.UserPromptSubmit = [ { "hooks": [ { "type": "command", "command": "bash ~/.claude/hooks/token-tracker.sh UserPromptSubmit" } ] } ]' \
  "$CLAUDE_CONFIG_DIR/settings.json" > "$tmp"; mv "$tmp" "$CLAUDE_CONFIG_DIR/settings.json"
run --check >/dev/null 2>&1; assert "--check catches the resurrected hook" "1" "$?"
run >/dev/null 2>&1
assert "install removes it again" "null" \
  "$(jq -r '.hooks.UserPromptSubmit // "null"' "$CLAUDE_CONFIG_DIR/settings.json")"
assert "rtk's PreToolUse hook still survived" "/rtk/hook.sh" \
  "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$CLAUDE_CONFIG_DIR/settings.json")"

banner "7b. the plugin hooks manifest"
assert "hooks/hooks.json is valid JSON" "0" \
  "$(jq -e . "$REPO/hooks/hooks.json" >/dev/null 2>&1; echo $?)"
assert "both events bound to the plugin-root path" "2" \
  "$(grep -c 'CLAUDE_PLUGIN_ROOT.*token-tracker\.sh' "$REPO/hooks/hooks.json")"

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

banner "10b. the statusline dispatcher"
fresh
run >/dev/null 2>&1
[ -x "$CLAUDE_CONFIG_DIR/statusline-dispatch.sh" ]
assert "written to the host, and executable" "0" "$?"
cmp -s "$REPO/claude/statusline-dispatch.sh" "$CLAUDE_CONFIG_DIR/statusline-dispatch.sh"
assert "byte-identical to the repo's copy" "0" "$?"
# The one that catches a half-migration: the settings value and the file on
# disk have to name the same thing, or the line goes blank with no error.
DECLARED=$(jq -r '.statusLine.command' "$CLAUDE_CONFIG_DIR/settings.json")
assert "settings declares the dispatcher" "bash ~/.claude/statusline-dispatch.sh" "$DECLARED"
eval "[ -x ${DECLARED#bash } ]" 2>/dev/null
assert "and the path it names exists on this host" "0" "$?"

# Capture, never `run | grep -q`. Under `pipefail` an early-exiting grep closes
# the pipe, SIGPIPEs the installer, and the assertion reads 141 for a run that
# actually succeeded.
saw() { case "$1" in *"$2"*) printf 0 ;; *) printf 1 ;; esac; }

V=$(awk '/^# dispatcher-version:/ { print $3; exit }' "$REPO/claude/statusline-dispatch.sh")
OUT=$(run 2>&1)
assert "a repeat install recognises it rather than rewriting" "0" "$(saw "$OUT" "dispatcher v$V already installed")"

printf '# vandalised\n' >> "$CLAUDE_CONFIG_DIR/statusline-dispatch.sh"
run >/dev/null 2>&1
cmp -s "$REPO/claude/statusline-dispatch.sh" "$CLAUDE_CONFIG_DIR/statusline-dispatch.sh"
assert "a hand-edited copy converges back" "0" "$?"

# The other half of the lab, one version ahead. Whichever installer runs second
# must not walk the host backwards.
sed 's/^# dispatcher-version: .*/# dispatcher-version: 99/' \
  "$REPO/claude/statusline-dispatch.sh" > "$CLAUDE_CONFIG_DIR/statusline-dispatch.sh"
BEFORE=$(cat "$CLAUDE_CONFIG_DIR/statusline-dispatch.sh")
run >/dev/null 2>&1
assert "a newer dispatcher is never downgraded" "$BEFORE" "$(cat "$CLAUDE_CONFIG_DIR/statusline-dispatch.sh")"

fresh; rm -f "$CLAUDE_CONFIG_DIR/settings.json"
OUT=$(run --check 2>&1)
assert "--check names a host with no dispatcher" "0" "$(saw "$OUT" "dispatcher at")"

banner "11. the shipped scripts actually run"
printf '%s' '{"model":{"display_name":"Claude Opus 5"},"context_window":{"used_percentage":42,"context_window_size":1000000,"total_input_tokens":1200,"total_output_tokens":340,"current_usage":{"cache_read_input_tokens":900,"input_tokens":100,"cache_creation_input_tokens":200,"output_tokens":40}}}' \
  | bash "$REPO/statusline.d/10-context" >/dev/null 2>&1
assert "the statusline contributor runs without bc" "0" "$?"
printf '%s' '{}' | bash "$REPO/claude/hooks/token-tracker.sh" PostToolUse >/dev/null 2>&1
assert "token-tracker.sh no-ops on an empty payload" "0" "$?"

# Inside a subagent the payload's transcript_path is the parent's; the hook must
# size the subagent's own transcript and, past the checkpoint, send the rules once.
S="tt-$$"; mkdir -p "$T/proj/$S/subagents"
printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":10,"cache_read_input_tokens":5000,"cache_creation_input_tokens":0,"output_tokens":10}}}' > "$T/proj/$S.jsonl"
printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":10,"cache_read_input_tokens":130000,"cache_creation_input_tokens":0,"output_tokens":10}}}' > "$T/proj/$S/subagents/agent-a1.jsonl"
tt() { printf '{"session_id":"%s","transcript_path":"%s"%s}' "$S" "$T/proj/$S.jsonl" "$1" | bash "$REPO/claude/hooks/token-tracker.sh" PostToolUse; }
OUT=$(tt ',"agent_id":"a1"')
assert "a subagent is shown its own context" "0" "$(saw "$OUT" "Context: 130.0k (this subagent)")"
assert "the checkpoint sends the handoff rules" "0" "$(saw "$OUT" "SUBAGENT CHECKPOINT")"
OUT=$(tt ',"agent_id":"agent-a1"')
assert "the rules go once; later calls get one line" "1" "$(saw "$OUT" "HANDOFF:")"
OUT=$(tt '')
assert "the main thread is unchanged" "1" "$(saw "$OUT" "subagent")"

# No leaks: sibling agents, the same agent id in another session, a session id
# long enough to hit the key cap, and calls fired in parallel.
use() { printf '{"type":"assistant","message":{"usage":{"input_tokens":0,"cache_read_input_tokens":%s,"cache_creation_input_tokens":0,"output_tokens":0}}}\n' "$2" >> "$1"; }
L="$S-$(printf 'x%.0s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60)"
for s in "$S" "$S-other" "$L"; do mkdir -p "$T/proj/$s/subagents"; use "$T/proj/$s.jsonl" 5000; done
use "$T/proj/$S/subagents/agent-b2.jsonl" 21000
use "$T/proj/$S-other/subagents/agent-a1.jsonl" 31000
use "$T/proj/$L/subagents/agent-p1.jsonl" 140000
use "$T/proj/$L/subagents/agent-p2.jsonl" 141000
tq() { printf '{"session_id":"%s","transcript_path":"%s","agent_id":"%s"}' "$1" "$T/proj/$1.jsonl" "$2" | bash "$REPO/claude/hooks/token-tracker.sh" PostToolUse; }
for r in 1 2 3; do
  for p in "$S a1" "$S b2" "$S-other a1" "$L p1" "$L p2"; do tq $p > "$T/out-${p// /-}-$r" & done
done
wait
LEAK=0
for r in 1 2 3; do
  for want in "$S-a1 130.0k" "$S-b2 21.0k" "$S-other-a1 31.0k" "$L-p1 140.0k" "$L-p2 141.0k"; do
    saw "$(cat "$T/out-${want% *}-$r")" "Context: ${want#* } (this subagent)" | grep -q 0 || LEAK=$((LEAK+1))
  done
done
assert "15 parallel calls across agents and sessions each see their own number" "0" "$LEAK"
assert "two siblings past the line each get the full rules" "0" \
  "$(( $(saw "$(cat "$T/out-$L-p1-"*)" "SUBAGENT CHECKPOINT") + $(saw "$(cat "$T/out-$L-p2-"*)" "SUBAGENT CHECKPOINT") ))"
rm -f /tmp/cc-token-"$S"*

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
