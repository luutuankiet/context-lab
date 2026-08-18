# Nothing mechanical enforces the layout

There is no CI gate, no git hook, and no automated action that holds a repo to this
layout. An agent does it at authoring time, prompted by the contract in the root
`AGENTS.md` and carried out by a skill whose description fires on wrap-up phrases.
That agent is the first-class driver of the practice, not a backstop for it.

The argument is a product argument, not a convenience one. **A repo laid out this
way must be drivable by any cold agent or any engineer with repo access without
them knowing the idea exists.** If it is working it reads as ordinary good
housekeeping — and a repo that fails somebody's build to teach them a methodology
has announced the methodology.

## Considered options

- **A CI gate on format conformance.** Rejected for the reason above, and because
  it converts a contributor's first pull request into a lecture.
- **A git hook.** Rejected doubly. Hooks here are installed at *user* tier,
  fleet-wide, so a format gate written as a hook would fire on every repo on the
  machine — including every repo that never opted in.
- **Naming the skill in the root file** — "invoke the housekeeping skill before you
  finish". Rejected: a root file that says only that is broken for every reader who
  has not installed the collection. The root file must stand alone.

## Consequences

The L0 surface **splits across two halves so that no fact is written twice**. The
root `AGENTS.md` carries the *contract* — what tidy looks like, and the instruction
to tidy before wrapping up — in harness-agnostic prose that any agent can act on
with nothing installed. The skill carries the *procedure* — how to do it — and
never restates the contract. The contract does not name the skill.

**The practice stays nameless.** *Context Lab* names the lab; what it emits into
another repo carries no brand at all, so a converted repo reads as a repo that is
laid out well rather than a repo running someone's methodology. The skill is named
for what it does.

Two `--check` commands exist — the docs-index generator's and the installer's — and
**nothing runs them for you**. They are there so a person or an agent can ask; they
are not gates.

The honest cost: without a mechanism, conformance decays exactly as fast as the
habit does. This is accepted. The alternative was a mechanism that would make the
repo hostile to the reader it was built for.
