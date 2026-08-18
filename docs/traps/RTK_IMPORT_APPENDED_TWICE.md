---
symptom: "git status in the context-lab clone shows claude/CLAUDE.md modified on a host I only just installed, and I did not edit it"
area: user-tier installer
verified: 2026-08-18
---

# `claude/CLAUDE.md` gains a second import on every fresh host

> **Retired by construction — this can no longer happen.** `~/.claude/CLAUDE.md`
> stopped being a symlink into the clone
> ([ADR 0009](../adr/0009-user-memory-composes-by-import-not-symlink.md)), so rtk
> writes to a host-local file that no repository tracks. The mechanism below is
> kept because the *shape* of the failure recurs: a tool that detects its own
> reference by literal string, writing into a file something else also owns.



## Symptom

You run `./install.sh` on a machine, it reports success, and `git status` in the
clone shows `claude/CLAUDE.md` as modified. You did not touch it. The extra line is
a duplicate rtk import.

It happens once per host and then stops, which is what makes it hard to catch: on
any single machine it looks like a one-off, and across a fleet it looks like
unexplained drift on every host at once.

## Mechanism

`~/.claude/CLAUDE.md` is a **symlink into the clone**. `rtk init -g --auto-patch`
writes to `~/.claude/CLAUDE.md`, so it writes *through* the link into the tracked
file.

rtk detects its own reference by the **literal string** `@RTK.md`. If the file
contains the absolute form instead:

```
@~/.claude/RTK.md
```

…then rtk's literal search does not match, rtk concludes its import is missing, and
it appends a second one. The result self-converges after one write — which is worse
than failing, because a loud failure gets fixed and quiet drift on five hosts does
not.

The absolute form looks safer, and the ambiguity it was meant to resolve **does not
exist**. Measured rather than inferred: with `~/.claude/CLAUDE.md` symlinked into
the clone, a probe file placed only in `~/.claude/` — and deliberately absent from
the link target's directory — resolved. A relative `@import` in a symlinked file
resolves against **the link's directory**, not the link target's.

## Fix

Historically: keep the first line of `claude/CLAUDE.md` exactly `@RTK.md`, bare and
relative, as `rtk init -g` writes it.

**That fix is now obsolete and the assertion is inverted.** `claude/CLAUDE.md` is
imported rather than linked, so a relative `@RTK.md` inside it would resolve
against the marketplace clone and find nothing. The payload therefore carries no
import of its own, and rtk's line lives in the host-local `~/.claude/CLAUDE.md`
where rtk writes it.

## How to verify

```sh
awk '/^@RTK\.md$/ { n++ } END { print n+0 }' claude/CLAUDE.md   # must now be 0
```

`test-install.sh` asserts that absence, so the old shape cannot come back.

## The general rule

**Where a tool owns a file this repo also tracks, either match the tool's literal
expectations byte-for-byte, or stop sharing the file.** This repo tried the first
for a year and then chose the second: a file with more than one writer is a
standing bug, and the durable fix was to give each writer its own line rather than
to out-guess a literal string match.
