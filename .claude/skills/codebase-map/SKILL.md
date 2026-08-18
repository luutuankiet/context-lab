---
name: codebase-map
description: Where behaviour lives in this repo — a per-area map of which files and line ranges own what, so you can open the right file instead of searching for it. Use before hunting for where something is implemented, before adding a feature that touches existing behaviour, and when a change seems to need edits in more places than expected.
---

# Where things live

Three areas, and almost all of the behaviour is in one file. The pages below are
maps: for each area, which files own it and roughly where in them.

**Pick the area, open that one page, then go straight to the file.** Do not read
every page — that defeats the point.

<!-- BEGIN GENERATED INDEX -- edit the pages, not this block -->

## Where things live

One page per area of the system. Read before going looking for where
something is implemented.

| page | covers | verified |
|---|---|---|
| [How this repo holds its own context](../../../docs/architecture/repo-context-layout.md) | where agent-facing context lives in this repo, what is always loaded, and how the generated index stays honest | 2026-08-18 |
| [The skills collection](../../../docs/architecture/skills-collection.md) | where the distributed skills live, how the stable bucket ships as a plugin, and why no third-party skill is vendored here | 2026-08-18 |
| [The user-tier installer](../../../docs/architecture/user-tier-installer.md) | how a host gets its Claude Code config, what install.sh actually writes, and what --check can and cannot prove | 2026-08-17 |

## Guides

Long-form pages that belong to no single area.

| page | summary | verified |
|---|---|---|
| [Third-party skills](../../../docs/third-party-skills.md) | why no skill written by someone else is vendored here, which upstream collections are pointed at, and how to hydrate them on a host | 2026-08-18 |

<!-- END GENERATED INDEX -->

The same table, browsable, is [docs/README.md](../../../docs/README.md).

## How to read a line range

Every entry is `file — lines — what lives there`. **The line numbers are a
starting point, not an address.** They drift with every commit that touches the
file above them, and nothing regenerates them.

So: jump to roughly that line, then confirm you are in the right place by what the
code says, not by the number. If a range is off by more than a screen or two, fix
it in the page and re-date it — that is a one-line edit and it is how the map
stays worth having.

Line ranges are given at all because this repo is one big file and a handful of
small ones. `install.sh` is 452 lines and carries six numbered phases in banner
comments — prereqs, the RTK import, the plugin, the symlink farm, the settings
merge, shell exports. "It's in `install.sh`" is not an answer; "phase 5, the
settings merge, around line 302" is.

The rest, for scale: `scripts/third-party-gate.sh` 159, `test-install.sh` 126,
`scripts/skills-publish-gate.sh` 71. Everything else is markdown.

## What this map does not tell you

It tells you **where**, not **why it is dangerous**. The whole fragile path in
this repo is one thing: **`install.sh` writing into `~/.claude/`.** That
directory is not ours — Claude Code owns twenty-odd runtime entries in it,
including `.credentials.json` — so every write there is a merge into somebody
else's live state, and four of the six traps in this repo were produced by it.

Those are catalogued by symptom in the `repo-maintenance` skill and in
[docs/README.md](../../../docs/README.md). If you are about to touch the symlink
farm, the settings merge, or the RTK import, read them first.

## Keeping it accurate

A map that lies is worse than none, because it sends people confidently to the
wrong file. Two habits keep it honest:

- **Re-date what you touch.** If you worked in an area and the page was right,
  bump `verified:`. If it was wrong, fix it and bump.
- **Add an area when you create one, not later.** A new subsystem with no page is
  invisible; the next person re-derives its shape from scratch.

To add a page, follow the same rules as any other doc — see the `repo-maintenance`
skill. Frontmatter for an area page is `title`, `covers` (what someone would be
looking for, phrased as they would phrase it), and `verified`. Then run
`scripts/gen-docs-index.sh`; the block above is generated and hand edits to it are
overwritten.
