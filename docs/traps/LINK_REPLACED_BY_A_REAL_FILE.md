---
symptom: "a host works fine but edits I make in the clone never reach it any more"
area: user-tier installer
verified: 2026-08-23
---

# A link replaced by a real file keeps working

**This trap is historical, and it hid a larger one.** Nothing is symlinked onto
a host any more —
[ADR 0014](../adr/0014-executables-ship-as-plugin-content.md) removed the last
two links. The page is kept because the filename is quoted elsewhere, because
leftover links are still on hosts that have not been cut over, and because the
general rule at the bottom is the reason the trap is worth remembering at all.

## Symptom

You change a file in the clone, commit, and the host does not change. Nothing
errors. It still renders — it renders the *old* thing. The host has silently
stopped tracking the repo.

## Mechanism

This is the blind spot every symlink farm has. `~/.claude/statusline.sh` was a
symlink into the clone. Something replaced it with a regular file:

- a tool that writes to the path instead of through it (some editors do this on
  save; so does `mv` from a temp file, which is the *correct* way to write a file
  atomically and therefore common),
- a hand-copied file during a manual fix,
- an older installer that copied rather than linked.

The path still exists. Its contents are still valid. Every consumer keeps working.
The only thing that broke is the property nobody checks: that this file is a
*view* of the clone rather than a copy of it.

## The larger trap underneath it

This page asks whether a path is a link or a copy. Both answers can be right
while the host still runs nothing you wrote. Measured across four hosts in
August 2026: the statusline dispatcher was committed, documented and present in
**none** of them, every host's `statusLine` still named the shim, and three of
the four had marketplace clones too old to contain a `statusline.d/` directory
at all. Every link was intact. Every check that looked at links passed.

The question that would have caught it is not "is this a link" but "does what
this host executes match what the remote publishes". That is a different
question, it needs the remote to answer, and it is what the audit skill asks.

## Why it stopped being a trap

The link was standing in for "what runs is what the repo published", and it was a
poor proxy: it resolved to whatever commit a working checkout happened to sit on,
which on most hosts was not the published one. Executables now reach a host as
plugin content addressed by `${CLAUDE_PLUGIN_ROOT}`, which resolves to a cache
directory keyed by the published commit. There is no path to replace and no link
to break.

## Fix, on a host not yet cut over

`install.sh` no longer creates, checks or repairs these links, so it will not
report them. Delete them by hand and re-install:

```sh
rm -f ~/.claude/statusline.sh ~/.claude/hooks/token-tracker.sh
rmdir ~/.claude/hooks 2>/dev/null   # only if rtk left nothing else there
```

The audit skill names any that remain; that is where this check lives now.

## How to verify nothing is left

```sh
for f in statusline.sh hooks/token-tracker.sh; do
  printf '%-26s %s\n' "$f" "$([ -e ~/.claude/"$f" ] && echo 'STILL PRESENT' || echo 'clean')"
done
```

`CLAUDE.md` is deliberately absent from that list: it is a real host-local file
composed by `@`-import, and it is *supposed* to exist (ADR 0011).

## The general rule

**Test for the mechanism, not the outcome.** "The file is there and the content is
right" is true in both the working and the broken state. `[ -L ]` was the
assertion that distinguished them, and any check that omitted it was measuring
the wrong thing. The same rule is what caught the successor problem: a plugin
hook and a settings hook with the same command both run, and "the tracker fires"
is true in both the working and the double-counting state.
