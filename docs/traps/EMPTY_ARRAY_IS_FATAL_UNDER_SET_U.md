---
symptom: "a shell script in this repo aborts with unbound variable on one machine only, and runs fine everywhere else"
area: shell scripts
verified: 2026-08-17
---

# An empty array expansion is fatal on bash 3.2

## Symptom

`install.sh`, `test-install.sh` or any other script here dies with

```
line NNN: missing[*]: unbound variable
```

on exactly one machine, and runs cleanly on every other host in the fleet. The line
it names looks obviously safe.

## Mechanism

Two things combine.

1. Every script here runs under `set -euo pipefail`. `-u` makes any expansion of an
   unset variable a fatal error.
2. **Before bash 4.4, an array with no elements is an *unset* variable**, not an
   empty one. So `"${arr[*]}"` and `"${arr[@]}"` on an empty array abort the script
   instead of expanding to nothing. 4.4 changed this; everything older did not.

The fleet is mixed. Most hosts run bash 5.x, where the same line is harmless. One
runs 3.2.57 — the last GPLv2 release, which is why Apple still ships it, and the
only `bash` on that machine, so `#!/usr/bin/env bash` finds it. That is why this can
only ever fire in one place, and why it survives every local test.

`${#arr[@]}` is safe in every version, including 3.2 — the length of an unset array
is 0 rather than an error. That asymmetry is what makes the guard below work.

## Fix

Guard on the count before expanding. `${#arr[@]}` is safe on an empty array in 3.2;
`"${arr[*]}"` is not.

`install.sh` does this today in step 6 — the `missing` array is only expanded after
an early return:

```sh
if [ ${#missing[@]} -eq 0 ]; then
  ...
  return 0
fi
# every "${missing[*]}" below this line is unreachable when the array is empty
```

The alternative, where an early return does not fit, is `${arr[@]+"${arr[@]}"}` —
correct but unreadable, so prefer the guard.

## How to verify

Find every expansion and confirm each is either guarded or provably non-empty:

```sh
rg -n '\$\{[A-Za-z_][A-Za-z0-9_]*\[[*@]\]\}' install.sh test-install.sh
```

There is no way to test this on a Linux host. The only real check is running the
script on the 3.2 machine, or reading each hit and reasoning about it.

## The general rule

**A version skew that only one host has is a landmine, not a bug** — it does not
fire when you write the code, it fires when someone else runs it. The mitigation is
to write to the oldest interpreter in the fleet, not to the one under your fingers.
