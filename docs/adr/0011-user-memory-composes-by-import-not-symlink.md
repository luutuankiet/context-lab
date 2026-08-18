# User memory composes by `@`-import, never by symlink

Supersedes the `claude/CLAUDE.md` row of
[ADR 0003](0003-distribute-by-symlink-and-git-pull.md). The other two files in
`claude/` are still symlinked exactly as 0003 decided; only user memory leaves the
farm.

`~/.claude/CLAUDE.md` is now a **real, host-local file that no repository owns**.
Each tier owns one `@`-import line inside it and nothing else:

```
@~/.claude/plugins/marketplaces/context-lab/claude/CLAUDE.md
@~/.claude/plugins/marketplaces/context-lab-private/claude/CLAUDE.md
@RTK.md
<free region — the operator's, overriding the blocks above>
```

## Why a symlink could not survive a second tier

One file cannot be symlinked into two repositories. As long as `~/.claude/CLAUDE.md`
was a link into the public clone, the private overlay had no way to contribute a
line to user memory without taking the file away from the public installer
entirely. That is not a bug to fix but a **structural conflict of ownership**: two
installers competing for one inode, where the winner is whichever ran last.

Imports dissolve the conflict rather than arbitrating it. Each installer greps for
a literal it owns and adds it if absent, so both may run in any order, any number
of times, and neither can observe the other.

## The link's own virtue turned out to be a liability

0003 chose symlinks for **drift visibility**: an edit writes through into the
tracked file and shows up in `git status`. Measured against the memory file
specifically, that property never once paid:

- Every commit `claude/CLAUDE.md` has ever received was deliberate authoring. It
  has never caught unintended drift.
- The incident that justified 0003 was a **statusline** fix lost across hosts —
  an executable config file, not memory prose. That file has had no drift since.
- Memory is the only linked file with a **foreign writer**. `rtk init -g
  --auto-patch` writes to `~/.claude/CLAUDE.md`, so it wrote *through the link into
  a public git repository* on every fresh host — the whole content of
  `docs/traps/RTK_IMPORT_APPENDED_TWICE.md`. Read as visibility that is a feature;
  read as a third-party tool committing to your repo it is not.

Breaking the link retires that trap by construction. rtk now writes to a file that
is tracked nowhere, which is where a tool's own generated reference belongs.

## Why the marketplace clone, and not the plugin cache

`claude plugin marketplace add` fetches the **entire repository**, not just a
manifest, to `~/.claude/plugins/marketplaces/<name>/`. That path is keyed by
marketplace name, so it never moves.

The plugin *cache* is the opposite and must not be imported: it is keyed by source
commit sha, so every push creates a new directory and an import into it would break
on the next update. Five such directories were live on the authoring host when this
was measured, with no stable alias among them.

`claude plugin marketplace update` does **not** pull. It reports `Found stale
directory, cleaning up and re-cloning` and replaces the directory wholesale — the
inode changes, the path does not. An `@`-import resolves by path and therefore
survives; this was measured across a real update, inode `22721092` before and
`22887499` after, with memory still loading in a fresh session. Anything that
resolves by inode rather than path would not survive, which is a second reason not
to point a link at this directory.

## Consequences

- **A host needs no clone to receive memory.** `marketplace add` performs the
  clone; the import points into it. This is what makes the public tier genuinely
  hand-to-a-colleague.
- **The entry point is three commands, and the third is not discoverable.**
  `marketplace add`, `plugin install`, then the installer out of the fetched
  clone. Nothing in the plugin model can run that third step: across all 286
  entries in the official marketplace, no manifest declares any `postinstall`,
  `preinstall`, `scripts`, or lifecycle key. It therefore belongs on the README's
  first screen, not in a footnote.
- **A tier that is not installed is a silent no-op.** An `@`-import whose target is
  missing produces no error, no warning, and a zero exit; siblings still load. A
  public-only host is a supported configuration with one unresolved line, which is
  exactly the clean degradation this required.
- **That same silence is the one real failure mode, so it is checked explicitly.**
  A `marketplace update` that fails partway leaves the line pointing at a directory
  that no longer exists, and nothing anywhere reports it — the host simply runs
  without memory. The import line being present proves nothing on its own, so step
  4b also warns when the target does not exist. It warns rather than fails: a
  dev-clone install and a sandboxed test both legitimately lack the directory.
- **The authoring host has no special case.** The import targets the marketplace
  clone everywhere, so a memory edit goes live after commit, push and
  `marketplace update` — the same loop ADR 0008 already imposed on skills. One
  rule, not two.
- **The free region is deliberately untracked, and drift there is accepted.**
  Nothing reports that one host's free region has diverged from another's, and
  nothing should: the region exists to hold what must *not* be fleet-wide. An
  operator wanting a change everywhere puts it in a tier, not in the free region.
- **The payload carries no import of its own.** A relative `@import` inside
  `claude/CLAUDE.md` would resolve against the marketplace clone rather than
  `~/.claude/`, and find nothing. `test-install.sh` asserts its absence.
- **Idempotence is enforced on the literal, not on the spelling.** Any `@` line
  ending in the owned path tail collapses to one canonical line, so the near-miss
  that produced a duplicate rtk import cannot produce a duplicate here. Asserted
  by `test-install.sh` in both directions.
