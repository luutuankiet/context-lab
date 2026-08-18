# Route: cold — first-time conversion

The repository has no contract file, or nothing imports it. This is the one-time
conversion, it is a much larger job than any other route, and it needs the human
in the loop before anything is written.

**It does not apply to a small repository a newcomer can read in an afternoon.**
The whole value is in not re-deriving expensive things. If there is nothing
expensive to re-derive, say so and stop.

**Do not touch the real tree until the human has seen the shape.** Build it in a
scratch directory that mirrors the repository root, show it, then port. It is
cheap, and it avoids arguing about a diff.

## 1. Find the material, and index before you read

Typical stores: a gitignored journal directory, an oversized `CLAUDE.md`, a
`docs/` folder nobody maintains, release notes, and the git log.

**These files are large. Do not read them linearly.**

```sh
wc -c <each candidate>
rg -n '^#{2,4} ' BIG_FILE.md     # index by heading before reading any of it
```

Use `^#{2,4} `, not `^#{1,4} ` — shell comments inside fenced code blocks look
exactly like level-1 headings, and an index built from `#` is convincing and
wrong. Then read **selectively**, only the sections whose headings suggest
durable content. In one real conversion, 84% of a 247 KB file was a superseded
chronological archive; reading it would have been pure waste.

**If the scanner set the notes flag, the notes directory is not yours to open
here.** Read [route-promote.md](route-promote.md) and run its Gate 1 first — raw
enumeration and an approved menu — then come back with what survived.

If there is no journal at all, derive the material from history:

```sh
git log --format='%s' | rg -i 'fix|revert|regress' | head -50
```

Commits that fix the same thing twice, and reverts, are where the traps are.

## 2. Sort, ladder, verify

[sort-and-ladder.md](sort-and-ladder.md), applied to the whole pile rather than
one session's findings. Show the menu and stop, per the authority block in
`SKILL.md`. Assume every quoted fact has drifted.

## 3. Scaffold, and write the contract

```
CLAUDE.md   ->  one line: @AGENTS.md
AGENTS.md   ->  always resident, keep it small
docs/{architecture,traps,reference,adr}/
docs/README.md
scripts/gen-docs-index.sh
```

`AGENTS.md` is the cross-tool convention. Claude Code does not read it natively,
so a `CLAUDE.md` containing exactly `@AGENTS.md` is an eleven-byte bridge.

**An `@import` does not defer cost** — imports load at launch exactly like inline
text. `@AGENTS.md` is fine because it points at one small file. Never `@`-import
a docs tree hoping it will load lazily; deeper pointers are plain markdown links.

The project half, roughly 2 KB, four things:

1. **What the project is** — a short paragraph a stranger could understand.
2. **The hard constraints** — the three or four facts that shape most decisions
   and are embarrassing to violate. "Ships unbundled, so an edit reaches users
   verbatim." "Single user on a trusted network — there is no auth model."
3. **A directory skeleton**, 8–14 lines, `path — one clause each`.
   **Sanity-check every path against disk.** Projected layouts in old docs list
   directories that were never created.
4. **Build and check commands that actually exist.** Run them. Advertising a
   `npm test` that is not there is worse than saying there is no test runner.

Then append [templates/AGENTS-standard-block.md](../templates/AGENTS-standard-block.md)
verbatim, substituting the index generator's path.

**Brownfield rule: append, never replace.** Most repositories already have a
`CLAUDE.md` or `AGENTS.md` with real content. If a `CLAUDE.md` already has
substance, leave it and add `@AGENTS.md` as its first line.

The contract **must stand alone**. A root file that says only "invoke the audit
skill" is broken for every reader who has not installed it — which is the default
case for anyone else who clones the repository.

## 4. Install the generator

Copy [scripts/gen-docs-index.sh](../scripts/gen-docs-index.sh) into the
repository as `scripts/gen-docs-index.sh`. It is dependency-free bash and awk, it
takes `--check`, and it renders all five collections into `docs/README.md` and,
once they exist, into the two emitted skill bodies.

Do not add a toolchain for this, and do not reach for a static site generator to
render one list.

**Ship no continuous-integration workflow.** The origin gist this format came
from carries a workflow appendix that fails a build when the index is stale.
**It is dropped, deliberately.** A repository that fails somebody's build to
teach them a layout has announced the layout, and the rule here is invite, never
enforce. `--check` exists so that a person or an agent can ask. If you later read
that gist, this paragraph is why its Appendix D is not here.

## 5. Author the two skills

The scanner will now report `structured`. Continue at
[route-author-skills.md](route-author-skills.md) — that is where the emitted
artifacts get written, and they are the whole teaching mechanism for every agent
that walks into this repository afterwards.

## 6. The seed decision record

Write one record of **this repository's own promotion**, in this repository's
terms: what was promoted, what was discarded, and what alternative was rejected.
Format in [page-formats.md](page-formats.md).

It is a worked example as much as a record. A cold agent that has never seen this
skill learns from it that decisions are recordable here at all — and that is the
one destination that is append-only and unrecoverable.

**Never copy a record out of another repository.** What is emitted here carries no
brand: a repository laid out this way reads as ordinary good housekeeping, not a
methodology to learn first. If the promotion this record would describe already
happened and is already recorded, skip it and say so.

## 7. Measure, and show the human

```sh
# before: everything unconditionally loaded
wc -c CLAUDE.md <every @-imported file> <the journal, if it was read every session>

# after
wc -c CLAUDE.md AGENTS.md
```

Roughly four bytes per token. Report before and after honestly, including the
worst case — resident, plus one skill body, plus one page — because that is the
number someone will challenge.

## 8. Retire the old system

Once the human has judged the result:

1. Run the topology check over everything about to be committed —
   [topology-check.md](topology-check.md).
2. Commit `docs/`, `AGENTS.md`, `CLAUDE.md`, the generator and the two skills.
3. File the issues that came out of the sort.
4. **Delete the journal directory**, and remove its gitignore entry.

Do not keep it "just in case". A second store of truth is how the first one
rotted. If a fact was worth keeping it is in `docs/` now — and if you are not
confident of that, you are not finished sorting.
