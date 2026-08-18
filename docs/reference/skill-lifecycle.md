---
title: The life of a skill
summary: the three buckets and which one is served, where drafting happens, and what changes for a consumer when a skill is promoted out to the tool's own repo
verified: 2026-08-18
---

# The life of a skill

A skill in this repo moves along two independent routes, and confusing them is the
usual mistake.

- The **maturity** route runs inside this repo: `in-progress/` → `stable/` →
  `deprecated/`. It is a `git mv` and nothing else.
- The **provenance** route leaves this repo entirely: a skill that turns out to be
  some tool's manual is deleted from here and re-published from that tool's own
  repo, which this repo's marketplace then points at.

They do not compose into a single ladder. A skill can walk one, both, or neither.

## Only one bucket is served

`.claude-plugin/plugin.json` declares `"skills": ["./skills/stable"]`, and that one
line is the entire bucket mechanism. Everything follows from it:

| bucket | served to sessions | what it is for |
|---|---|---|
| `skills/stable/` | **yes** | the published catalogue |
| `skills/in-progress/` | no | a parking lot for drafts between editing sessions |
| `skills/deprecated/` | no | the off-switch, retained for its history |

**`in-progress/` and `deprecated/` are storage, not loading paths.** Neither is
reachable from any session on any host, including the authoring one, and that is
deliberate rather than an oversight — a skill sitting in either bucket is inert by
design. Moving a directory between buckets is therefore a behaviour change, not
filing.

## Where drafting actually happens

Because `in-progress/` is unreachable, **the inner loop does not run in this repo
at all.** A skill being drafted is hand-copied into the user-scope skills
directory, `~/.claude/skills/<name>/`, where it is live-editable — edit the file,
the next session has it, with no commit, no push and no reinstall. That directory
is owned by the operator; nothing this repo installs writes to it, and on a fresh
host it does not exist until it is created by hand.

The repo ships **nothing** to support this. There is no second marketplace, no
second plugin entry, no allowlist change, no gate script and no symlink. The loop
needed somewhere to happen, not a mechanism to be built.

Three mechanisms that would have worked were rejected, all for the same reason —
each couples the loop back to the repo as persistent host state that can drift
while nobody is watching:

- `--plugin-dir <path>`, a repeatable launch flag that loads a plugin from a
  directory for one session and registers nothing.
- A plugin folder placed under the user-scope skills directory, which auto-loads as
  `<name>@skills-dir` — a different namespace from the one the skill will ship
  under.
- A second marketplace on a local filesystem path, which restores the live-edit
  behaviour that a directory source used to give the whole collection.

**The known cost is a missed copy-back.** Two copies exist while drafting — the
live one under the user-scope directory and the tracked one in `in-progress/` — and
they are kept in step by hand. Forgetting to copy back before promoting ships the
version from before the last edit, with no error and a clean `git status`. This was
weighed against a symlink, which would have removed the second copy entirely, and
accepted: the drafting copy is short-lived, single-owner, and never a distribution
source.

## Promotion inside the repo

`git mv skills/in-progress/<name> skills/stable/`, commit, push. The skill is now
in the served bucket and reaches consumers on their next plugin update. Nothing
else changes — same repo, same plugin, same invocation name — so this move cannot
break a caller.

Deprecation is the same move in the other direction, into `skills/deprecated/`.
The skill stops being served with no manifest edit.

## Promotion out of the repo

A skill that **documents a tool** belongs in that tool's repo, because it changes
when the tool changes. A skill about how this operator works stays here. The test
is authorship of the subject, not who wrote the words.

When a skill fails that test it is deleted from `skills/stable/` and the tool's
repo grows a `.claude-plugin/plugin.json` of its own; this repo's
`.claude-plugin/marketplace.json` gains an entry naming that repo as a source. No
bytes are copied — the consumer's machine clones the named repo at
`claude plugin install` time.

The allowlist lives in the tool's repo rather than here for one reason: it names
directories, so it has to sit where a rename can land in the same commit.

### The invocation name changes, and this is the part that bites

A plugin skill is invoked as `<plugin>:<skill>`. Promotion out moves the skill into
a **different plugin**, so its prefix changes — `context-lab:write-pr` became
`write-pr:write-pr`. Anything that referenced the old name is now wrong: other
skills, this repo's own prose, and any habit the operator has.

> Promotion out is **not** transparent to a consumer. Promotion between buckets is.

### Coming back

Reversal is mechanically easy — drop the pointer entry, re-add the directory — but
it is not a normal move. The rule above decides where a skill lives, so a skill
only returns if its subject stops being an external tool. Treat the pointer as
one-way in practice.

## Reading the current state

The buckets and the pointers are both readable in one place each, and neither is
generated from the other:

```sh
ls skills/stable skills/in-progress skills/deprecated   # the maturity route
```

Pointer entries are the objects in the `plugins` array of
`.claude-plugin/marketplace.json` whose `source` is a `github` object rather than
`"./"`. The `"./"` entry is this repo's own plugin, carrying the stable bucket.
