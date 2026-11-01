# Promotion keeps cited tool output, is opt-in, and ends in the context audit

Supersedes the "raw tool output" row of ADR 0015, which kept logs and tool JSON in
`tmp/` and never promoted them.

## Cited output is snapshot, sanitized

A page often rests on a run: a benchmark log, a build or test result. Under ADR 0015
that output stayed in `tmp/`, so the claim lost its proof when `tmp/` was cleared.
**Output a page cites is now a `snapshot`:** copied through `envscan dehydrate`,
every identifying value a `$KEY` or rewritten, and the copy scanned clean. Output
nothing cites is still `discard`, and data files are still never opened.

ADR 0015 rejected "copy anything that scans clean" because the scanner only knows
the values in `.env`. That still holds, so a scan is not enough here either: the
agent reads the whole file and lists every identifier it finds on the menu, and the
operator approves each one. The judge reads only `md txt py sh sql yml yaml toml`,
so for a `.log` or `.json` file that reading is the only check for values not in
`.env`. Tool output is read, never run, which is why a copy is acceptable for it
and not for prose: prose carries the author's paraphrase of a value, which no scan
can see.

## Opt-in

promote-tmp runs only when the operator invokes it, in a repo with a `.env`. A repo
set up by repo-context-audit alone, and a teammate working in it, see no change: no
hook fires, no step is added to their wrap-up, and repo-context-audit does not
require promotion.

## One wrap-up

promote-tmp's last step invokes repo-context-audit. Promotion keeps the evidence;
the audit decides what the repo should now say about it. Ending one in the other
makes a single command the wrap-up for a session that used `tmp/`. Each keeps its
own menu, so the operator approves twice.

## Considered options

- **Keep output in `tmp/` (ADR 0015).** Rejected: claims lose their proof when
  `tmp/` is cleared.
- **Make the audit invoke promotion instead.** Rejected: the audit runs in every
  repo, including teammates' repos with no `.env`, so promotion would stop being
  opt-in.
- **One combined menu.** Rejected: the menus approve different things, a copy out
  of `tmp/` against a change to current docs, and a merged menu hides which is which.
