# A tool's manual lives in the tool's repo, and the catalogue only points

Two skills in `skills/stable/` were copies of skills that also exist in the repos
of the tools they document. They are now deleted from here, and
`.claude-plugin/marketplace.json` carries a pointer to each authoring repo
instead.

| skill | authoring repo | what it documents |
|---|---|---|
| `write-pr` | `luutuankiet/write-pr` | the npm CLI of the same name |
| `dbt-bq-optimize` | `luutuankiet/dbtcx` | the `dbtcx` PyPI tool |

`mcp-dev` is **not** in this table and stays here. It reaches for
`@luutuankiet/mcp-proxy-shim` as an instrument, but it is not that tool's manual —
it is a development loop that happens to invoke it. That repo ships no user-facing
skill at all; the three files under its `.claude/skills/` configure agents working
on that repo and are excluded from its npm `files` array.

## The rule

**A skill that documents a tool changes when the tool changes, so it belongs in
the tool's repo.** A skill about how this operator works belongs here. The test is
authorship of the subject, not who wrote the words.

## Why a pointer and not a copy

A marketplace entry naming a foreign repo is not a shortcut around vendoring — it
is what the plugin format is for. In Anthropic's own marketplace, 233 of 286
entries point at repositories other than the one holding the manifest. The
consumer's machine clones the named repo into its plugin cache at
`claude plugin install` time; nothing is copied at author time and this repo
commits none of the tool repos' bytes.

That keeps the invariant on
[skills-collection](../architecture/skills-collection.md) — no foreign bytes here,
checkable in one line rather than by a per-file provenance argument — and it
removes the failure [ADR 0002](0002-buckets-cut-on-maturity-repos-cut-on-privacy.md)
records as having hit every hand-maintained second copy in the predecessor repo. The drift was already real, not
hypothetical: the copy of `write-pr/SKILL.md` here had diverged **ahead** of its
upstream by one hunk, carrying a base-directory fix and a
`$CLAUDE_PLUGIN_ROOT`-is-empty warning that the authoring repo lacked. That hunk
was pushed upstream before the copy was deleted; it would otherwise have been lost
by the deletion.

## Why the tool repo carries its own `plugin.json`

A marketplace entry can supply everything — name, description, and the `skills[]`
allowlist — for a sourced repo that has no manifest at all. Four plugins in the
official marketplace are published exactly that way. It was still rejected here.

**The allowlist names directories, and it must live in the repo that can rename
them.** With the allowlist here, renaming `skill/dbt-bq-optimize/` upstream is a
defect in *this* repo, discovered by a user at install time. With the allowlist in
the tool repo, the rename and the manifest change land in one commit. `dbtcx` makes
the point concrete: its skill directory is the singular `skill/`, a name nothing
would guess.

The consequence is the intended one — an entry here is a name and a URL, and
carries no description to fall out of date.

## Why the entries carry no `ref` and no `sha`

Pinning to a release tag was considered and rejected as ceremony. Each entry
resolves its repo's default branch at install and update time, so a push to a tool
repo reaches every host on its next `claude plugin update`.

What is given up is reproducibility: someone handed this repo gets whatever those
default branches say that day, and a bad push upstream reaches every host that
updates. Accepted — these are the same operator's repos, and the alternative makes
a one-line typo fix in a skill require a tagged release.

## Why no tool repo declares a `version`

`version` names the plugin's cache directory. A static one gives a directory that
is never recreated, so `claude plugin update` reports *"already at the latest
version"* while serving stale content and emitting no error. Both new manifests
omit it, as this repo's own already does, which makes the cache key the source
commit sha.

The visible cost is that `claude plugin validate --strict` fails on all three
manifests with `No version specified`. Strict mode cannot pass without the key
that causes the bug. Validate without `--strict` and read the one warning as
expected.

## What changes for whoever uses the skills

The invocation namespace moves, because the plugin moves:

```
context-lab:write-pr          ->  write-pr:write-pr
context-lab:dbt-bq-optimize   ->  dbtcx:dbt-bq-optimize
```

`install.sh` gains a row per plugin, so a host that runs the installer gets all
three from the one `context-lab` marketplace and one `marketplace add`.

## Rejected alternatives

- **Each tool repo becomes its own marketplace.** Gives a second front door for
  someone who found the npm package without this repo. Nobody is expected to; two
  catalogues to keep in step buys nothing.
- **Fetch the tool repos' skills at author time and commit them.** One plugin and
  one entry point, at the price of reintroducing the copies this ADR deletes, and
  of a build step in a repo that has none.
