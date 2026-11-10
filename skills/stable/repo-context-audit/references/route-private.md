# Route: private project context

Some context is not ready to publish: client work still being planned, a decision
agreed only internally, a study nobody has signed off. It still has to survive
the session. It lives in a **project**: a plain folder at `tmp/projects/<slug>/`
inside whatever repository the session is in, ignored by git, never committed.

Enter this route when the operator asks for it, or when you judge that what the
session learned belongs to such a piece of work and not to the repository's
published pages. The scanner does not send you here and its state does not change.

## No menu inside the folder

**Inside `tmp/projects/` you write at your own discretion, without a menu and
without approval.** Nothing in the folder leaves the machine, so there is no
decision for a human to make before the write. Afterwards, report briefly: what
you wrote, and what you left alone.

The exemption ends at the folder's edge. Anything written outside
`tmp/projects/`, including a published page that draws on a project, goes through
the menu in `SKILL.md` as usual. **Never copy a file or a value out of a project
into a published page.** Rewrite it in the published page's own terms.

## 1. Reuse before you create

```sh
<this skill's base directory>/scripts/projects.sh              # every project, newest first
<this skill's base directory>/scripts/projects.sh --since 30   # touched in the last 30 days
```

Each row is the slug, the date of the newest file in the project, the file count
and the first line of its scope. If a project's topic matches the work in hand,
use it. Create a new one only when none does.

## 2. Create one

```sh
<this skill's base directory>/scripts/projects.sh --init <slug>
```

The slug is short kebab-case, named after the client or the work stream, with no
date in it. The command first checks that git ignores `tmp/projects`; if not, it
adds the path to `.git/info/exclude`, which is local and never committed. Then it
writes two files and nothing else:

```
tmp/projects/<slug>/CLAUDE.md    one line: @AGENTS.md
tmp/projects/<slug>/AGENTS.md    a skeleton ending in the wrap-up block
```

It refuses a slug that exists. Do not run `git init` in a project: it is a plain
folder.

Now fill in `AGENTS.md` above the block: what the project is, in a paragraph a
stranger could follow, and the few hard constraints. It is loaded whenever a
session works in the project, so the 4 KB budget applies. A session-start hook
that lists folders holding their own `AGENTS.md` can then show the project to new
sessions; the file's first lines and its modified time are what such a listing
has to go on.

## 3. The layout is a repository's, built lazily

| path | when it appears |
|---|---|
| `CLAUDE.md`, `AGENTS.md` | at creation |
| `README.md` | optional: the scope, for a human reader |
| `TRACK.md` | optional: open decisions and next actions, free-form. Link it from `AGENTS.md` once it exists |
| `docs/architecture/`, `docs/traps/`, `docs/reference/`, `docs/adr/` | each with its first page |
| `docs/README.md` | generated, with the first page |
| `.claude/skills/codebase-map/`, `.claude/skills/repo-maintenance/` | with the first page, written as in [route-author-skills.md](route-author-skills.md) |

Do not scaffold empty directories. Pages use the formats in
[page-formats.md](page-formats.md), unchanged.

A project has no issue tracker. **A next action is a line in `TRACK.md`**, which is
what the wrap-up block in the project's `AGENTS.md` says.

Dated `tmp/YYYYMMDD/<topic>/` folders stay where they are. They are raw evidence:
cite them from a project page by path, and never move them into the project.

## 4. Maintain it like a repository

Once a project is loaded, treat it exactly as you would a repository root. The
same scanner and generator work on it:

```sh
<this skill's base directory>/scripts/audit.sh --repo tmp/projects/<slug>
<this skill's base directory>/scripts/projects.sh --reindex [<slug>]
```

`--reindex` runs the index generator on every project that has pages, or on the
one named, and then touches its `AGENTS.md` so the file's modified time shows when
the project was last worked on. Run it after adding or renaming a page. Never
hand-maintain an index here either.

**A young project reads as `structured`, and that is not a fault.** The scanner
reports each collection that does not exist yet and each missing index skill.
Those appear with their first page; do not create them to satisfy the scanner.

## What may be kept

Treat the project as a local repository. Client names, hosts, raw captures and
other private material may be kept in it as they are. There is no pass that
replaces values with placeholders and no check for internal names, because none
of it is published.

## What this route does not do

- **It marks nothing as draft.** There is no status key and no fixed first line.
  Being under `tmp/projects/` is the whole signal.
- **It has no way out.** A project may later be rewritten into the repository's
  own pages, become a repository of its own, or be deleted. Each of those is the
  operator's decision at the time, and none of them is a step here.
- **The repository's scanner and the dated-folder promotion route do not see
  projects.** `audit.sh` at the repository root never counts anything under
  `tmp/projects/` as unpromoted notes, and promotion refuses a project folder.
