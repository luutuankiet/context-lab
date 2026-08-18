# One entry point for repo context, reached by a scanner

`repo-housekeeping` and `promote-working-notes` are merged into
`repo-context-audit`. A scanner reports where a repository actually is — cold,
structured or wired, plus two orthogonal flags — and routes to a reference page
from there. Promotion and the page-format definition stop being things you have
to know to invoke and become routes.

Three entry points meant the operator had to pick one, and two of them only made
sense after the third had run. The scanner removes the choice, and it is a
filesystem test rather than a judgement, so it costs nothing to run first.

## Considered options

**Keep them separate.** Rejected: the two skills stated the same asymmetric-collapse
menu rule twice in different words with the same figures, and each described the
other's territory to explain where its own job stopped. Two of the three were
unreachable without knowing the third existed.

**One skill per operational-cache entry**, the shape an earlier ticket specified.
Rejected on measurement: across fifty working-note directories on this fleet, the
median directory held zero admissible procedures and roughly two were cleanly
repository-specific rather than host-specific. That is a gated exception, not a
tier. The standard tier is two generated index skills routing to `docs/`, which
costs two resident descriptions instead of N and keeps every fact in markdown that
every tool and every human can read.

## Consequences

- **No continuous-integration workflow ships.** The origin gist this format came
  from wires the index check into a build; that appendix is dropped, and
  `references/route-setup.md` says so explicitly so an agent that later reads the
  gist does not reintroduce it. This is
  [ADR 0005](0005-nothing-mechanical-enforces-the-layout.md) applied, not a new
  decision — the governing rule for what is emitted is invite, never enforce.
- **The emitted artifacts are the teaching mechanism, and they are the whole of
  it.** After a repository is wired, this skill may never load in it again. The
  emitted `repo-maintenance` skill therefore carries a second copy of the
  decision-record admission tests. That copy is deliberate and is a known drift
  risk, which the repair route checks by diffing against the shipped template.
- **The index generator moved into the skill**, and `scripts/gen-docs-index.sh`
  in this repository became a wrapper around it. A generator carries a schema, and
  the schema has one home.
