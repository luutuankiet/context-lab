#!/usr/bin/env bash
#
# Generate docs/README.md, and the two emitted skill bodies once they exist.
#
#   scripts/gen-docs-index.sh            write every index
#   scripts/gen-docs-index.sh --check    exit 1 if any index is stale
#
# The generator itself is the one shipped by the repo-context-audit skill, and
# this file is deliberately three lines of wrapper rather than a second copy. A
# generator holds a schema -- the marker string, the frontmatter keys, the
# collections -- and this repo's whole premise is that a schema has one home.
# When the skill's copy changes, this repo changes with it, which is the point:
# the lab is the first thing the payload is tested on.

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$REPO/skills/stable/repo-context-audit/scripts/gen-docs-index.sh" --repo "$REPO" "$@"
