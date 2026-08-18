---
symptom: "a path built from $CLAUDE_PLUGIN_ROOT inside a skill resolves to /skills/... and the command fails as if the file were missing"
area: skills collection
verified: 2026-08-18
---

# `$CLAUDE_PLUGIN_ROOT` is empty in a Bash call

A skill that ships a script is tempting to write as:

```bash
"$CLAUDE_PLUGIN_ROOT"/skills/stable/<skill>/scripts/thing.sh    # WRONG
```

Verified by running it: the variable is **not expanded when the skill text is
injected**, and it is **not set in the environment of a Bash tool call**. The
command therefore runs against `/skills/stable/...` — an absolute path at the
filesystem root — and fails as "no such file", pointing at a file that plainly
exists.

## Use the skill's base directory instead

The harness states the skill's base directory when it injects the skill
("Base directory for this skill: …"). That is the anchor to use, and it is
correct under every install shape — plugin, project skill, or personal skill:

```bash
<this skill's base directory>/scripts/thing.sh
```

Never a path relative to the *repo* root either (`skills/stable/<skill>/…`). That
only resolves when the working directory happens to be a clone of this repo,
which is never true on a consumer's machine.

## Related: the cache copy is not what a session reads

Installing this repo's plugin creates
`~/.claude/plugins/cache/context-lab/context-lab/<sha>/` — a full copy of the
clone. For a **filesystem-source** marketplace, that copy is *not* where skills
are loaded from: `known_marketplaces.json` records `installLocation` as the clone
itself, and a session's skill base directory is the clone path.

Two consequences:

- **Reading the cache to find out what a host is running will mislead you.** Read
  the clone.
- **Editing the cache changes nothing** and is invisible to `git status`.
