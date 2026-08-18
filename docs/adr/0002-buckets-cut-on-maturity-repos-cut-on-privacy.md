# Buckets cut on maturity; repos cut on privacy

Skills are split across two repositories by **privacy** — one public, one private —
and within a repository into buckets by **maturity** (`in-progress/`, `stable/`,
`deprecated/`). The two axes never share a boundary.

The reasoning is which attribute changes. Maturity changes constantly; privacy
almost never does. Putting the fast-moving attribute on the expensive boundary —
the repo — would mean a repo-to-repo move every time a skill graduated.

## Considered options

- **Private-WIP promoted to public-when-mature.** Rejected: it puts maturity on the
  repo boundary, so every graduation is a cross-repo copy, and copy-then-diverge is
  the dominant observed failure in the predecessor repo.
- **Topic buckets** (the upstream collection's shape: `engineering/`, `writing/`).
  Rejected: it mixes topic and maturity on one tree, and only maturity has a
  mechanical consumer — the linker keys on the path.

## Consequences

`skills/deprecated/` is the off-switch, excluded by path with no config edit
needed. Bucket placement therefore decides whether a skill installs at all, which
makes moving a directory a behaviour change rather than filing.

Graduation is a gate that can fail — valid frontmatter, a privacy scrub, and the
owner's call — and the catalog is generated from frontmatter rather than
hand-written, because every hand-maintained second copy in the predecessor repo
drifted.

The private repo's honest job is sync between the two machines that use it, not
fleet reach. Its membership test is not "is this sensitive" but **"is this only
relevant to me"** — which reduces to *did I write it for myself*, and makes
authorship the single axis that privacy and provenance both hang off.
