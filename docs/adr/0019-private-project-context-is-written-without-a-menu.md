# Private project context lives under tmp/projects/ and is written without a menu

The repo-context-audit skill holds published context: pages a repository commits.
Some context is not final. Client work is still being planned, or a decision has
been agreed only internally. It had nowhere to go but a dated scratch folder that
the next session would not find.

## A project is a plain folder at `tmp/projects/<slug>/`

One undated folder per client or work stream, ignored by git, with no repository
of its own. It uses the layout of a repo root, built lazily: `CLAUDE.md` and
`AGENTS.md` at creation, each `docs/` collection, the generated index and the two
index skills with their first page. Open decisions and next actions are lines in
an optional free-form `TRACK.md`, because a project has no issue tracker.

The existing scanner and generator maintain a project through `--repo`. One new
script, `scripts/projects.sh`, lists projects, creates one and regenerates their
indexes. Before its first write it checks that git ignores `tmp/projects`, and
adds the path to `.git/info/exclude` when it does not.

## The exception: no menu inside the folder

The skill's authority rule is "Report the menu and stop": every route that writes
shows a human what would be written and waits. That rule exists because a written
page is published. **Nothing under `tmp/projects/` leaves the machine, so inside
it the agent writes at its own discretion and reports afterwards.**

The exception is the path and nothing more. A write anywhere else goes through
the menu. The skill's prohibition on copying out of a private notes directory
covers projects unchanged: published pages are rewritten, never copied.

## Considered options

- **A slim layout with its own generator.** A single notes file per project, and
  a small indexer for them. Rejected: an agent would have to learn a second
  layout, and a project that grew would need converting. With the full layout an
  agent that has loaded a project maintains it the way it maintains any
  repository, with the tools it already has.
- **A separate skill.** Rejected: the scanner, the generator, the page formats
  and the wrap-up rules would be duplicated or cross-referenced, and the
  exception to the menu would sit far from the rule it qualifies.
- **A status marker on every page.** A frontmatter key or a fixed first line
  saying the page is not final. Rejected: the location already says it, and a
  marker is one more thing to strip, forget or trust wrongly when a page moves.
- **A dedicated promotion path.** A route that moves a finished project into the
  published pages. Rejected: a project may be rewritten into the root pages,
  become its own repository, or be deleted, and which one is not knowable in
  advance. A fixed path would also invite copying, which the skill forbids.

## Consequences

- Client names, hosts and raw captures may sit in a project as they are. No pass
  replaces them with placeholders and no check looks for internal names, so a
  project is only as private as the machine it is on.
- A project is not backed up or shared by git. Losing the folder loses the work.
- The root scanner never counts anything under `tmp/projects/` as unpromoted
  notes, and the `tmp/` promotion route (ADR 0015) refuses a project folder.
  Both would otherwise keep proposing to publish what was put there to stay
  private.
- A young project scans as `structured` with missing collections. That is its
  normal state, and the scanner's state logic was left alone to keep it true for
  real repositories.
- The ignore guard writes `.git/info/exclude`, never `.gitignore`, so a host
  repository gains no committed trace of private work.
