---
symptom: "the agent ignores fleet-wide rules on one host and nothing anywhere reports a problem"
area: user-tier installer
verified: 2026-08-18
---

# An `@`-import that resolves to nothing is completely silent

## Symptom

One host stops behaving like the others. It reaches for the wrong tools, ignores
conventions every other host follows, writes attribution footers you have banned.
Sessions start normally. `claude` exits 0. Nothing is logged, and
`~/.claude/CLAUDE.md` looks correct when you open it — the import line is right
there.

## Mechanism

`~/.claude/CLAUDE.md` does not contain user memory. It contains a line that
*points* at it:

```
@~/.claude/plugins/marketplaces/context-lab/claude/CLAUDE.md
```

A missing import target is a **no-op, not an error**: no message, no warning, zero
exit, and every sibling import still loads. So a host with the line present and the
target absent is indistinguishable, from the outside, from a host that is fine.

That is deliberate — it is what lets a public-only host skip the private tier's
line cleanly. The cost is that the same silence covers a real failure.

The target goes missing because `claude plugin marketplace update` does **not**
pull. It prints `Found stale directory, cleaning up and re-cloning` and replaces
the directory wholesale. If the re-clone then fails — no network, no git auth, a
renamed repo, a full disk — the delete has already happened. The line now points at
nothing, and the next session loses every rule the payload carried.

The path itself is stable across a successful update; only the inode changes. An
`@`-import resolves by path and survives that. It is the failed update, not the
successful one, that breaks it.

## Fix

Re-fetch the marketplace:

```sh
claude plugin marketplace update context-lab
```

## How to verify

Do not check that the import line exists — that is the assertion that passes in
both the working and the broken state, exactly as with a symlink replaced by a real
file. Check that the **target** exists:

```sh
awk '/^@/ {
  p = substr($0, 2)
  if (p ~ /^~\//)      sub(/^~/, ENVIRON["HOME"], p)
  else if (p !~ /^\//) p = ENVIRON["HOME"] "/.claude/" p
  print p
}' "$HOME/.claude/CLAUDE.md" | while read -r t; do
  printf '%-8s %s\n' "$([ -e "$t" ] && echo ok || echo MISSING)" "$t"
done
```

The two branches matter. A bare `@RTK.md` resolves against the *containing file's*
directory, not the working directory, so testing it as written reports MISSING on a
host where it is fine — a false alarm on the one page whose whole subject is a
check that lies.

`install.sh --check` does this for the line it owns and prints
`warn import target is missing`. It warns rather than fails because a dev-clone
install and a sandboxed test both legitimately lack the directory — so a warning
here is worth reading, not scrolling past.

The end-to-end check is a fresh session answering a question only the payload can
answer:

```sh
claude -p 'name the one rule in your memory about attribution footers'
```

## The general rule

**Silence as a feature and silence as a failure are the same silence.** Any
mechanism that degrades quietly on purpose needs a separate, explicit check that
the thing it degrades to was actually intended — because nothing downstream will
ever raise its hand.
