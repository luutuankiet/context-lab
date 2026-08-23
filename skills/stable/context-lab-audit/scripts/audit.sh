#!/usr/bin/env bash
#
# Does what is on this host match what this repository intends?
#
#   audit.sh                audit this host and refresh the cached remote head
#   audit.sh --no-refresh   audit only; write nothing at all
#   audit.sh --claude-dir D audit a config directory other than the live one
#
# Exit status is the answer, so a caller never has to parse the prose:
#
#   0  audited, nothing drifted
#   1  audited, drift found
#   2  intent could not be established -- NOTHING was audited
#
# Intent is remote HEAD. Not the checkout on this disk, not a receipt written
# at install time: a receipt answers "what did I do last time", which is not
# the question being asked. Every intended value below is read out of the
# fetched commit with `git show`, never off the working tree -- so a host whose
# clone is behind is still audited against the truth rather than against
# whatever it happens to be holding.
#
# When the fetch fails there is no fallback. Comparing against the local copy
# would hand back a clean bill of health derived from a source this script has
# just finished calling unauthoritative, which is worse than no answer.
#
# It reads the installer's own manifests out of that same commit rather than
# restating them, so the two cannot disagree. When a manifest cannot be parsed
# the check reports `unknown` and counts as drift -- a check that silently
# passes because it could not run is the failure this script exists to refuse.
#
# This host only. It never enumerates machines, and it can only see what this
# repository ships; `--blind-spots` is printed at the end of every run.
#
# Written for bash 3.2 with no `timeout(1)` and no GNU coreutils, because the
# oldest host in the fleet has none of them.

set -uo pipefail

MARKETPLACE=context-lab
PLUGIN=context-lab
PLUGIN_ID="$PLUGIN@$MARKETPLACE"
REPO_URL="https://github.com/luutuankiet/context-lab.git"

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DO_REFRESH=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-refresh) DO_REFRESH=0; shift ;;
    --claude-dir) CLAUDE_DIR="$2"; shift 2 ;;
    --repo-url)   REPO_URL="$2"; shift 2 ;;
    -h|--help)    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

PLUGINS="$CLAUDE_DIR/plugins"
MKT_DIR="$PLUGINS/marketplaces/$MARKETPLACE"
SETTINGS="$CLAUDE_DIR/settings.json"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/context-lab-audit.XXXXXX") || exit 2
trap 'rm -rf -- "$WORK"' EXIT INT TERM

# ------------------------------------------------------------------ output ---

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
[ -t 1 ] || { RED=; GRN=; YLW=; DIM=; RST=; }

N_INSTALLER=0
N_APPROVE=0
N_UNKNOWN=0

step()      { printf '\n%s==>%s %s\n' "$DIM" "$RST" "$1"; }
ok()        { printf '  %sok%s        %s\n' "$GRN" "$RST" "$1"; }
# A fact is a difference that is not a fault. Reporting one as a failure trains
# the reader to ignore the whole report, which costs more than the fact is worth.
fact()      { printf '  %sfact%s      %s\n' "$DIM" "$RST" "$1"; }
note()      { printf '            %s\n' "$1"; }

# Class one: re-running the installer is the repair, and a human runs it.
installer() { printf '  %sdrift%s     %s[install]%s %s\n' "$YLW" "$RST" "$DIM" "$RST" "$1"
              N_INSTALLER=$((N_INSTALLER + 1)); }
# Class two: nothing you can run fixes it, because the settings merge adds and
# changes but never deletes. The edit is proposed and applied only on approval.
approve()   { printf '  %sdrift%s     %s[approve]%s %s\n' "$RED" "$RST" "$DIM" "$RST" "$1"
              N_APPROVE=$((N_APPROVE + 1)); }
# The check could not run. Never silently green.
unknown()   { printf '  %sunknown%s   %s\n' "$RED" "$RST" "$1"
              N_UNKNOWN=$((N_UNKNOWN + 1)); }

stop() { # <reason>
  printf '\n%scould not establish intent%s\n' "$RED" "$RST"
  printf '  %s\n' "$1"
  printf '\nNothing was audited. Intent is remote HEAD and there is no fallback:\n'
  printf 'comparing against the copy on this disk would report health derived\n'
  printf 'from a source that has just been declared unauthoritative.\n'
  exit 2
}

# ------------------------------------------------------------------ intent ---

step "1. intent -- remote HEAD"

INTENT_DIR=
INTENT=
REMOTE_URL=

if [ -d "$MKT_DIR/.git" ]; then
  REMOTE_URL=$(git -C "$MKT_DIR" config --get remote.origin.url 2>/dev/null)
  [ -n "$REMOTE_URL" ] || stop "the clone at $MKT_DIR has no origin remote"
  # `origin HEAD`, not a bare `origin`: it writes exactly one FETCH_HEAD, which
  # is the remote's default branch tip and nothing else.
  if ! err=$(git -C "$MKT_DIR" fetch --quiet origin HEAD 2>&1); then
    stop "could not reach $REMOTE_URL -- $(printf '%s' "$err" | tr '\n' ' ')"
  fi
  INTENT=$(git -C "$MKT_DIR" rev-parse FETCH_HEAD 2>/dev/null)
  INTENT_DIR="$MKT_DIR"
else
  # No marketplace clone on this host. That is itself drift, reported below,
  # but intent still has to come from the remote rather than from nothing.
  REMOTE_URL="$REPO_URL"
  if ! err=$(git clone --quiet --depth 1 "$REPO_URL" "$WORK/intent" 2>&1); then
    stop "could not reach $REPO_URL -- $(printf '%s' "$err" | tr '\n' ' ')"
  fi
  INTENT=$(git -C "$WORK/intent" rev-parse HEAD 2>/dev/null)
  INTENT_DIR="$WORK/intent"
fi

[ -n "${INTENT:-}" ] || stop "fetched $REMOTE_URL but could not resolve its HEAD"
ok "remote HEAD $INTENT"
note "$REMOTE_URL"

# Every intended byte in this script comes through here.
show() { git -C "$INTENT_DIR" show "$INTENT:$1" 2>/dev/null; }

INSTALLER_SRC="$WORK/install.sh"
show install.sh > "$INSTALLER_SRC" 2>/dev/null || true
[ -s "$INSTALLER_SRC" ] || unknown "remote HEAD carries no install.sh -- every manifest below is unreadable"

# Elements of a bash array literal in the installer source. The installer is
# the manifest; duplicating its values here would let the two drift apart
# silently, which is the exact failure mode this whole script is about.
array_elems() { # <array name>
  awk -v n="$1" '
    $0 ~ "^"n"=\\(" { inb = 1; next }
    inb && /^\)/     { exit }
    inb              { gsub(/^[ \t]+|[ \t]+$/, ""); gsub(/"/, "");
                       if ($0 != "" && $0 !~ /^#/) print }
  ' "$INSTALLER_SRC" 2>/dev/null
}

scalar_value() { # <variable name> -- the single-quoted or bare value
  awk -v n="$1" '$0 ~ "^"n"=" { sub("^"n"=", ""); gsub(/^['"'"'"]|['"'"'"]$/, ""); print; exit }' \
    "$INSTALLER_SRC" 2>/dev/null
}

# ---------------------------------------------------- 2. behind or diverged ---

step "2. the clone this host serves plugins from"

if [ "$INTENT_DIR" != "$MKT_DIR" ]; then
  installer "no marketplace clone at $MKT_DIR"
  note "intent was read from a throwaway clone instead"
  CLONE_HEAD=
else
  CLONE_HEAD=$(git -C "$MKT_DIR" rev-parse HEAD 2>/dev/null)
  if [ "$CLONE_HEAD" = "$INTENT" ]; then
    ok "at remote HEAD"
  elif git -C "$MKT_DIR" merge-base --is-ancestor "$CLONE_HEAD" "$INTENT" 2>/dev/null; then
    behind=$(git -C "$MKT_DIR" rev-list --count "$CLONE_HEAD..$INTENT" 2>/dev/null)
    # Behind is not drift. The platform runs its own plugin update once per
    # session start, which walks an ancestor forward without anyone owning a
    # scheduler. Reporting this as a failure would be reporting the mechanism
    # working.
    fact "$behind commit(s) behind remote HEAD, and an ancestor of it"
    note "the platform's own update walks this forward at the next session start"
  else
    installer "the clone has diverged from remote HEAD -- $CLONE_HEAD is not an ancestor"
  fi

  dirty=$(git -C "$MKT_DIR" status --porcelain 2>/dev/null)
  if [ -n "$dirty" ]; then
    installer "tracked files are modified in the clone"
    printf '%s\n' "$dirty" | sed 's/^/            /'
  else
    ok "no modified tracked files"
  fi
fi

# ----------------------------------------------------------- 3. the plugin ---

step "3. the installed plugin"

INSTALLED_JSON="$PLUGINS/installed_plugins.json"
install_path=
if [ -f "$INSTALLED_JSON" ]; then
  install_path=$(jq -r --arg k "$PLUGIN_ID" '(.plugins[$k] // [])[0] // {} | .installPath // ""' \
                   "$INSTALLED_JSON" 2>/dev/null)
fi

if [ -z "${install_path:-}" ]; then
  installer "$PLUGIN_ID is not installed on this host"
elif [ ! -d "$install_path" ]; then
  installer "$PLUGIN_ID records an install directory that is not there: $install_path"
else
  # The directory is named for the commit the plugin was built from, and
  # `installPath` is the truth where `gitCommitSha` and it disagree -- they do,
  # on a host that has updated more than once.
  built_from="${install_path##*/}"
  if [ -n "$CLONE_HEAD" ] && [ "${CLONE_HEAD#"$built_from"}" = "$CLONE_HEAD" ]; then
    installer "the plugin was built from $built_from but the clone is at $(printf '%s' "$CLONE_HEAD" | cut -c1-12)"
    note "a plugin update is pending against code the host already has"
  else
    ok "built from $built_from"
  fi
fi

enabled=$(jq -r --arg k "$PLUGIN_ID" '(.enabledPlugins // {})[$k] // false' "$SETTINGS" 2>/dev/null)
if [ "${enabled:-false}" = "true" ]; then
  ok "enabled in settings.json"
else
  installer "$PLUGIN_ID is not enabled in settings.json"
  note "an installed-but-disabled plugin also stops its statusline contributors from running"
fi

# ---------------------------------------------------------- 4. the settings ---

step "4. settings.json -- the keys this repository owns"

MANIFEST="$WORK/settings.owned.json"
show claude/settings.owned.json > "$MANIFEST" 2>/dev/null || true

if [ ! -s "$MANIFEST" ] || ! jq -e . "$MANIFEST" >/dev/null 2>&1; then
  unknown "remote HEAD has no readable claude/settings.owned.json"
elif [ ! -f "$SETTINGS" ]; then
  installer "no settings.json at $SETTINGS"
elif ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  unknown "$SETTINGS is not valid JSON -- nothing about it can be checked"
else
  # The same deep merge the installer performs. If applying it changes nothing,
  # every owned key already holds its intended value.
  differing=$(jq -s -r '
      . as [$live, $man]
      | ($live * $man) as $want
      | [ $man | keys[] ] | map(select(($want[.] | tojson) != ($live[.] | tojson))) | .[]
    ' "$SETTINGS" "$MANIFEST" 2>/dev/null)
  if [ -z "$differing" ]; then
    ok "all $(jq -r 'keys | length' "$MANIFEST") owned keys hold their intended value"
  else
    for k in $differing; do
      installer "settings.json key \`$k\` does not match the manifest at remote HEAD"
    done
  fi

  unset_keys=$(array_elems SETTINGS_UNSET)
  if [ -z "$unset_keys" ]; then
    unknown "could not read SETTINGS_UNSET out of install.sh at remote HEAD"
  else
    for k in $unset_keys; do
      if jq -e --arg k "$k" 'has($k)' "$SETTINGS" >/dev/null 2>&1; then
        installer "settings.json still carries \`$k\`, which is on the unset list"
      else
        ok "\`$k\` unset"
      fi
    done
  fi
fi

# ------------------------------------------ 5. the one class nothing repairs ---

step "5. hook entries the settings merge can never remove"

# A jq merge adds a key and changes a key. It cannot delete one. So an entry
# that should go cannot be removed by running the installer again, however many
# times -- and an entry left pointing at a command the plugin now declares for
# itself makes that command run twice per event, silently.
#
# Commands are compared by signature, not literally: the same script is spelled
# `~/.claude/hooks/x.sh` in a settings file and `${CLAUDE_PLUGIN_ROOT}/hooks/x.sh`
# in a plugin manifest, and a literal comparison would never match the pair this
# check exists to find.
signature() { # <command string>
  printf '%s\n' "$1" | awk '{ for (i = 1; i <= NF; i++) { n = $i; sub(/.*\//, "", n); printf "%s%s", (i > 1 ? " " : ""), n } print "" }'
}

PLUGIN_HOOKS="$WORK/plugin-hooks.json"
show hooks/hooks.json > "$PLUGIN_HOOKS" 2>/dev/null || true

DUPES="$WORK/dupes"
: > "$DUPES"

if [ ! -s "$PLUGIN_HOOKS" ]; then
  ok "the plugin declares no hooks of its own at remote HEAD, so no entry can duplicate one"
elif ! jq -e . "$PLUGIN_HOOKS" >/dev/null 2>&1; then
  unknown "the plugin's hooks manifest at remote HEAD is not valid JSON"
elif [ ! -f "$SETTINGS" ] || ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  ok "no readable settings.json, so no stale entry to find"
else
  declared="$WORK/declared"
  jq -r '(.hooks // {}) | to_entries[] | .value[] | (.hooks // [])[] | .command // empty' \
    "$PLUGIN_HOOKS" 2>/dev/null > "$declared"

  # `<event>\t<group index>\t<hook index>\t<command>` for every entry in the
  # live settings file.
  jq -r '(.hooks // {}) | to_entries[] as $e
         | ($e.value | to_entries[]) as $g
         | ($g.value.hooks // [] | to_entries[]) as $h
         | [$e.key, ($g.key|tostring), ($h.key|tostring), ($h.value.command // "")] | @tsv' \
     "$SETTINGS" 2>/dev/null > "$WORK/live-hooks"

  while IFS="$(printf '\t')" read -r event gi hi cmd; do
    [ -n "${cmd:-}" ] || continue
    sig=$(signature "$cmd")
    while IFS= read -r dcmd; do
      [ -n "$dcmd" ] || continue
      [ "$sig" = "$(signature "$dcmd")" ] || continue
      approve "settings.json declares hooks.$event[$gi].hooks[$hi] -- the plugin now declares the same command"
      note "$cmd"
      note "left in place it runs twice per $event, once from settings and once from the plugin"
      printf '%s\t%s\t%s\n' "$event" "$gi" "$hi" >> "$DUPES"
      break
    done < "$declared"
  done < "$WORK/live-hooks"

  [ -s "$DUPES" ] || ok "no settings hook entry duplicates a plugin-declared command"
fi

if [ -s "$DUPES" ]; then
  # The exact edit, and what agreeing to it means, printed rather than applied.
  paths=$(awk -F'\t' 'BEGIN { printf "[" }
    { printf "%s[\"hooks\",\"%s\",%s,\"hooks\",%s]", (NR > 1 ? "," : ""), $1, $2, $3 }
    END { printf "]" }' "$DUPES")
  FILTER="delpaths($paths)
    | .hooks |= with_entries(.value |= map(select(((.hooks // []) | length) > 0)))
    | .hooks |= with_entries(select((.value | length) > 0))"
  jq "$FILTER" "$SETTINGS" > "$WORK/proposed.json" 2>/dev/null

  printf '\n  the edit, which is not applied by this script:\n\n'
  if [ -s "$WORK/proposed.json" ]; then
    diff -u "$SETTINGS" "$WORK/proposed.json" | sed 's/^/      /'
  fi
  printf '\n  apply it, after the human has agreed, with:\n\n'
  printf "      jq '%s' \\\\\n" "$(printf '%s' "$FILTER" | tr '\n' ' ' | sed 's/  */ /g')"
  printf '        %s > %s.new && mv %s.new %s\n' "$SETTINGS" "$SETTINGS" "$SETTINGS" "$SETTINGS"
  printf '\n  what is being agreed to: the removed entries stop firing from the\n'
  printf '  settings file. The plugin still declares them, so the commands keep\n'
  printf '  running -- once each instead of twice. Nothing else in the file moves.\n'
fi

# ------------------------------------------------------- 6. the dispatcher ---

step "6. the statusline dispatcher"

WANT_DISPATCH="$WORK/statusline-dispatch.sh"
show claude/statusline-dispatch.sh > "$WANT_DISPATCH" 2>/dev/null || true
HOST_DISPATCH="$CLAUDE_DIR/statusline-dispatch.sh"

marker() { awk '/^# dispatcher-version:/ { print $3; exit }' "$1" 2>/dev/null; }

if [ ! -s "$WANT_DISPATCH" ]; then
  unknown "remote HEAD has no claude/statusline-dispatch.sh"
else
  want=$(marker "$WANT_DISPATCH")
  if [ -z "$want" ]; then
    unknown "the dispatcher at remote HEAD carries no dispatcher-version marker"
  elif [ ! -f "$HOST_DISPATCH" ]; then
    installer "no dispatcher at $HOST_DISPATCH -- the statusline renders nothing"
  else
    have=$(marker "$HOST_DISPATCH"); : "${have:=0}"
    if [ "$have" -gt "$want" ] 2>/dev/null; then
      # The dispatcher is host infrastructure written by whichever installer
      # runs, so a newer copy means another one got there first. Monotone by
      # design: this is not something to repair.
      fact "this host has dispatcher v$have, newer than the v$want this repository intends"
    elif [ "$have" != "$want" ]; then
      installer "dispatcher is v$have, intent is v$want"
    elif cmp -s "$WANT_DISPATCH" "$HOST_DISPATCH"; then
      ok "dispatcher v$have, byte-identical to intent"
    else
      installer "dispatcher is v$have but its bytes differ from intent -- hand-edited"
    fi
  fi
fi

step "7. statusline contributors"

# Intent is the executable bit in the tree, because that is what enrols a
# contributor -- a file present without it is skipped at discovery and appears
# nowhere else.
wanted=$(git -C "$INTENT_DIR" ls-tree "$INTENT" statusline.d/ 2>/dev/null \
         | awk '$1 == "100755" { n = $4; sub(/.*\//, "", n); print n }')
if [ -z "$wanted" ]; then
  fact "this repository ships no statusline contributor at remote HEAD"
else
  for c in $wanted; do
    f="$MKT_DIR/statusline.d/$c"
    if [ ! -f "$f" ]; then
      installer "contributor \`$c\` is not on this host"
    elif [ ! -x "$f" ]; then
      installer "contributor \`$c\` is present but not executable, so it is skipped at discovery"
    else
      ok "contributor \`$c\`"
    fi
  done
fi

if [ -x "$HOST_DISPATCH" ] || [ -f "$HOST_DISPATCH" ]; then
  # Basenames only. The render order is host truth and worth seeing; the
  # directories it came from are not this repository's business to print.
  order=$(CLAUDE_CONFIG_DIR="$CLAUDE_DIR" bash "$HOST_DISPATCH" --list 2>/dev/null | sed 's#.*/##' | tr '\n' ' ')
  [ -n "${order:-}" ] && fact "render order on this host: ${order% }"
fi

# ------------------------------------------------------- 8. the user memory ---

step "8. the user-memory import"

TAIL=$(scalar_value MEMORY_IMPORT_TAIL)
MEMORY="$CLAUDE_DIR/CLAUDE.md"

if [ -z "${TAIL:-}" ]; then
  unknown "could not read MEMORY_IMPORT_TAIL out of install.sh at remote HEAD"
elif [ -L "$MEMORY" ]; then
  installer "$MEMORY is still a symlink into a clone -- memory composes by import now"
elif [ ! -f "$MEMORY" ]; then
  installer "no $MEMORY, so nothing imports this repository's memory block"
else
  found=$(awk -v tail="$TAIL" \
    'index($0, "@") == 1 && index($0, tail) == length($0) - length(tail) + 1 { n++ }
     END { print n+0 }' "$MEMORY")
  case "$found" in
    0) installer "$MEMORY does not import this repository's memory block" ;;
    1) ok "imported exactly once" ;;
    *) installer "$MEMORY imports the memory block $found times" ;;
  esac
  # An @-import whose target is missing is a silent no-op: no error, no warning,
  # zero exit, siblings still load. The line being present proves nothing.
  if [ "$found" -ge 1 ] && [ ! -e "$CLAUDE_DIR$TAIL" ]; then
    installer "the import resolves to nothing -- $CLAUDE_DIR$TAIL does not exist"
  fi
fi

# ------------------------------------------------------- 9. the symlink farm ---

step "9. the linked files"

links=$(array_elems LINKS)
if [ -z "$links" ]; then
  unknown "could not read LINKS out of install.sh at remote HEAD"
else
  for spec in $links; do
    src="${spec%%|*}"; dst="$CLAUDE_DIR/${spec##*|}"
    if [ -L "$dst" ]; then
      if [ -e "$dst" ]; then
        # The link resolves into some clone, which is not required to be at
        # remote HEAD -- a working copy on a branch is the normal case, not a
        # fault. Say so and move on.
        if show "$src" | cmp -s - "$dst" 2>/dev/null; then
          ok "${spec##*|} -> a clone holding remote HEAD's copy"
        else
          fact "${spec##*|} links to a clone whose copy differs from remote HEAD"
        fi
      else
        installer "${spec##*|} is a dangling symlink"
      fi
    elif [ -e "$dst" ]; then
      # The blind spot every symlink farm has: a link replaced by a real file
      # keeps working, so nobody notices the host stopped tracking.
      installer "${spec##*|} is a regular file, not a link into a clone"
    else
      installer "${spec##*|} is not installed"
    fi
  done
fi

# --------------------------------------------------- 10. the shell exports ---

step "10. the shell environment"

vars=$(grep -o '"[A-Z_][A-Z_0-9]*=[^"]*"' "$INSTALLER_SRC" 2>/dev/null \
       | tr -d '"' | grep -E '^(MAX_MCP|CLAUDE_CODE_MCP)')
case "$(basename -- "${SHELL:-/bin/bash}")" in
  zsh)  rc="$HOME/.zshrc" ;;
  bash) rc="$HOME/.bashrc" ;;
  *)    rc="$HOME/.profile" ;;
esac

if [ -z "${vars:-}" ]; then
  unknown "could not read the exported variables out of install.sh at remote HEAD"
else
  for v in $vars; do
    if [ -f "$rc" ] && grep -Fq "export $v" "$rc"; then
      ok "$(basename -- "$rc"): $v"
    else
      installer "$(basename -- "$rc"): $v is not exported"
    fi
  done
fi

# ---------------------------------------------- 11. the remote-head refresh ---

step "11. the cached remote head"

# A statusline contributor renders "this host is behind its remote" out of a
# cached value, and no render touches the network. Nothing else on a host
# refreshes that cache -- so an audit, which has already paid for the fetch,
# is where it gets refreshed. Merged into whatever is there, never replacing
# it: other entries in that file belong to other marketplaces.
HEADS="$PLUGINS/.remote-heads.json"
SHORT=$(printf '%s' "$INTENT" | cut -c1-12)

if [ "$DO_REFRESH" -eq 0 ]; then
  fact "not refreshed (--no-refresh)"
elif ! command -v jq >/dev/null 2>&1; then
  unknown "jq is not on PATH, so the cached remote head cannot be written"
else
  existing='{}'
  if [ -f "$HEADS" ] && jq -e . "$HEADS" >/dev/null 2>&1; then existing=$(cat "$HEADS"); fi
  mkdir -p -- "$PLUGINS"
  if printf '%s' "$existing" \
     | jq --arg m "$MARKETPLACE" --arg h "$SHORT" --arg t "$(date -u '+%Y-%m-%dT%H:%M:%S+00:00')" \
          '.heads[$m] = $h | .fetchedAt = $t' > "$WORK/heads.json" 2>/dev/null \
     && mv -- "$WORK/heads.json" "$HEADS"; then
    ok "cached remote head for \`$MARKETPLACE\` set to $SHORT"
  else
    unknown "could not write $HEADS"
  fi
fi

# ------------------------------------------------------------ blind spots ---

step "blind spots"

fact "this host only -- an audit never enumerates machines"
fact "only what this repository ships; anything installed from another source is invisible here"
fact "intent is remote HEAD, so an unpushed commit reads as drift, correctly"

# ------------------------------------------------------------------ verdict ---

printf '\n'
if [ "$((N_INSTALLER + N_APPROVE + N_UNKNOWN))" -eq 0 ]; then
  printf '%sno drift%s  audited against %s\n' "$GRN" "$RST" "$INTENT"
  exit 0
fi
printf '%sdrift%s  audited against %s\n' "$YLW" "$RST" "$INTENT"
printf '  %d repairable by re-running ./install.sh\n' "$N_INSTALLER"
printf '  %d needing an approved edit -- no amount of re-running fixes these\n' "$N_APPROVE"
printf '  %d check(s) that could not run\n' "$N_UNKNOWN"
exit 1
