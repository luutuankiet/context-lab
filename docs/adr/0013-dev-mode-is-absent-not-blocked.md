# Dev mode is absent from the architecture, not blocked in it

Supersedes the second accepted cost in
[ADR 0003](0003-distribute-by-symlink-and-git-pull.md), and names the thing
[ADR 0008](0008-the-marketplace-source-is-the-github-repo.md),
[ADR 0011](0011-user-memory-composes-by-import-not-symlink.md) and
[ADR 0012](0012-the-statusline-is-composed-not-owned.md) each gave up a piece of
without ever calling it by name.

**Decision: there is no supported way to install a host against a working
checkout.** This repo does not offer one, does not detect one, and does not
refuse one. Development against a checkout happens by hand, outside anything
described here.

Absent is stronger than blocked and weaker than forbidden, and the distinction is
the whole record. A blocked mode is one the architecture knows about; the reader
learns it exists, the check has to keep proving it is still blocked, and the
first person with a good reason turns the block off. An absent mode has no
surface to turn off.

## This is a decision because the platform offers the feature

The platform supports dev installs. A marketplace entry may declare a `command`
source with `mode: "link"`, which resolves a plugin to a path on disk instead of
a fetched copy — a working checkout, live, with no publish step. Nothing stops
this repo adopting it. It declines.

## What is being reversed

ADR 0003 chose symlinks for drift visibility and stated the cost plainly:
"because work on this repo happens *in* the clone that hosts are linked to,
checking out a branch repoints the live user tier for as long as it stays out."

That sentence is dev mode, recorded as a side effect of a mechanism chosen for a
different reason. Nobody asked for it, and it is the direct cause of the
split-source failure that opened this thread: three of four hosts ran their
statusline and their token-tracker hook out of a working checkout while their
user memory resolved to the marketplace clone. Two copies of this repo on one
machine, at different commits, with nothing anywhere saying so — because there
was no name for the mode that produced it and therefore nothing to check.

ADR 0006 then made the same property the default for skills, by choosing the
clone as the marketplace source: an uncommitted edit was live in the next
session, verified and celebrated. Three later records took it back one surface at
a time — 0008 for skills, 0011 for user memory, 0012 for the statusline, each
weighing the trade on its own merits and each landing the same way. Three
independent decisions agreeing is the signal that they were one decision. This
record is that one, stated once, so the fourth surface does not have to relitigate
it.

## Considered options

- **Support it explicitly**, with a `mode: "link"` marketplace entry behind a
  flag. Rejected: it reintroduces two sources for one repository on one host,
  which is the failure being closed, and it has to work on every host in case
  anyone uses it on one.
- **Block it** — have `--check` detect a checkout-shaped install and fail.
  Rejected twice over. Code that defends against a mode nobody offers has to stay
  correct forever against a threat that does not exist, and the check itself
  documents the mode into existence for the next reader.
- **Absent.** Chosen. Nothing to configure, nothing to assert, nothing to explain.

## Consequences

**The two remaining symlinks are the last of it.** `claude/statusline.sh` and
`claude/hooks/token-tracker.sh` still resolve into the clone, so a host with a
clone still runs two files out of a working checkout today. Both go in the same
cut: the tracker moves into the plugin's own `hooks/hooks.json`, and the
statusline settings key repoints at the host-written dispatcher, which takes the
second link with it. This record does not perform that cut — it records why the
cut is allowed to leave nothing behind in place of the links, rather than leaving
a supported link mode where they were.

**Working on this repo costs a publish loop, deliberately.** An edit to a skill
is live after commit, push and `claude plugin update`; an edit to the payload is
live after `git pull && ./install.sh`. Anyone who wants a faster loop wires it up
by hand, on their own machine, and this repo neither helps nor objects.

**A search for "dev mode" in this repository returns nothing, and that is the
result, not a gap.** The only place the words appear is in this record, saying
why.
