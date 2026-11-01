# Reference clones: private repos you may read but not commit

A *reference clone* is a private repository cloned locally with permission, so its
code can be read. The clone is never committed. A repo records it with a pointer, so
it can be rebuilt on another machine.

This page is the record to keep while promoting. No rebuild tool exists; the commands
below are run by hand or by an agent when a move to a new machine happens.

Any other clone, such as a public project cloned for research, needs a pointer only
if committed text cites it, and it needs no `.env` keys.

## Keys

The gate matches whole strings, so the URL alone misses most ways of writing the same
repo. In a test of eight forms, the full URL caught only itself.

| key | holds | when |
|---|---|---|
| `REPO_A_URL` | the clone URL, with no credentials in it | always |
| `REPO_A` | `owner/repo` | always; it catches HTTPS, SSH and citation forms |
| `REPO_A_HOST` | the host | only if the host identifies the client; a shared host would block every link to it |
| `REPO_A_OWNER`, `REPO_A_NAME` | each part alone | only if distinctive; a common word is a rewrite item instead |

Cite a line as `$REPO_A@<sha>:<path>:<line>`. A path can carry names too, so it goes
through the same scan as other text.

## The pointer

A repo keeps one page, `docs/reference/reference-clones.md`, with a row per clone: the
key, what the clone is for, and the rebuild command. It does not hold a pinned revision
or a capture time, because each citation carries its own SHA and a single pin would go
stale.

```sh
url=$(grep '^REPO_A_URL=' .env | cut -d= -f2-)
git clone "$url" tmp/refs/repo-a
```

The folder is named after the key, not the repo. Read `.env` one key at a time like
this: sourcing it breaks on the `&` and `#` in URLs.

Make it a full clone. A depth-1 clone cannot read an older citation. A citation is
read without moving the checkout, using `git show <sha>:<path>`.

Existing clones stay where they are, including any outside `tmp/`, and the rule applies
wherever they sit. New rebuilds go to `tmp/refs/<key>/`.

## What may leave a clone

Citations and descriptions in your own words. No verbatim client code, and no snapshots
from inside a clone. A clone is never a promotion target and is never committed into.

## When a clone counts as cache

Only with no unpushed commits, no stash, and a clean `git status`. Anything else goes
on the menu like any other file, because deleting the clone would lose that work.
Gitignored files are not covered by this check.

## When a rebuild fails

A rewritten-away revision and lost access both exit `128`, and an agent cannot tell an
expired login from withdrawn permission. So stop and report:

- Never substitute the latest revision for a citation.
- Never delete a clone on its own; ask the operator on the menu whether permission has
  ended.
- A citation that can no longer be resolved stays as history.

An old clone keeps a revision after upstream rewrites it away, and may be the last
copy. Before calling a folder safe to clear, check that each cited revision can still
be fetched from the remote.
