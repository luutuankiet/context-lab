# The env file: what goes where

A repo keeps its identifying values in a local, gitignored `.env`, and commits
`.env.example` with the same keys and empty values. Committed text then uses key
names, and the real values never leave the machine.

## What goes where

**If it is in `.env`, it is blocked.** An outbound gate treats every value as text
that must not leave, without knowing what the value means.

| item | where it goes |
|---|---|
| a stable identifying value: client, repo, host, URL | `.env`, one value per key |
| a harmless setting | somewhere else, because `.env` would block it |
| an API key or password | the operator's shell profile or secret store, because a credential is not an identifier |
| a value that needs judgement, or is too short or too common to match safely | not `.env` as a rule; reword it where it appears, and review it in the menu |
| what a key means | `.env.example` only |

A machine name is the one deliberate exception for common words: it stays in `.env`
when a script needs it, and the repo's text names that machine by its role instead.

## One value per key

The gate matches a value as a whole string, so `HOSTS="one two"` does not block
`one` alone. Give a URL two keys when both forms matter: the full URL and its host.

Notes go on their own line. In `KEY=value # note` the note can become part of the
value, and the bare value then passes the gate.

## Naming a key

**A key must not identify anything sensitive.** That is the only rule. The gate cannot
catch `CLIENT_ACME=`, so the name has to be safe in itself, because `.env.example` is
committed.

The default suggestion is a role and a letter, such as `CLIENT_A`, `REPO_B` or a
numbered `DEPLOY_HOST_1`, with letters not reused. Agents decide on the spot, and
suggest a rename when a key gives something away. Rename early: committed evidence
is frozen, so a key cited there can no longer change.

## Explaining a key

Each key, or block of keys, has one line above it in `.env.example`:

```
# what: short name of the client behind the oldest engagement | group: clients
CLIENT_A=
```

`what` is the question asked during a rebuild, so it must let the operator recognise
the value without naming it. `git log` holds who added a key, when and why.

## Rebuilding on a new machine

Copy `.env.example` to `.env`, then ask for one value per key using its `what` line.
Until every key has a value or has been removed from the example, the gate treats
protection as incomplete and blocks posting.

## Reading and writing

- Read line by line, and read only the keys a script names. Never `source` the file:
  URLs carry `&` and `#`.
- A script that creates a new ID writes the value to `.env`, and the key with a safe
  `what` line to `.env.example`, in the same step.

## Retiring a value

Comment the line out in `.env` when the value stops being useful, and remove its key
from `.env.example` in the same commit.

**A commented-out value is no longer blocked.** Before committing, the agent knows the
repo's context and judges whether a retired value is back in use, and suggests adding
it again if so. The scanner warns, without blocking, when a commented-out value
appears in outgoing text. That warning cannot fire on a machine rebuilt after the key
was removed, because that machine never had the value.

## Checking the file

Where the scanner provides an env check, it reports and suggests but never rewrites
`.env`, because renaming a key also means changing the text that uses it. It flags:

- notes on the same line as a value
- keys holding several values
- keys containing their own value
- values too short to match
- values with many hits in tracked files
- keys present in only one of the two files
- keys with no `what` line
