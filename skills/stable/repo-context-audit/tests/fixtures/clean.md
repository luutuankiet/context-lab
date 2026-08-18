# A page that should produce zero hits

This fixture is the negative control. It is written the way the format asks
for — inline evidence, real numbers, real citations — and none of it is
topology.

The conversion took 888 KB of notes down to 8 pages and 3 issues, and the
always-resident context fell from roughly 28 KB to 3.2 KB. Those numbers stay
as written: a scrub that collapses every number to `N` destroys the pedagogy
the example existed for.

Reproducible references are not leaks and stay as written:

- commit `7fead737dd3a88688de4868454c93a8c6ff5f463`
- `scripts/gen-docs-index.sh:112`
- <https://github.com/luutuankiet/context-lab>
- the `mattpocock-skills` plugin

Placeholders elided in prose are already correct and must not be rewritten:
`Authorization: Bearer <PAT>`, `--token=<redacted>`.

Paths are written relative to the repo, or with `~/` for a home directory —
never as an absolute path with a username in it.
