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

## Related: which copy a session reads depends on the marketplace source

Installing this repo's plugin creates
`~/.claude/plugins/cache/context-lab/context-lab/<sha>/`. Whether that copy is the
read path depends entirely on how the marketplace is sourced, and the two answers
are opposites:

- **`"source": "directory"`** — `known_marketplaces.json` records `installLocation`
  as the clone itself, and a session's skill base directory is the clone path. The
  cache copy is bookkeeping; reading it will mislead you, and editing it does
  nothing.
- **`"source": "github"`** — the marketplace is fetched into
  `~/.claude/plugins/marketplaces/<name>/` and the cache copy is authoritative.
  Reading the clone will mislead you instead.

`context-lab` moved from the first shape to the second in ADR 0008;
`context-lab-private` was always the second. Check `known_marketplaces.json` before
assuming either. Editing the cache is still pointless under both — the next update
overwrites it, and `git status` never sees it.
