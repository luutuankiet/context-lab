# Executables ship as plugin content, not as symlinks into a clone

Supersedes [ADR 0003](0003-distribute-by-symlink-and-git-pull.md) outright, and
retires the "config stays linked" half of
[ADR 0006](0006-skills-ship-as-a-plugin-config-stays-linked.md). It completes a
direction the four records before it each took one step along:
[ADR 0008](0008-the-marketplace-source-is-the-github-repo.md) moved skills off
the clone, [ADR 0011](0011-user-memory-composes-by-import-not-symlink.md) moved
memory off it, [ADR 0012](0012-the-statusline-is-composed-not-owned.md) moved
rendering off it, and [ADR 0013](0013-dev-mode-is-absent-not-blocked.md) named
what was left. What was left is two symlinks, and this record removes them.

**Decision: nothing in this repo is symlinked onto a host.** The hook that was
linked as `~/.claude/hooks/token-tracker.sh` now ships in the plugin's own
`hooks/hooks.json`, addressed as
`${CLAUDE_PLUGIN_ROOT}/claude/hooks/token-tracker.sh`. The statusline reaches a
host the same way, through the dispatcher. `install.sh` registers things and
places nothing: no `LINKS` array, no `link_files()`, no `backups/` directory.

## Why the original reason stopped holding

ADR 0003 chose links for **drift visibility**: an edit on a host wrote through
the link into the tracked file, so `git status` in the clone reported it. That
argument assumed the clone was the thing a host executes. It has not been for
some time, and the assumption failed in both directions at once:

- Three of four hosts had links resolving into a personal working checkout,
  running whatever commit that checkout happened to sit on — in one case a
  commit two behind the marketplace, in another an uncommitted edit that had
  never taken effect because the memory import resolved elsewhere.
- Drift visibility only works if somebody looks. Nobody runs `git status` in
  four clones. The audit skill does the looking now, and it reads the published
  remote as intent rather than a local checkout.

`${CLAUDE_PLUGIN_ROOT}` gives the property the link was standing in for, and
gives it stronger: the path resolves to a cache directory keyed by the commit
the marketplace published. What runs is a version, not a working copy.

## Plugin hooks merge; they do not override

The load-bearing detail, and the one that makes this a single atomic change
rather than two independent ones. A plugin's hooks are **added to** whatever
`settings.json` declares — they do not replace it. A host that gains the plugin
hook while keeping its settings entry fires the tracker **twice per event**, and
nothing reports an error.

So `install.sh` must delete the settings entries in the same install that
delivers the plugin hook. That is why `SETTINGS_UNSET` now accepts a dotted
path: `delpaths` was building one-element paths and could only ever reach
top-level keys. The entries are named individually — `hooks.UserPromptSubmit`
and `hooks.PostToolUse` — and never as a bare `hooks`, because the `PreToolUse`
entry beside them belongs to another tool and must survive. A test seeds the
legacy binding and asserts exactly that.

## Considered options

- **Keep the links, add the hooks manifest.** Rejected: this is the
  double-fire, and it is silent.
- **Move the hook but keep the statusline symlink.** Rejected as a half-cut.
  One remaining link is enough to keep every host's `~/.claude` pointing into a
  checkout, which is the state this record exists to end.
- **Have `install.sh` copy the executables instead of linking them.** Rejected:
  a copy has a version nobody can name. The plugin cache already solves this,
  and solving it twice is how the two mechanisms drift apart.

## Accepted costs

- **A host's hook is now only as fresh as its plugin.** `claude plugin update`
  is the update verb; a `git pull` in a clone changes nothing. This is the
  intended trade — freshness becomes an explicit act with a version attached.
- **The legacy `~/.claude/hooks/` directory and the two links are not removed
  by the installer.** Deleting files this repo no longer claims to own is an
  audit's job, not an install's; the audit skill names them and proposes the
  removal.
- **`claude/statusline.sh` is gone**, and with it the compatibility path for a
  host that has not yet been repointed at the dispatcher. Every host has been.
