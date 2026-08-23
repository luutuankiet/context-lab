#!/usr/bin/env bash
#
# The legacy statusline entry point. A shim, and nothing else.
#
# Every host's settings.json still names `~/.claude/statusline.sh`, which is a
# symlink into this clone. The rendering it used to hold now lives in
# `statusline.d/10-context`, where the dispatcher can discover it alongside
# contributors from anywhere else -- so this file exists only so that a host
# which has not yet been repointed at the dispatcher keeps rendering exactly
# what it rendered before.
#
# It composes nothing. A host reaching the statusline through here sees this
# repo's segment and no other; being repointed at the dispatcher is what buys
# composition. Retiring this file, its symlink and the settings entries that
# name it is tracked separately.
#
# Written for bash 3.2, the oldest interpreter in the fleet.

set -u

# Resolve through the symlink by hand. `readlink -f` is GNU and was absent from
# macOS for years; plain `readlink` is one level and portable, which is all a
# link straight into a clone needs.
self="${BASH_SOURCE[0]}"
while [ -L "$self" ]; do
  link=$(readlink "$self")
  case "$link" in
    /*) self="$link" ;;
    *)  self="$(dirname -- "$self")/$link" ;;
  esac
done
here=$(cd -- "$(dirname -- "$self")" && pwd -P)

exec "$here/../statusline.d/10-context"
