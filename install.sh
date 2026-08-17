#!/usr/bin/env bash
# Context Lab installer — links the user tier into ~/.claude/ on this host.
#
# NOT YET IMPLEMENTED. Phase 1 created this file so the tree is complete;
# the body is built by "Build the settings manifest and install.sh".
#
# When implemented it does six things, in order:
#   1. prereq check        (rtk, jq, awk, rg, gh, node, git)
#   2. rtk install + `rtk init -g --auto-patch`
#   3. marketplace plugin  (mattpocock-skills@claude-plugins-official)
#   4. symlink farm        per FILE into ~/.claude/ — never a directory symlink
#   5. settings merge      key-level jq merge of claude/settings.owned.json
#   6. shell exports       MAX_MCP_OUTPUT_TOKENS, CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS
#
# `install.sh --check` verifies prereqs, that every link still resolves into
# this clone, and that every owned key still matches the manifest.

set -euo pipefail
echo "install.sh is a Phase 1 stub and does nothing yet." >&2
echo "Implement it before running it on any host." >&2
exit 1
