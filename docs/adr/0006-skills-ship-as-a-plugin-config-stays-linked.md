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

## Why no `version` key

`plugin.json` declares no `version`, and that is deliberate. With one, `claude
plugin update` compares the declared version and does **nothing** when it has not
moved — so a forgotten bump silently strands every host while every command
reports success. With no version key, the plugin's version *is the source commit
sha*: `git pull` moves the sha, `install.sh` sees a new version, and the host
updates. Verified both ways on thinkpad — an edit under a static `0.1.0` did not
propagate, and the same edit versionless installed as `ea8bf49fd432`.

The accepted cost is that **the cache is a copy, refreshed per commit**, which
gets its own page: `docs/traps/EDITS_ONLY_REACH_A_SESSION_AFTER_A_COMMIT.md`.

## What this costs, honestly

0003's decisive property was **drift visibility** — an edit through a symlink
writes into the tracked file and shows up in `git status`. A plugin is copied into
`~/.claude/plugins/cache/`, so an edit made *to the cache* is invisible, which is
the failure mode 0003 named (a statusline fix hand-applied on one host, unnoticed
on another for weeks).

Two things make that acceptable here where it was not acceptable for config:

1. The copy is **derived, not authored**. It is keyed by commit sha, so it is
   reproducible from the clone, and there is no reason to ever edit it.
2. Nothing else can deliver the namespacing and the one-line bucket rule. Skills
   installed as loose directories under `~/.claude/skills/` collide on bare names
   and need a linker plus an exclusion rule to keep `in-progress/` and
   `deprecated/` off a host.

The authoring host is the one place where the copy genuinely bites, because the
repo *is* the skills being edited. The answer is not a special case: commit, then
`./install.sh`. A commit is cheap, and the alternative — symlinking a checkout in
as a version entry so the cache is live — trades the trap for an untracked,
hand-made cache entry, which is precisely the thing 0003 refused.

## Consequences

- The fleet update verb is `git pull && ./install.sh`, unchanged in shape from
  0003 and now covering skills too.
- `~/.claude/skills/` is unused by this repo and need not exist on any host.
  Foreign skills already sitting there are untouched — plugins do not read it.
- Skills are invoked **namespaced**: `context-lab:<name>`. Prose inside a skill
  that pointed at an unpublished sibling by bare name was rewritten to say so.
- Scripts inside a skill are addressed as
  `"$CLAUDE_PLUGIN_ROOT"/skills/stable/<skill>/scripts/...`, not by a path
  relative to a repo the consumer does not have.
- The marketplace is named `context-lab`. Auto-update defaults key on the
  declared marketplace **name** against a hardcoded set of official names, so this
  name defaults to auto-update **off**, which is what is wanted.
