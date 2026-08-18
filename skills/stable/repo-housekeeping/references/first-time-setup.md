# First-time setup

A repo with no root `AGENTS.md`, or one that has grown past a screen or two, has
never been laid out this way. This is the one-time conversion. It is a much larger
job than a wrap-up pass, and it needs the human in the loop.

**It does not apply to a small repo a newcomer can read in an afternoon.** The whole
value is in not re-deriving expensive things. If there is nothing expensive to
re-derive, skip it and say so.

## Do no harm, first

**A private notes directory may contain live secrets.** Agent journals accumulate
whatever the agent needed: a password pasted for a deploy, a key inside a `curl`,
tokens, internal hostnames. It has been safe only because the directory is
gitignored, and that ignore rule is the *only* control holding it.

- **Never `git add -f` anything inside it.**
- **Never copy a value out of it into a page.**
- **Scan before the first commit of `docs/`, not after.** Committing is permanent —
  history cannot be rewritten without a force-push.
- **Enumerate raw.** Default tooling skips ignored files and dotfiles, so a listing
  built with default flags can miss half a directory and return zero hits on the one
  real credential. Use `rg -uu --hidden` (or `find`) when taking inventory, or you
  will write a confident menu from half the material and never learn the rest exists.

**Do not touch the real repo until the human has seen the shape.** Build it in a
scratch directory that mirrors the repo root, show it, then port. It is cheap, and
it avoids arguing about a diff.

## 1. Find the material, and index before you read

Typical stores: a gitignored journal directory, an oversized `CLAUDE.md`, a `docs/`
folder nobody maintains, release notes, and the git log.

**These files are large. Do not read them linearly.**

```sh
wc -c <each candidate>
rg -n '^#{2,4} ' BIG_FILE.md     # index by heading before reading any of it
```

Use `^#{2,4} `, not `^#{1,4} ` — shell comments inside fenced code blocks look
exactly like level-1 headings, and an index built from `#` is convincing and wrong.

Then read **selectively**, only the sections whose headings suggest durable content.
In one real conversion, 84% of a 247 KB file was a superseded chronological archive;
reading it would have been pure waste.

If there is no journal, derive the material from history instead:

```sh
git log --format='%s' | rg -i 'fix|revert|regress' | head -50
```

Commits that fix the same thing twice, and reverts, are where the traps are.

## 2. Sort, ladder, verify

Steps 3, 4 and 5 of `SKILL.md`, applied to the whole pile instead of one session's
findings. Two things change at this scale:

- **Show the human a menu before writing anything** — the proposed disposition of
  every item plus the shape of the output. Collapse the list on depth, and collapse
  it **asymmetrically: freely on the delete side, never on the keep side.** That
  turns an unreadable 63-row menu into 6 rows and is safe precisely *because* the
  collapsed rows are the deletions.
- **Assume every quoted fact has drifted.** In one real conversion, measured against
  disk: every quoted line number had moved, systematically, one by 79 lines; one
  documented path did not exist; a claimed "4 call sites" was 2; and one fully
  drafted, well-argued page described a bug that had **already been fixed** — it was
  deleted before it shipped.

## 3. Write the root contract

```
CLAUDE.md   ->  one line: @AGENTS.md
AGENTS.md   ->  always resident, keep it small
```

`AGENTS.md` is the cross-tool convention. Claude Code does not read it natively, so
a `CLAUDE.md` containing exactly `@AGENTS.md` is an eleven-byte bridge.

**An `@import` does not defer cost** — imports load at launch exactly like inline
text. `@AGENTS.md` is fine because it points at one small file. Never `@`-import a
docs tree hoping it will load lazily; deeper pointers are plain markdown links.

The project half, roughly 2 KB, four things:

1. **What the project is** — a short paragraph a stranger could understand.
2. **The hard constraints** — the three or four facts that shape most decisions and
   are embarrassing to violate. "Ships unbundled, so an edit reaches users
   verbatim." "Single user on a trusted network — there is no auth model."
3. **A directory skeleton**, 8–14 lines, `path — one clause each`. **Sanity-check
   every path against disk.** Projected layouts in old docs list directories that
   were never created.
4. **Build and check commands that actually exist.** Run them. Advertising a `npm
   test` that is not there is worse than saying there is no test runner.

Then the standard block. Everything above it belongs to the project; everything
below is what every repo laid out this way carries:

```markdown
<!-- Standard block. Everything above belongs to this project; everything below is
     the pointer every repo laid out this way carries. -->

## Documentation

Indexed in [docs/README.md](docs/README.md). Every page is self-contained — it
assumes you opened that one file and have nothing else loaded.

| where | what | read it |
|---|---|---|
| [architecture/](docs/architecture/) | where behaviour lives, one page per area | before going looking for something |
| [traps/](docs/traps/) | failure modes with no error message, indexed by symptom | before debugging something wrong but not crashing |
| [reference/](docs/reference/) | simply true, expensive to re-derive | when you need the detail |
| [adr/](docs/adr/) | why the repo is the way it is | before changing something that looks odd |

## Before you wrap up

Leave the repo holding what this session cost you to find out. Four rules.

1. **Sort it, and expect most of it to go nowhere.** A next action is an issue. A
   durable, expensive-to-re-derive fact is a page. A hard-to-reverse choice with a
   rejected alternative is an ADR. Status, dates, version pins and plans are none of
   those — delete them.
2. **A doc is the last resort.** Type error → test → comment at the site → doc.
   Name the single line you would have commented instead; if you can name it,
   comment it and stop.
3. **Verify against running code before writing, and date the page `verified:`.**
   Anything remembered from earlier in the session is stale until re-read. Deleting
   a draft because the problem is already fixed is a success.
4. **Append, never rewrite.** Supersede a merged ADR with a new one naming what it
   replaces. A trap filename is an identifier quoted elsewhere: edit the body, never
   the name.

Then run <the repo's index generator>. Never hand-maintain an index.
```

**Brownfield rule: append, never replace.** Most repos already have a `CLAUDE.md` or
`AGENTS.md` with real content. If a `CLAUDE.md` already has substance, leave it and
add `@AGENTS.md` as its first line.

The contract **must stand alone**. A root file that says only "invoke the
housekeeping skill" is broken for every reader who has not installed it — which is
the default case for anyone else who clones the repo.

## 4. Generate the index

One source of truth (the page frontmatter), one render (`docs/README.md`), spliced
between two marker comments so hand-written surrounding prose survives. Dependency-
free, in whatever the repo already has — do not add a toolchain, and do not reach
for a static site generator to render one list.

A worked implementation in POSIX-ish bash + awk, about 180 lines, is
`scripts/gen-docs-index.sh` in the Context Lab repository. Copy it and change the
collections if the repo wants different ones.

Give it a `--check` mode that exits non-zero when the index is stale. **Do not wire
it into CI.** A repo that fails somebody's build to teach them a layout has
announced the layout; `--check` exists so a person or an agent can ask.

## 5. Measure, and show the human

```sh
# before: everything unconditionally loaded
wc -c CLAUDE.md <every @-imported file> <the journal, if it was read every session>

# after
wc -c CLAUDE.md AGENTS.md
```

Roughly four bytes per token is close enough. Report the before and after honestly,
including the worst case — resident, plus one skill body, plus one page — because
that is the number someone will challenge.

## 6. Retire the old system

Once the human has judged the result:

1. Run the credential scan over everything about to be committed.
2. Commit `docs/`, `AGENTS.md`, `CLAUDE.md` and the generator.
3. File the issues that came out of the sort.
4. **Delete the journal directory**, and remove its gitignore entry.

Do not keep it "just in case". A second store of truth is how the first one rotted.
If a fact was worth keeping it is in `docs/` now — and if you are not confident of
that, you are not finished sorting.
