---
title: The skills collection
covers: where the distributed skills live, which bucket actually installs, and why no third-party skill is vendored here
verified: 2026-08-17
---

# The skills collection

`skills/` is the collection this repo distributes. It is separate from `.claude/`,
which configures agents working *on* this repo and ships nowhere.

## Buckets are maturity only

The repo boundary cuts on **privacy**. This repo is public, so privacy is already
decided and maturity is the only axis left inside it.

| bucket | count today | meaning |
|---|---|---|
| `skills/stable/` | 10 | graduated; safe to depend on; **the only bucket that installs** |
| `skills/in-progress/` | 2 | live iteration; may change or disappear without warning |
| `skills/deprecated/` | 13 | the off-switch — excluded by path, no config edit needed |

Bucket placement therefore decides whether a skill installs at all. Moving a
directory between buckets is a behaviour change, not filing.

Skills that encode fleet topology — host names, endpoints, account-to-project
mappings — do not live here. They live in the private companion repo, and the test
for which is not "is it sensitive" but **"is it only relevant to me"**.

## Nothing installs today

`install.sh` step 4 runs `link-skills.sh` if it is executable. **That file does not
exist in this repo.** The step is a deliberate no-op, not an oversight, and the
consequence is worth stating plainly: a host that runs `install.sh` today gets the
user-tier config and **zero skills**.

Distribution, once the linker lands, is clone-plus-link and `git pull` — no
package, no credential on a daily driver, no push from a central host. A public
repo needs no credential, so nothing new lands on any machine.

## Graduation is a gate that can fail

Three conditions, all of them: valid frontmatter, a privacy scrub, and the owner's
call. Two mechanical checks back it:

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

Hydration is `install.sh` step 3 today: it runs `claude plugin install` for the one
upstream collection in use. A manifest-driven form is not built yet.

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
