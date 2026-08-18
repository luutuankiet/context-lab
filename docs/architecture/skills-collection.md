---
title: The skills collection
covers: where the distributed skills live, how the stable bucket ships as a plugin, and why no third-party skill is vendored here
verified: 2026-08-18
---

# The skills collection

`skills/` is the collection this repo distributes. It is separate from `.claude/`,
which configures agents working *on* this repo and ships nowhere.

## Buckets are maturity only

The repo boundary cuts on **privacy**. This repo is public, so privacy is already
decided and maturity is the only axis left inside it.

| bucket | count today | meaning |
|---|---|---|
| `skills/stable/` | 6 | graduated; safe to depend on; **the only bucket that installs** |
| `skills/in-progress/` | 1 | live iteration; may change or disappear without warning |
| `skills/deprecated/` | 11 | the off-switch — excluded by the allowlist, no config edit needed |

Bucket placement therefore decides whether a skill installs at all. Moving a
directory between buckets is a behaviour change, not filing.

Skills that encode fleet topology — host names, endpoints, account-to-project
mappings — do not live here. They live in the private companion repo, and the test
for which is not "is it sensitive" but **"is it only relevant to me"**.

**The private repo is its own marketplace, and `install.sh` must never name it.**
This installer is public, so naming it would publish that repo's existence to
every consumer and hand them a plugin entry that 404s. The boundary is the
remote: anyone may add this marketplace, only the owner can resolve that one.
A host that wants the topology skills adds them itself:

```sh
claude plugin marketplace add luutuankiet/context-lab-private
claude plugin install context-lab-private@context-lab-private
```

Note that repo pins a `version` where this one deliberately does not, and it is
**GitHub-sourced**, so it is served from the cache copy rather than from a clone.
Its update path is therefore genuinely `marketplace update` + `plugin update`,
not `git pull` — the two repos are not symmetrical here, and that is a live
question rather than a settled one.

## The bucket rule is one line of JSON

`.claude-plugin/plugin.json` declares `"skills": ["./skills/stable"]`. A listed
path is itself a skill directory when it holds a `SKILL.md`, and otherwise its
**immediate children** are scanned — one level, never recursive. So the allowlist
*is* the bucket mechanism:

- adding a directory to `skills/stable/` publishes it, with no manifest edit;
- `mv`-ing it to `deprecated/` unpublishes it, also with no manifest edit;
- `in-progress/` and `deprecated/` are unreachable to a consumer by construction,
  not by a rule somebody has to remember.

Verified by installing it: `claude plugin details context-lab` lists exactly the
11 stable skills and nothing else, at ~1.2k always-on tokens for the whole bucket.

## Distribution: a marketplace whose source is the clone

Each host already clones this repo to run `install.sh`. That same clone is the
marketplace source, so nothing new is fetched and the update verb stays `git
pull`:

```sh
claude plugin marketplace add ~/dev/context-lab   # a filesystem path is a
claude plugin install context-lab@context-lab     # first-class source
```

`install.sh` step 3 does both, idempotently, for this plugin and the upstream one.

**Write for the oldest CLI in the fleet, not the newest.** Measured against
2.1.81 on personal, where the others run 2.1.233/234:

| | 2.1.81 | 2.1.233+ |
|---|---|---|
| `plugin install --yes` | `error: unknown option '-y'` | accepted |
| `plugin details` | no such command | works |
| `plugin validate` on the marketplace | fails: root `description` unrecognized | `--strict` *wants* a description |
| directory source, versionless sha, `skills` allowlist | all work | all work |

The mechanism itself is stable across both; only the CLI's own surface moved. So
`install.sh` passes no `-y`, and the marketplace keeps its `description` — it is
rejected by the old validator but ignored harmlessly by the old installer, and the
publish gate runs on the authoring host.

**`plugin.json` deliberately declares no `version`**, so the recorded version is
the source commit sha rather than a number somebody has to remember to bump.

**A directory-source marketplace is not copied.** Skills are read from the clone
itself, so editing one changes what the next session runs — no commit, no
reinstall. Measured, not assumed: an uncommitted edit was visible, and a brand-new
directory in `skills/stable/` was invocable with nothing installed in between.
`claude plugin install` does leave a ~900 KB copy under
`~/.claude/plugins/cache/`, but that copy is bookkeeping, not the read path, and
reading it to see what a host runs will mislead you
(`docs/traps/CLAUDE_PLUGIN_ROOT_IS_EMPTY_IN_BASH.md`).

Config files stay symlinked (ADR 0003); only skills changed carrier (ADR 0006).
`~/.claude/skills/` is no longer used by this repo at all and need not exist on
any host — foreign skills already sitting there are untouched, because plugins do
not read that directory.

## Graduation is a gate that can fail

Three conditions, all of them: valid frontmatter, a privacy scrub, and the owner's
call. Two mechanical checks back it:

```sh
scripts/skills-publish-gate.sh   # runs both, plus `claude plugin validate --strict`
```

```sh
find skills -type l          # must return empty — see below
# every SKILL.md frontmatter `name` must equal its directory name
```

**The symlink ban is the whole resolved-path rule.** A skill readable through a
symlink can be gitignored at the link's target and still publish its contents —
which is exactly how a private file once escaped a privacy gate. With no symlink
possible, the resolved path and the literal path coincide by construction, and the
gate needs no resolution logic at all.

The catalog is **generated** from frontmatter. There is no hand-written index of
skills, because every hand-maintained second copy in the predecessor repo drifted.

## No third-party skill is vendored here

This repo holds only what its author wrote. An upstream collection stays upstream
and is *exhibited* as a pinned pointer that a consumer installs on demand — never
copied in.

Three reasons, and the third is the one that decides it:

1. Vendoring duplicates a collection that is already installed as a plugin. The
   upstream README names this exact mistake: you subscribe *or* you fork, and doing
   both leaves you with every skill twice.
2. A copy carries a licence-notice obligation that no copy here ever met.
3. It makes the invariant checkable in one line — **zero third-party bytes in this
   repo** — instead of a per-file provenance argument.

The forks that used to be here were byte-identical or differed by a stripped
trailing newline. The observed failure was not copy-then-diverge; it was
copy-then-*not*-diverge, which is worse, because nothing ever signals that the copy
is redundant.

Hydration is `install.sh` step 3: it runs `claude plugin install` for the one
upstream collection in use, from the same list that installs this repo's own
plugin. The two are the same mechanism pointed at different sources.

**A subscription cannot be half-taken.** There is no per-skill off-switch for a
plugin: the settings key that looks like one short-circuits to "on" for plugin
skills, and the disable keys people reach for do not exist in the binary at all.
Installing the plugin means taking all of it.

## Collision with a local skill is narrower than it looks

Verified rather than assumed: skills **never shadow across levels — both appear**.
A personal skill beats a project one for the bare name, which is the *inverse* of
settings precedence. Plugin skills are always namespaced (`plugin:skill`). The
entire collision surface is that a same-named local skill revokes the plugin
skill's bare `/name` shortcut — it does not hide the skill.

Any provenance metadata a skill wants nests under `metadata:` in frontmatter. Bare
top-level keys pass local validation silently but are a **hard error** on upload,
where only a short allowlist of keys is accepted.
