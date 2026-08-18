#!/usr/bin/env bash
#
# Install the user tier of Claude Code config onto this host.
#
#   ./install.sh            install (idempotent — safe to re-run)
#   ./install.sh --check    verify only, mutate nothing, non-zero exit on drift
#   ./install.sh --dry-run  print every mutation without performing it
#
# Escape hatches (all valid with --check too):
#   --no-rtk     skip the rtk install + `rtk init -g`
#   --no-plugin  skip the marketplace plugin
#   --no-shell   skip the shell-export block
#
# The whole design is symlinks, not copies. An edit made on a host writes
# straight into the tracked file, so drift shows up as `git status` output in
# the clone. Copies make the same edit invisible — which is exactly how joon's
# bc->awk statusline fix went unnoticed for weeks.
#
# Honours $CLAUDE_CONFIG_DIR (Claude Code does too), so the whole installer can
# be exercised against a throwaway directory without touching the real one.

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
MANIFEST="$REPO/claude/settings.owned.json"
STAMP="$(date +%Y%m%dT%H%M%S)"

MODE=install
DO_RTK=1
DO_PLUGIN=1
DO_SHELL=1

for arg in "$@"; do
  case "$arg" in
    --check)     MODE=check ;;
    --dry-run)   MODE=dryrun ;;
    --no-rtk)    DO_RTK=0 ;;
    --no-plugin) DO_PLUGIN=0 ;;
    --no-shell)  DO_SHELL=0 ;;
    -h|--help)   sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------- manifest ---

# Files symlinked from the clone into $CLAUDE_DIR, as "<repo path>|<claude path>".
# Never a directory symlink: $CLAUDE_DIR also holds .credentials.json,
# history.jsonl, projects/, sessions/ and 20-odd other runtime entries owned by
# Claude Code itself. Linking the directory would put all of that in git.
# claude/CLAUDE.md is deliberately absent: user memory is composed by @-import
# in step 4b, not linked. Linking it made two installers compete for ownership
# of one file, and let rtk write through the link into a tracked repo (ADR 0009).
LINKS=(
  "claude/statusline.sh|statusline.sh"
  "claude/hooks/token-tracker.sh|hooks/token-tracker.sh"
)

# Keys that must be REMOVED from settings.json. A jq merge can add or change a
# key but never delete one, so without this list a dead key survives on every
# host forever.
#   enabledMcpjsonServers — ["proxy"], a dangling reference to a .mcp.json
#   server that no longer exists; the proxy is registered at account level now.
#   agent — "gsd-lite", the retired default agent. Found live at user tier on
#   joon during the fleet rollout, pinning every session there to a 10 KB fork
#   of an agent file this effort retires. It is not in sandbox-cc, so freezing
#   that repo does not reach it. Unset rather than owned: the target state is no
#   agent default at all, and agents are skills.
SETTINGS_UNSET=(
  enabledMcpjsonServers
  agent
)

# Binaries the user tier genuinely needs.
REQUIRED_BINS=(jq awk sed git curl)
# Wanted, but nothing here hard-fails without them.
OPTIONAL_BINS=(flock sha256sum node gh rg)
# Deliberately absent: bc. joon has never had it, and both consumers
# (statusline.sh, token-tracker.sh) were moved to awk precisely so that this
# installer never has to install a package manager's worth of dependency.

# ------------------------------------------------------------------- output ---

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
[ -t 1 ] || { RED=; GRN=; YLW=; DIM=; RST=; }

FAILURES=0
ok()   { printf '  %sok%s    %s\n' "$GRN" "$RST" "$1"; }
warn() { printf '  %swarn%s  %s\n' "$YLW" "$RST" "$1"; }
bad()  { printf '  %sFAIL%s  %s\n' "$RED" "$RST" "$1"; FAILURES=$((FAILURES + 1)); }
step() { printf '\n%s==>%s %s\n' "$DIM" "$RST" "$1"; }
would() { printf '  %swould%s %s\n' "$DIM" "$RST" "$1"; }

# Returns 0 when we should actually change something on disk.
mutating() { [ "$MODE" = install ]; }

# ------------------------------------------------------------ 1. prereqs -----

check_prereqs() {
  step "1. prerequisites"
  for b in "${REQUIRED_BINS[@]}"; do
    if command -v "$b" >/dev/null 2>&1; then ok "$b"; else bad "$b is required and missing"; fi
  done
  for b in "${OPTIONAL_BINS[@]}"; do
    if command -v "$b" >/dev/null 2>&1; then ok "$b"; else warn "$b missing (optional)"; fi
  done
  if command -v node >/dev/null 2>&1; then
    ok "node $(node --version)"
  fi
}

# ---------------------------------------------------------------- 2. rtk -----

install_rtk() {
  step "2. rtk"
  [ "$DO_RTK" -eq 1 ] || { warn "skipped (--no-rtk)"; return 0; }

  if command -v rtk >/dev/null 2>&1; then
    ok "rtk present ($(rtk --version 2>/dev/null || echo 'version unknown'))"
  elif mutating; then
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
    ok "rtk installed"
  else
    [ "$MODE" = check ] && bad "rtk not installed" || would "install rtk"
    return 0
  fi

  # Two commands, not one: rtk's own install.sh writes only the binary and
  # touches nothing under $CLAUDE_DIR. `rtk init -g` is what owns the harness
  # surfaces -- and --auto-patch is required, because the default PatchMode::Ask
  # blocks on stdin and would hang a non-interactive install forever.
  if mutating; then
    rtk init -g --auto-patch
    ok "rtk init -g --auto-patch"
  elif [ "$MODE" = dryrun ]; then
    would "rtk init -g --auto-patch"
  fi
  # Nothing to assert in --check: rtk's own surfaces are verified where they
  # land, by the hooks.PreToolUse canary in step 5.
}

# ------------------------------------------------------------- 3. plugin -----

# Two plugins, one mechanism. The upstream one hydrates third-party skills onto
# the host (docs/third-party-skills.md records which upstream, at which sha,
# under which licence -- scripts/third-party-gate.sh asserts that id and that
# file agree). The second is this repo: skills/stable/ ships as the `context-lab`
# plugin out of a marketplace whose source is the *GitHub repo* -- so a host needs
# no clone, the marketplace serves the default branch, and `claude plugin update`
# is the real update verb (ADR 0008, superseding the directory source of 0006).
#
# Each spec is `plugin|marketplace|source`. An empty source means the marketplace
# is already known to the CLI and must not be added. Written as a newline list
# and read with `while read`, not an array: bash 3.2 on m3 makes "${arr[@]}" on
# an empty array fatal under `set -u`, and a plain string has no such edge.
PLUGIN_SPECS="mattpocock-skills|claude-plugins-official|
context-lab|context-lab|luutuankiet/context-lab"

install_plugin() {
  step "3. marketplace plugins"
  [ "$DO_PLUGIN" -eq 1 ] || { warn "skipped (--no-plugin)"; return 0; }

  if ! command -v claude >/dev/null 2>&1; then
    warn "claude CLI not on PATH; no plugin can be installed"
    return 0
  fi

  # One `plugin list` for the whole step: it shells out to the CLI, and the set
  # of installed plugins cannot change while this function runs.
  local installed
  installed=$(claude plugin list 2>/dev/null || true)

  # A here-string, not a pipe: a piped `while read` runs in a subshell, and every
  # bad() inside it would increment a FAILURES that dies with that subshell --
  # leaving `--check` exiting 0 on a host with no plugins at all.
  while IFS='|' read -r plugin marketplace source; do
    [ -n "$plugin" ] || continue
    eval "source=\"$source\""
    install_one_plugin "$plugin" "$marketplace" "$source" "$installed"
  done <<< "$PLUGIN_SPECS"
}

# Add a marketplace if the CLI has never heard of it. Adding is idempotent in the
# CLI, but it also *rewrites user settings*, so it is gated on the list rather
# than run blind on every install.
add_marketplace() {
  local marketplace="$1" source="$2"
  [ -n "$source" ] || return 0
  # Exact match on the name, never a substring: `context-lab` is a prefix of
  # `context-lab-private`, and an unanchored `grep -q "$marketplace"` matched the
  # private marketplace, returned early, and left context-lab unadded on every
  # host while the installer reported success. `awk '{print $NF}'` reduces each
  # line of the pretty listing to its last field -- the bare name on a name line,
  # something that cannot collide on any other -- so the guard depends on neither
  # the ❯ glyph nor --json, which the oldest CLI in the fleet predates.
  if claude plugin marketplace list 2>/dev/null | awk '{print $NF}' \
       | grep -qx "$marketplace"; then
    return 0
  fi
  if [ "$MODE" = check ]; then bad "marketplace $marketplace not configured"; return 1; fi
  if [ "$MODE" = dryrun ]; then would "claude plugin marketplace add $source"; return 1; fi
  if claude plugin marketplace add "$source" >/dev/null 2>&1; then
    ok "marketplace $marketplace added from $source"
  else
    bad "could not add marketplace $marketplace from $source"
    return 1
  fi
}

install_one_plugin() {
  local plugin="$1" marketplace="$2" source="$3" installed="$4"
  local id="$plugin@$marketplace"

  add_marketplace "$marketplace" "$source" || return 0

  # Exact match on the full plugin@marketplace id -- see add_marketplace for why
  # a substring match here is a silent no-op rather than a visible failure.
  if printf '%s\n' "$installed" | awk '{print $NF}' | grep -qx "$id"; then
    # A remote-source marketplace is a fetched copy, so this refresh *is* the
    # update -- `marketplace update` re-fetches the repo, `plugin update` re-reads
    # it. plugin.json still declares no version, so the recorded version is the
    # source commit sha and a push is always seen; a static version key would let
    # `plugin update` no-op while reporting success (ADR 0006, still true).
    # `plugin update` needs the full plugin@marketplace id; the bare name errors
    # with "Plugin not found".
    if mutating; then
      claude plugin marketplace update "$marketplace" >/dev/null 2>&1 || true
      claude plugin update "$id" >/dev/null 2>&1 || true
      ok "$id installed and updated"
    else
      ok "$id installed"
    fi
    return 0
  fi

  if [ "$MODE" = check ]; then bad "$id not installed"; return 0; fi
  if [ "$MODE" = dryrun ]; then would "claude plugin install $id"; return 0; fi

  # Nothing below may abort the run. This step used to be a bare
  # `claude plugin install "$plugin" && ok ...`, which under `set -e` exits the
  # whole installer when the install fails -- observed on a host that had never
  # fetched the marketplace, leaving it with rtk initialised and no symlinks, no
  # settings merge and no shell exports. A half-configured host is worse than a
  # reported failure, because nothing announces it.
  # No `-y`. The flag only matters for a marketplace-declared *command* install,
  # which neither of these is -- and it does not exist at all on the oldest CLI in
  # the fleet (2.1.81 on personal), where passing it fails the install outright
  # with `error: unknown option '-y'`.
  local out
  if out=$(claude plugin install "$id" 2>&1); then
    ok "$id installed"
    return 0
  fi
  printf '%s\n' "$out" | sed 's/^/        /'

  # A stale marketplace cache reports the plugin as "not found in marketplace"
  # rather than as a fetch error, so refresh once and retry before believing it.
  # That was the real cause on all three hosts rolled out after thinkpad.
  warn "refreshing the marketplace cache and retrying once"
  claude plugin marketplace update "$marketplace" >/dev/null 2>&1 || true
  if out=$(claude plugin install "$id" 2>&1); then
    ok "$id installed (after a marketplace refresh)"
  else
    printf '%s\n' "$out" | sed 's/^/        /'
    bad "$id could not be installed; the rest of the tier is still applied"
  fi
}

# ------------------------------------------------------- 4. symlink farm -----

link_files() {
  step "4. symlink farm -> $CLAUDE_DIR"

  for spec in "${LINKS[@]}"; do
    local src="$REPO/${spec%%|*}" dst="$CLAUDE_DIR/${spec##*|}"

    if [ ! -e "$src" ]; then bad "source missing: $src"; continue; fi

    # Already correct?
    if [ -L "$dst" ] && [ "$(readlink -f -- "$dst")" = "$(readlink -f -- "$src")" ]; then
      ok "${spec##*|} -> ${spec%%|*}"
      continue
    fi

    # The blind spot every symlink farm has: a link quietly replaced by a real
    # file keeps working, so nobody notices the host has stopped tracking.
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      if [ "$MODE" = check ]; then bad "${spec##*|} is a regular file, not a link into the clone"; continue; fi
      if mutating; then
        mkdir -p "$CLAUDE_DIR/backups"
        mv -- "$dst" "$CLAUDE_DIR/backups/$(basename -- "$dst").pre-context-lab.$STAMP"
        warn "backed up pre-existing $(basename -- "$dst")"
      else
        would "back up pre-existing $dst"
      fi
    fi

    if [ "$MODE" = check ]; then bad "${spec##*|} not linked"; continue; fi
    if mutating; then
      mkdir -p -- "$(dirname -- "$dst")"
      ln -sfn -- "$src" "$dst"
      ok "${spec##*|} -> ${spec%%|*}"
    else
      would "ln -sfn $src $dst"
    fi
  done

  # No skills are linked here, and none ever will be. Skills ship as the
  # `context-lab` plugin installed in step 3; ~/.claude/skills/ need not exist.
  # The linker this step used to guard on was never written -- see ADR 0006.
}

# ------------------------------------------------- 4b. user memory -----------

# The distinctive tail of the import line this installer owns. Any @-line ending
# in it is ours regardless of how the path was spelled, which is what makes the
# collapse below idempotent: rtk appended a second import precisely because it
# matched one literal spelling and missed the other (see
# docs/traps/RTK_IMPORT_APPENDED_TWICE.md).
MEMORY_IMPORT_TAIL='/plugins/marketplaces/context-lab/claude/CLAUDE.md'

# $CLAUDE_DIR/CLAUDE.md is a real, host-local file this installer does not own.
# It owns one line in it. Everything else -- rtk's @RTK.md, the private overlay's
# own import, and whatever the operator hand-writes -- is left exactly as found.
# The imported target is the *marketplace* clone, not the plugin cache: the cache
# is keyed by commit sha and gets a new directory on every push, while
# plugins/marketplaces/<name>/ is keyed by name and never moves.
memory_import() {
  step "4b. user memory -> $CLAUDE_DIR/CLAUDE.md"

  local dst="$CLAUDE_DIR/CLAUDE.md"
  # TAIL is already the whole path below $CLAUDE_DIR -- do not prepend any of it
  # again. Getting this wrong is invisible: the doubled path is self-consistent,
  # so the idempotence tests still pass and only the target-existence check below
  # notices that nothing is there.
  local src="$CLAUDE_DIR$MEMORY_IMPORT_TAIL"
  local line

  # Prefer the ~-anchored spelling: it is what a colleague's host gets, so the
  # file reads the same everywhere. Fall back to absolute when $CLAUDE_DIR has
  # been pointed somewhere else, which is how test-install.sh exercises this.
  case "$src" in
    "$HOME"/*) line="@~${src#"$HOME"}" ;;
    *)         line="@$src" ;;
  esac

  # Migration. This file used to be a symlink into the clone. That made the two
  # tiers compete for ownership of one file and let a third-party tool write
  # through into a tracked repo; the content it pointed at is now reached by the
  # import instead, so removing the link loses nothing.
  if [ -L "$dst" ]; then
    if [ "$MODE" = check ]; then
      bad "CLAUDE.md is still a symlink into a clone -- re-run install to migrate"
      return 0
    elif mutating; then
      rm -f -- "$dst"
      warn "removed the legacy CLAUDE.md symlink (memory now composes by import)"
    else
      would "rm $dst (legacy symlink into the clone)"
    fi
  fi

  # An @-import whose target is missing is a *silent* no-op: no error, no
  # warning, zero exit, siblings still load. So the line being present proves
  # nothing on its own -- `marketplace update` deletes the directory and
  # re-clones it rather than pulling, and a re-clone that fails (no network, no
  # git auth) leaves the line pointing at nothing. Without this the host runs
  # with no memory and --check stays green. warn, not bad: a dev-clone install
  # or a sandboxed test legitimately has no marketplace directory yet.
  [ -e "$src" ] || warn "import target is missing: $src (run: claude plugin marketplace update context-lab)"

  local found=0
  if [ -f "$dst" ]; then
    found=$(awk -v tail="$MEMORY_IMPORT_TAIL" \
      'index($0, "@") == 1 && index($0, tail) == length($0) - length(tail) + 1 { n++ }
       END { print n+0 }' "$dst")
  fi

  if [ "$found" -eq 1 ] && [ -f "$dst" ] && grep -Fqx -- "$line" "$dst"; then
    ok "import present exactly once"
    return 0
  fi

  if [ "$MODE" = check ]; then
    case "$found" in
      0) bad "CLAUDE.md does not import the context-lab memory block" ;;
      1) bad "CLAUDE.md imports the memory block by a different path than $line" ;;
      *) bad "CLAUDE.md imports the memory block $found times" ;;
    esac
    return 0
  fi
  if ! mutating; then
    [ "$found" -eq 0 ] && would "add '$line' to $dst" || would "collapse $found memory imports in $dst to '$line'"
    return 0
  fi

  local tmp="$dst.context-lab.$$"
  if [ "$found" -eq 0 ]; then
    # Insert into the leading import header rather than appending, so anything
    # the operator has written below stays below -- the free region is where a
    # host overrides the block, and an override under an import is the point.
    if [ -f "$dst" ]; then
      awk -v line="$line" '
        BEGIN { header = 1; inserted = 0 }
        {
          if (header && $0 !~ /^@/ && $0 !~ /^[[:space:]]*$/) { print line; inserted = 1; header = 0 }
          print
        }
        END { if (!inserted) print line }' "$dst" > "$tmp" && mv -- "$tmp" "$dst"
    else
      mkdir -p -- "$(dirname -- "$dst")"
      printf '%s\n' "$line" > "$dst"
    fi
    ok "added $line"
  else
    # Any spelling of our import collapses to one canonical line, in place.
    awk -v line="$line" -v tail="$MEMORY_IMPORT_TAIL" '
      index($0, "@") == 1 && index($0, tail) == length($0) - length(tail) + 1 {
        if (!seen) { print line; seen = 1 }
        next
      }
      { print }' "$dst" > "$tmp" && mv -- "$tmp" "$dst"
    ok "collapsed $found memory import(s) to one canonical line"
  fi
}

# ---------------------------------------------------- 5. settings merge ------

# Deep-merge the manifest over live settings, then delete the unset keys.
merged_settings() {
  local live="$1" unset_json
  unset_json=$(printf '%s\n' "${SETTINGS_UNSET[@]}" | jq -R . | jq -s .)
  jq -s --argjson unset "$unset_json" \
    '(.[0] * .[1]) | delpaths([$unset[] | [.]])' "$live" "$MANIFEST"
}

merge_settings() {
  step "5. settings.json"

  [ -f "$MANIFEST" ] || { bad "manifest missing: $MANIFEST"; return 0; }
  jq -e . "$MANIFEST" >/dev/null 2>&1 || { bad "manifest is not valid JSON"; return 0; }

  local live="$SETTINGS"
  if [ ! -f "$live" ]; then
    if [ "$MODE" = check ]; then bad "no settings.json at $live"; return 0; fi
    live=$(mktemp); echo '{}' > "$live"
  elif ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
    # Never overwrite a file we cannot parse -- that is how a settings.json
    # gets truncated and a host loses every preference at once.
    bad "$SETTINGS is not valid JSON; refusing to touch it"
    return 0
  fi

  local desired current had_pretooluse
  desired=$(merged_settings "$live" | jq -S .)
  current=$(jq -S . "$live")
  # Snapshot before we write, so the canary below tests "did the merge destroy
  # it" rather than "does it exist" -- on a host where rtk has not been
  # initialised yet there is nothing to preserve and nothing to complain about.
  had_pretooluse=$(jq -r 'if (.hooks.PreToolUse // null) == null then "no" else "yes" end' "$live")

  if [ "$desired" = "$current" ]; then
    ok "all owned keys already applied"
  elif [ "$MODE" = check ]; then
    bad "settings.json drifted from the manifest"
    diff <(printf '%s\n' "$current") <(printf '%s\n' "$desired") | sed 's/^/        /' || true
  elif mutating; then
    # Write to a temp file and mv, so an interrupted install can never leave a
    # half-written settings.json behind.
    local tmp; tmp=$(mktemp)
    printf '%s\n' "$(merged_settings "$live")" > "$tmp"
    jq -e . "$tmp" >/dev/null || { bad "refusing to install malformed settings.json"; rm -f "$tmp"; return 0; }
    mkdir -p -- "$CLAUDE_DIR"
    mv -- "$tmp" "$SETTINGS"
    ok "owned keys applied"
  else
    would "merge $(jq -r 'keys | length' "$MANIFEST") owned keys into $SETTINGS"
    diff <(printf '%s\n' "$current") <(printf '%s\n' "$desired") | sed 's/^/        /' || true
  fi

  # Canary. `hooks` is merged key-wise, so PreToolUse -- which `rtk init -g`
  # owns -- must survive our write. Naming PreToolUse in the manifest would
  # erase rtk's entry on every single install, because `*` replaces arrays
  # wholesale rather than appending to them.
  if [ "$had_pretooluse" = yes ] && [ -f "$SETTINGS" ]; then
    if jq -e '.hooks.PreToolUse // empty' "$SETTINGS" >/dev/null 2>&1; then
      ok "rtk's hooks.PreToolUse survived the merge"
    else
      bad "hooks.PreToolUse is gone -- the merge ate rtk's hook"
    fi
  elif command -v rtk >/dev/null 2>&1 && [ "$DO_RTK" -eq 1 ]; then
    warn "no hooks.PreToolUse yet -- run \`rtk init -g --auto-patch\` to install it"
  fi

  for k in "${SETTINGS_UNSET[@]}"; do
    if [ -f "$SETTINGS" ] && jq -e --arg k "$k" 'has($k)' "$SETTINGS" >/dev/null 2>&1; then
      [ "$MODE" = check ] && bad "$k still present" || would "delete $k"
    else
      ok "$k unset"
    fi
  done
}

# ------------------------------------------------------ 6. shell exports -----

BEGIN_MARK="# >>> context-lab user tier >>>"
END_MARK="# <<< context-lab user tier <<<"

shell_exports() {
  step "6. shell exports"
  [ "$DO_SHELL" -eq 1 ] || { warn "skipped (--no-shell)"; return 0; }

  local vars=("MAX_MCP_OUTPUT_TOKENS=500000" "CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS=0" "CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT=0")

  # Only the login shell's rc is required. Most hosts here have a .bashrc they
  # never source -- demanding the exports in every rc file that happens to
  # exist would fail every zsh host in the fleet for no reason.
  local rc
  case "$(basename -- "${SHELL:-/bin/bash}")" in
    zsh)  rc="$HOME/.zshrc" ;;
    bash) rc="$HOME/.bashrc" ;;
    *)    rc="$HOME/.profile" ;;
  esac

  local missing=()
  for v in "${vars[@]}"; do
    [ -f "$rc" ] && grep -Fq "export $v" "$rc" || missing+=("$v")
  done

  if [ ${#missing[@]} -eq 0 ]; then
    # Set outside our block is fine -- thinkpad has had these hand-written
    # since long before this installer existed. Adopting them into the managed
    # block is a manual one-liner, not something to do behind someone's back in
    # their login shell.
    if grep -Fq "$BEGIN_MARK" "$rc"; then ok "$(basename "$rc"): managed block present"
    else ok "$(basename "$rc"): already exported (unmanaged)"; fi
    return 0
  fi

  # MAX_MCP_OUTPUT_TOKENS is load-bearing, not cosmetic: without it large MCP
  # results are silently truncated, which reads as a broken tool rather than a
  # missing export.
  if [ "$MODE" = check ]; then
    bad "$(basename "$rc"): missing ${missing[*]}"
  elif mutating; then
    { printf '\n%s\n' "$BEGIN_MARK"
      for v in "${missing[@]}"; do printf 'export %s\n' "$v"; done
      printf '%s\n' "$END_MARK"; } >> "$rc"
    ok "$(basename "$rc"): appended ${missing[*]}"
  else
    would "append ${missing[*]} to $rc"
  fi
}

# --------------------------------------------------------------- run ---------

case "$MODE" in
  check)  printf '%schecking%s user tier against %s\n' "$DIM" "$RST" "$CLAUDE_DIR" ;;
  dryrun) printf '%sdry run%s  against %s -- nothing will be written\n' "$DIM" "$RST" "$CLAUDE_DIR" ;;
  *)      printf '%sinstalling%s user tier into %s\n' "$DIM" "$RST" "$CLAUDE_DIR" ;;
esac
printf '%ssource%s     %s\n' "$DIM" "$RST" "$REPO"

check_prereqs
install_rtk
install_plugin
link_files
memory_import
merge_settings
shell_exports

printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '%sall good%s\n' "$GRN" "$RST"
else
  printf '%s%d problem(s)%s\n' "$RED" "$FAILURES" "$RST"
  exit 1
fi
