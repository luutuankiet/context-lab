---
symptom: "install.sh --check reports everything healthy but the host is not running what main says it should"
area: user-tier installer
verified: 2026-08-17
---

# `--check` proves the links, not the commit

## Symptom

`./install.sh --check` exits 0. Every link resolves, every owned key matches, every
unset key is absent. The host is nonetheless running config that does not match
`main` — an old installer, a stale statusline, or none of the skills that were
supposed to have landed.

## Mechanism

`--check` compares the *host* against the *working tree*. It has no opinion about
which commit the working tree is on.

```
~/.claude/CLAUDE.md  ->  <clone>/claude/CLAUDE.md
```

That link is correct whether the clone is on `main`, five commits behind `main`, or
on somebody's feature branch. The check answers "is this host still tracking the
clone", which is the question it was written for. It does not answer "is this clone
still tracking the remote", and the two questions look identical from the outside.

Two ways to land here, both observed:

- **A branch checkout.** Work on the repo happens *in* the clone that the host is
  linked to, so checking out a branch to make a change silently repoints the live
  user tier at that branch for as long as it stays out.
- **A clone that was never pulled.** Merged pull requests do not reach a host by
  themselves. Measured on 2026-08-17: a clone sat five commits behind
  `origin/main` — missing the entire skills collection and an installer fix — while
  `--check` reported the host healthy, because the payload files those commits
  touched happened to be unchanged.

The second case is the nastier one. `git status` alone says nothing: it prints
`## main...origin/main [behind 5]` only after a fetch.

## Fix

Fetch before you trust the check, and read the branch line:

```sh
git -C <clone> fetch -q && git -C <clone> status --porcelain=v1 -b | head -1
```

Expect exactly `## main...origin/main`. Anything else — `[behind N]`, `[ahead N]`,
or a branch that is not `main` — means the host is running something other than
what the remote says, no matter what `--check` reported.

## How to verify

```sh
git -C <clone> rev-parse HEAD origin/main    # the two must be equal
readlink -f ~/.claude/CLAUDE.md              # must resolve into that clone
```

## The general rule

**A symlink farm proves the link, never the contents behind it.** Any check built
on "does this point where I expect" needs a second, separate check on "is what it
points at current" — and the second one requires network, which is exactly why it
tends to get left out.
