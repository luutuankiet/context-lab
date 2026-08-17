---
symptom: "a hook that another tool installed stopped firing after I ran install.sh, and settings.json looks fine"
area: user-tier installer
verified: 2026-08-17
---

# A merge that adds one hook erases another

## Symptom

Something that used to intercept tool calls stops. `settings.json` still parses,
still has a `hooks` key, still has the entries this repo owns. The entry that
vanished belonged to a different tool, so nobody looks for it.

Concretely: `rtk init -g` owns `hooks.PreToolUse`. Naming `PreToolUse` in
`claude/settings.owned.json` erases rtk's entry on **every single install, on every
host**, and nothing reports an error.

## Mechanism

The settings merge is:

```sh
jq -s '.[0] * .[1]' ~/.claude/settings.json claude/settings.owned.json
```

`jq`'s `*` operator merges **objects** key-wise and recursively — but it **replaces
arrays wholesale**. It does not append to them.

`hooks` is an object, so merging `hooks` is safe: keys this repo does not name are
left alone. But each hook event's value is an *array*. The moment the manifest
names `hooks.PreToolUse`, that array is replaced rather than extended, and whatever
another tool put there is gone.

This is why `claude/settings.owned.json` names only `UserPromptSubmit` and
`PostToolUse`, and why the list of owned hook events is a deliberate decision
rather than an accident of what happened to be needed.

## Fix

Do not name a hook event in the manifest unless this repo owns every entry in it.
If a third event ever has to be shared, the merge has to grow a real
append-and-dedupe step — a `*` merge cannot express it.

## How to verify

`install.sh` carries a canary that makes this loud instead of silent. It
snapshots the state *before* the write:

```sh
had_pretooluse=$(jq -r 'if (.hooks.PreToolUse // null) == null then "no" else "yes" end' "$live")
```

…and after the merge, if there was one before, asserts there is one after —
failing the run with `hooks.PreToolUse is gone -- the merge ate rtk's hook` if not.
The snapshot is what makes the check mean "did the merge destroy it" rather than
"does it exist": on a host where rtk has not been initialised yet there is nothing
to preserve and nothing to complain about.

By hand:

```sh
jq '.hooks | keys' ~/.claude/settings.json
jq 'keys' claude/settings.owned.json | grep hooks
```

## The general rule

**A key-level merge is only safe at the level where the values are objects.** The
first array in the path is where the merge stops being additive — and where
somebody else's configuration starts getting deleted quietly.
