---
symptom: "install.sh prints `ok <plugin> installed`, the session has none of that plugin's skills, and `claude plugin list` does not show it"
area: user-tier installer
verified: 2026-08-18
---

# The installer reports a plugin it never installed

## Symptom

`./install.sh` prints

```
ok    context-lab@context-lab installed
```

`./install.sh --check` exits 0. A fresh session has none of the plugin's skills,
and `claude plugin list` does not list it. Nothing has failed anywhere, so there is
nothing to search for.

## Mechanism

Both plugin guards matched a **substring**, and one plugin's name is a prefix of
another's.

```sh
claude plugin marketplace list | grep -q "$marketplace"   # WRONG
printf '%s' "$installed"      | grep -q "$plugin"         # WRONG
```

With `context-lab-private` installed, `grep -q "context-lab"` succeeds on both.
`add_marketplace` concludes the marketplace is already configured and returns
early; `install_one_plugin` concludes the plugin is already installed and takes
the "already there, just refresh" path. Every branch reports success. Measured on
thinkpad 2026-08-18: `context-lab` had never been added on any host, across
repeated installs, and no run ever said so.

The pair is what makes it invisible. A wrong "already installed" alone would be
caught by the next session having no skills; a wrong "already configured" alone
would fail at install time. Together they produce a clean run and an empty result.

## Fix

Reduce each line of the pretty listing to its last field and match that exactly:

```sh
claude plugin marketplace list 2>/dev/null | awk '{print $NF}' | grep -qx "$marketplace"
printf '%s\n' "$installed"                 | awk '{print $NF}' | grep -qx "$id"
```

A name line's last field is the bare name (or `plugin@marketplace`); no other line
in either listing can collide with one. Deliberately not `--json`, which the oldest
CLI in the fleet predates, and deliberately not a match on the `❯` glyph, which is
presentation and can change.

Note the second guard must match `$id`, not `$plugin` — `claude plugin list` prints
the full `plugin@marketplace` id.

## How to verify

```sh
./install.sh --dry-run | sed -n '/marketplace plugins/,/^==>/p'
```

A plugin that is genuinely absent must print `would claude plugin marketplace add …`
or `would claude plugin install …`. If it prints `ok … installed` while
`claude plugin list` disagrees, the guard is matching something else.

## The general rule

**A guard that reports "already done" must match exactly, because its failure mode
is silence.** An unanchored `grep` inside a check is a bug the moment two names in
the namespace share a prefix — and a personal namespace is exactly where
`foo` and `foo-private` both exist.
