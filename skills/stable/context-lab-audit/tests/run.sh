#!/usr/bin/env bash
#
# The host audit, exercised against a throwaway config directory and a
# throwaway remote.
#
#   ./tests/run.sh
#
# Every fixture is a real git remote and a real clone of it, because the whole
# behaviour under test is "what does remote HEAD say" -- a test that stubbed the
# fetch would prove none of it. The remote is seeded from this repository's own
# working tree, so the manifests the audit parses are the real ones and a change
# to the installer's shape fails here rather than on a host.
#
# Nothing here touches the real config directory or the real remote.

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$HERE/../scripts/audit.sh"
REPO="$(cd -- "$HERE/../../../.." && pwd)"

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

is()    { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (want [$3], got [$2])"; fi; }
has()   { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (missing [$3])" ;; esac; }
hasnt() { case "$2" in *"$3"*) fail "$1 (found [$3])" ;; *) pass "$1" ;; esac; }

git_q() { git -c user.email=t@example.invalid -c user.name=t -c commit.gpgsign=false "$@"; }

# A remote holding this repository's real manifests, a clone of it that a host
# would serve plugins from, and a config directory that satisfies every check.
sandbox() {
  local t; t=$(mktemp -d "${TMPDIR:-/tmp}/context-lab-audit-test.XXXXXX")
  local o="$t/origin" c="$t/.claude" m

  mkdir -p "$o/claude/hooks" "$o/statusline.d"
  cp "$REPO/install.sh"                     "$o/install.sh"
  cp "$REPO/claude/settings.owned.json"     "$o/claude/settings.owned.json"
  cp "$REPO/claude/statusline-dispatch.sh"  "$o/claude/statusline-dispatch.sh"
  cp "$REPO/claude/statusline.sh"           "$o/claude/statusline.sh"
  cp "$REPO/claude/CLAUDE.md"               "$o/claude/CLAUDE.md"
  cp "$REPO/claude/hooks/token-tracker.sh"  "$o/claude/hooks/token-tracker.sh"
  cp "$REPO/statusline.d/10-context"        "$o/statusline.d/10-context"
  chmod +x "$o/statusline.d/10-context" "$o/claude/statusline-dispatch.sh"
  git_q init -q "$o" >/dev/null 2>&1
  git_q -C "$o" add -A >/dev/null 2>&1
  git_q -C "$o" commit -qm seed >/dev/null 2>&1

  m="$c/plugins/marketplaces/context-lab"
  mkdir -p "$c/plugins" "$c/hooks"
  git_q clone -q "$o" "$m" >/dev/null 2>&1

  # The keys this repository owns, holding exactly their intended values.
  cp "$o/claude/settings.owned.json" "$c/settings.json"

  # The plugin, built from the commit the clone is on.
  local sha; sha=$(git_q -C "$m" rev-parse HEAD | cut -c1-12)
  mkdir -p "$c/plugins/cache/context-lab/context-lab/$sha"
  cat > "$c/plugins/installed_plugins.json" <<JSON
{"plugins":{"context-lab@context-lab":[{"scope":"user",
  "installPath":"$c/plugins/cache/context-lab/context-lab/$sha",
  "version":"$sha","gitCommitSha":"$sha"}]}}
JSON

  cp "$o/claude/statusline-dispatch.sh" "$c/statusline-dispatch.sh"
  chmod +x "$c/statusline-dispatch.sh"
  ln -sfn "$m/claude/statusline.sh"          "$c/statusline.sh"
  ln -sfn "$m/claude/hooks/token-tracker.sh" "$c/hooks/token-tracker.sh"
  printf '@%s/plugins/marketplaces/context-lab/claude/CLAUDE.md\n' "$c" > "$c/CLAUDE.md"

  printf 'export MAX_MCP_OUTPUT_TOKENS=500000\n' > "$t/.bashrc"
  printf 'export CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS=0\n' >> "$t/.bashrc"
  printf 'export CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT=0\n' >> "$t/.bashrc"

  printf '%s\n' "$t"
}

audit() { # audit <sandbox> [extra args...]
  local t="$1"; shift
  HOME="$t" SHELL=/bin/bash CLAUDE_CONFIG_DIR="$t/.claude" \
    bash "$AUDIT" --repo-url "$t/origin" "$@" 2>&1
}

# Commit something harmless on the remote, so the clone falls behind.
advance_remote() { git_q -C "$1/origin" commit -q --allow-empty -m later >/dev/null 2>&1; }

printf '\n== a host that matches remote HEAD has no drift ==\n'
T=$(sandbox)
OUT=$(audit "$T" --no-refresh); RC=$?
is "exit 0" "$RC" "0"
has "and says so" "$OUT" "no drift"
hasnt "nothing is repairable" "$OUT" "[install]"
hasnt "nothing needs approval" "$OUT" "[approve]"
hasnt "and no check went unrun" "$OUT" "unknown"

printf '\n== a failed fetch audits nothing, and never falls back ==\n'
T=$(sandbox)
git_q -C "$T/.claude/plugins/marketplaces/context-lab" remote set-url origin "$T/gone.git"
OUT=$(audit "$T" --no-refresh); RC=$?
is "exit 2, distinct from both audited outcomes" "$RC" "2"
has "it names the remote it could not reach" "$OUT" "$T/gone.git"
has "and says nothing was audited" "$OUT" "Nothing was audited"
hasnt "the dispatcher is never compared against the local copy" "$OUT" "dispatcher"
hasnt "nor is anything reported as healthy" "$OUT" "  ok "

printf '\n== behind remote HEAD is a fact, not a failure ==\n'
T=$(sandbox)
advance_remote "$T"
OUT=$(audit "$T" --no-refresh); RC=$?
is "exit 0 -- an ancestor is a healthy host" "$RC" "0"
has "the distance is reported" "$OUT" "1 commit(s) behind remote HEAD"
has "with what closes it" "$OUT" "walks this forward"
hasnt "and it is not counted as drift" "$OUT" "[install]"

printf '\n== a clone that is not an ancestor is drift ==\n'
T=$(sandbox)
advance_remote "$T"
git_q -C "$T/.claude/plugins/marketplaces/context-lab" commit -q --allow-empty -m local >/dev/null 2>&1
OUT=$(audit "$T" --no-refresh); RC=$?
is "exit 1" "$RC" "1"
has "named as a divergence" "$OUT" "diverged from remote HEAD"

printf '\n== an old dispatcher is repairable by the installer ==\n'
T=$(sandbox)
sed 's/^# dispatcher-version: .*/# dispatcher-version: 0/' \
  "$T/.claude/statusline-dispatch.sh" > "$T/d" && mv "$T/d" "$T/.claude/statusline-dispatch.sh"
OUT=$(audit "$T" --no-refresh)
has "the version gap is named" "$OUT" "dispatcher is v0, intent is v1"
has "and classed as installer work" "$OUT" "[install] dispatcher is v0"

printf '\n== a same-version dispatcher with different bytes is still drift ==\n'
T=$(sandbox)
printf '\n# hand-edited\n' >> "$T/.claude/statusline-dispatch.sh"
has "byte drift is caught, not just the marker" "$(audit "$T" --no-refresh)" "bytes differ from intent"

printf '\n== a missing memory import is repairable by the installer ==\n'
T=$(sandbox)
: > "$T/.claude/CLAUDE.md"
has "named" "$(audit "$T" --no-refresh)" "does not import this repository's memory block"

printf '\n== an import pointing at nothing is caught, though the line is there ==\n'
T=$(sandbox)
rm -f "$T/.claude/plugins/marketplaces/context-lab/claude/CLAUDE.md"
OUT=$(audit "$T" --no-refresh)
has "the silent no-op is reported" "$OUT" "the import resolves to nothing"

printf '\n== a link replaced by a real file stops tracking silently, and is caught ==\n'
T=$(sandbox)
rm -f "$T/.claude/statusline.sh"; printf 'copy\n' > "$T/.claude/statusline.sh"
has "named" "$(audit "$T" --no-refresh)" "is a regular file, not a link into a clone"

printf '\n== a hand-edited owned key is caught, and named ==\n'
T=$(sandbox)
jq '.effortLevel = "high"' "$T/.claude/settings.json" > "$T/s" && mv "$T/s" "$T/.claude/settings.json"
has "the key is named" "$(audit "$T" --no-refresh)" 'key `effortLevel` does not match'

printf '\n== a stale hook entry needs approval, not a re-run ==\n'
T=$(sandbox)
mkdir -p "$T/origin/hooks"
cat > "$T/origin/hooks/hooks.json" <<'JSON'
{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command",
  "command":"bash ${CLAUDE_PLUGIN_ROOT}/hooks/token-tracker.sh UserPromptSubmit"}]}]}}
JSON
git_q -C "$T/origin" add -A >/dev/null 2>&1
git_q -C "$T/origin" commit -qm hooks >/dev/null 2>&1
OUT=$(audit "$T" --no-refresh); RC=$?
is "exit 1" "$RC" "1"
has "classed as needing approval, never as installer work" "$OUT" "[approve] settings.json declares hooks.UserPromptSubmit"
has "the consequence is spelled out" "$OUT" "runs twice per UserPromptSubmit"
has "and it is not applied" "$OUT" "which is not applied by this script"
has "the count separates the two classes" "$OUT" "1 needing an approved edit"

REMOVED=$(printf '%s\n' "$OUT" | grep -E '^ *-' | grep token-tracker)
has "the proposed edit removes the duplicated entry" "$REMOVED" "UserPromptSubmit"
hasnt "and leaves the entry the plugin does not declare alone" "$REMOVED" "PostToolUse"

printf '\n== the same command spelled two ways still matches ==\n'
# The settings file says `~/.claude/hooks/...`; the plugin manifest says
# `${CLAUDE_PLUGIN_ROOT}/hooks/...`. A literal comparison finds nothing.
has "matched by signature, not by string" "$OUT" 'bash ~/.claude/hooks/token-tracker.sh UserPromptSubmit'

printf '\n== a manifest that cannot be parsed is unknown, never green ==\n'
T=$(sandbox)
sed '/^SETTINGS_UNSET=(/,/^)/d' "$T/origin/install.sh" > "$T/i" && mv "$T/i" "$T/origin/install.sh"
git_q -C "$T/origin" commit -aqm strip >/dev/null 2>&1
OUT=$(audit "$T" --no-refresh); RC=$?
has "the check reports that it could not run" "$OUT" "could not read SETTINGS_UNSET"
is "and that counts against the verdict" "$RC" "1"
has "counted in its own column" "$OUT" "1 check(s) that could not run"

printf '\n== the cached remote head is refreshed, and merged not replaced ==\n'
T=$(sandbox)
printf '{"heads":{"somewhere-else":"0123456789ab"}}\n' > "$T/.claude/plugins/.remote-heads.json"
audit "$T" >/dev/null
HEADS="$T/.claude/plugins/.remote-heads.json"
WANT=$(git_q -C "$T/origin" rev-parse HEAD | cut -c1-12)
is "this marketplace's head is written" "$(jq -r '.heads["context-lab"]' "$HEADS")" "$WANT"
is "another marketplace's entry survives" "$(jq -r '.heads["somewhere-else"]' "$HEADS")" "0123456789ab"
if [ -n "$(jq -r '.fetchedAt // empty' "$HEADS")" ]; then pass "fetchedAt is stamped"; else fail "fetchedAt is stamped"; fi

printf '\n== --no-refresh writes nothing at all ==\n'
T=$(sandbox)
printf '{"heads":{"somewhere-else":"0123456789ab"}}\n' > "$T/.claude/plugins/.remote-heads.json"
BEFORE=$(cat "$T/.claude/plugins/.remote-heads.json")
audit "$T" --no-refresh >/dev/null
is "the cache is untouched" "$(cat "$T/.claude/plugins/.remote-heads.json")" "$BEFORE"

printf '\n== a host with no marketplace clone still gets an answer ==\n'
T=$(sandbox)
rm -rf "$T/.claude/plugins/marketplaces/context-lab"
OUT=$(audit "$T" --no-refresh); RC=$?
is "exit 1 -- it audited, and found drift" "$RC" "1"
has "the missing clone is the drift" "$OUT" "no marketplace clone at"
has "intent still came from the remote" "$OUT" "throwaway clone"

printf '\n== it says what it cannot see, on every run ==\n'
T=$(sandbox)
OUT=$(audit "$T" --no-refresh)
has "this host only" "$OUT" "an audit never enumerates machines"
has "and only what this repository ships" "$OUT" "anything installed from another source is invisible"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
