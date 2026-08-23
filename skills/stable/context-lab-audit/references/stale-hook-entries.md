# The one class of drift no re-run repairs

Load this when the scanner printed an `[approve]` line. It is the only finding
that ends in you editing a file.

## Why running something cannot fix it

`install.sh` applies its manifest with a deep merge. A merge **adds** a key and
**changes** a key. It has no way to say *this should no longer be here*. So an
entry that has been retired from the manifest keeps living in
`~/.claude/settings.json` on every host that ever had it, and running the
installer a hundred more times changes nothing.

That is harmless while nothing else claims the same work. It stops being
harmless the moment the plugin declares the same command in its own hook
manifest, because then **both fire**. One event, two invocations, no error, no
warning, and nothing on screen that says so. A token counter that counts twice
is not obviously broken — it is just wrong.

## How the scanner decides

It compares by **signature**, not by string: every whitespace-separated token in
the command is reduced to its last path component. `bash
~/.claude/hooks/x.sh UserPromptSubmit` and `bash
${CLAUDE_PLUGIN_ROOT}/hooks/x.sh UserPromptSubmit` both reduce to `bash x.sh
UserPromptSubmit`, and match. A literal comparison would never find the pair
this check exists to find, because the two sides are spelled differently by
construction.

Only a **duplicate** is flagged. A settings hook entry that no plugin declares
is somebody else's — another tool's, or hand-written — and is left alone.

## What to say before applying it

Show the diff the scanner printed, then this, in your own words but with none of
it dropped:

- **what stops:** the named entries stop firing from `settings.json`
- **what does not stop:** the plugin still declares them, so each command still
  runs — once per event instead of twice
- **what else moves:** nothing. The edit is a `delpaths`, plus the removal of any
  hook group left holding an empty list
- **what happens if you decline:** the double-fire continues; it is silent, and
  the next audit will report it again

Then ask. **One approval covers the edit you just showed**, on this host, in
this turn. Not a standing one — a blanket yes hands the next session a blessing
whose contents nobody has seen.

## Applying it

Run the command the scanner printed. It writes to a temporary file and `mv`s it
into place, so an interruption cannot leave a half-written `settings.json`
behind — which is how a host loses every preference at once.

Afterwards, re-run the scanner. A clean second run is the proof; your own
recollection of what you just typed is not.
