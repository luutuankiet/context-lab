# Skills ship as a plugin; config stays linked

Supersedes the skills half of
[ADR 0003](0003-distribute-by-symlink-and-git-pull.md). The three config files in
`claude/` are still symlinked out of the clone, exactly as 0003 decided. Skills
are not: `skills/stable/` ships as the `context-lab` plugin, from a marketplace
declared in `.claude-plugin/marketplace.json` whose source is the host's own
clone.

ADR 0003 rejected "a published package" on the grounds that it versions the
collection and buys nothing for a single operator while adding a release step
between writing a skill and using it. That reasoning was sound against the thing
it was aimed at — an npm-style package. It does not survive contact with a
marketplace, which was measured rather than read about:

- **Publishing is two manifests, 8 and 12 lines.** There is no build, no
  registry, no account, and no release step.
- **A filesystem path is a first-class marketplace source**, so the clone every
  host already has *is* the distribution channel. Nothing new is fetched.
- **`"skills": ["./skills/stable"]` is the entire bucket mechanism.** A listed
  path is a skill directory if it holds `SKILL.md`, otherwise its immediate
  children are scanned — one level, never recursive. Adding a directory publishes
  it; `mv`-ing it to `deprecated/` unpublishes it. Neither edits a manifest.
- **No linker was needed at all.** The `link-skills.sh` this repo had been
  planning to write is deleted from the plan rather than deferred, and the dead
  `if [ -x "$REPO/link-skills.sh" ]` guard in step 4 is gone with it.

## The source is the clone, so 0003's decisive property survives

0003 chose symlinks for **drift visibility**: an edit writes into the tracked file
and shows up in `git status`, where an edit to a copy shows up as nothing at all.
That property is preserved here, and the reason is worth stating precisely because
the opposite was assumed for most of a session before it was measured.

A marketplace whose source is a **directory** is not copied.
`known_marketplaces.json` records its `installLocation` as the clone path itself,
and a plugin declared `"source": "./"` inside it resolves to that same clone. A
session's skill base directory is therefore
`~/dev/context-lab/skills/stable/<skill>` — the tracked file. Verified three ways
on thinkpad:

| test | result |
|---|---|
| invoke a skill after an **uncommitted** edit | the edit is there |
| add a **new** directory to `skills/stable/`, install nothing | invocable as `context-lab:<name>` immediately |
| ask a session for the skill's base directory | the clone, not the cache |

So there is no authoring-host special case, no symlink escape hatch, and no
commit-then-install loop. Editing a skill in the clone changes what the next
session runs — the same loop that existed before plugins, with namespacing and the
bucket allowlist added.

`claude plugin install` *does* also write a full copy to
`~/.claude/plugins/cache/<marketplace>/<plugin>/<sha>/`. For this configuration
that copy is a bookkeeping artifact, not the read path. Reading it to find out
what a host is running will mislead you; see
`docs/traps/CLAUDE_PLUGIN_ROOT_IS_EMPTY_IN_BASH.md`.

## Why no `version` key

`plugin.json` declares no `version`, and that is deliberate. With one, `claude
plugin update` compares the declared version and does **nothing** when it has not
moved — so a forgotten bump leaves every host's recorded state frozen while every
command reports success. With no version key the plugin's version *is the source
commit sha*, so the recorded state tracks the clone by construction. Verified both
ways on thinkpad: an edit under a static `0.1.0` did not register, and the same
edit versionless installed as `ea8bf49fd432`.

## What this costs, honestly

- **A remote-source install would behave differently.** Point the marketplace at
  the GitHub repo instead of the clone and skills *are* served from the cache
  copy, which reintroduces exactly the copy-drift 0003 refused. The filesystem
  source is not a convenience here; it is the decision.
- **`~/.claude/plugins/cache/` grows.** Each install/update leaves a ~900 KB copy
  of the whole repo, old versions marked `.orphaned_at` and swept after about two
  weeks.
- **`claude plugin update <name>` fails with "Plugin not found"** unless it is
  given the full `<plugin>@<marketplace>` id. `install.sh` always passes the id.

## Consequences

- The fleet update verb is `git pull && ./install.sh`, unchanged in shape from
  0003 and now covering skills too.
- `~/.claude/skills/` is unused by this repo and need not exist on any host.
  Foreign skills already sitting there are untouched — plugins do not read it.
- Skills are invoked **namespaced**: `context-lab:<name>`. Prose inside a skill
  that pointed at an unpublished sibling by bare name was rewritten to say so.
- Scripts inside a skill are addressed **relative to the skill's own base
  directory**, which the harness states on injection — not by a path relative to a
  repo the consumer does not have, and not via `$CLAUDE_PLUGIN_ROOT`, which is
  empty in a Bash call.
- The marketplace is named `context-lab`. Auto-update defaults key on the
  declared marketplace **name** against a hardcoded set of official names, so this
  name defaults to auto-update **off**, which is what is wanted.
