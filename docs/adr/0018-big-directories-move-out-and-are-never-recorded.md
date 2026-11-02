# Big directories move out of promotion and are never recorded

Promotion lists every file under a topic folder. A git-less tree extracted from a
container image can hold thousands of files, none of them ours to commit: in the repo
that raised this, 94% of a 15,915-row menu came from three such trees. The menu had to
stop asking about them file by file, and the agent had to learn what to do with them.

## The tree moves to `tmp/refs/<key>/`

The menu folds such a directory to one row and proposes moving it, the way a nested
clone already moves. It gets a row on the reference page and a `$KEY`, and citations
name it by image digest. envscan gains no concept of a tree.

## Folding is by size alone

A directory folds at `MENU_TREE_MIN` unrecorded files, default 200, with no clone,
recorded file or changed file inside. Shallowest wins, the topic folder never folds,
and `--expand` declines a fold for a whole subtree.

**The threshold rests on one repo:** authored directories there topped out at 112 files
and extracted ones started at 254. Whether that gap holds elsewhere is not established,
which is why the threshold stays overridable and a fold is only ever a proposal the
operator can decline.

## Considered options

- **Record trees in the promotion store.** One record per tree would make the menu short
  without moving anything. Rejected: a record says a file's content was handled, and a
  tree's content never is. It would also teach the store and the leak scan a second kind
  of thing, and the scan would still pay for every file in a folder that stayed put.
- **Detect trees by extension or modified time.** Rejected: two of the three trees read
  as authored SQL projects by both measures, so a content heuristic would have offered
  them for promotion file by file.

## Also changed

This supersedes the sentence in ADR 0017 that the judge reads only `md txt py sh sql yml
yaml toml`. It now reads `.log`, `.json` and `.diff` as well, so reading a tool-output
file whole is no longer the only check on those types, though it stays a required one
for a snapshot.
