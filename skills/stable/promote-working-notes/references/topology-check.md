# Topology check — pattern classes and vocabulary

Read this when running Gate 2, or when adjusting what the check looks for.

## Why the patterns are split in two

The check looks for two different things, and only one of them can live in a public repo.

**Generic classes** are shape-recognisable — a private IP range looks like a private IP range regardless of whose it is. They are hardcoded in `scripts/topology-check.sh`.

**Identity terms** — your host nicknames, your internal DNS suffix, your clients' names — are the leak *itself*. A public file listing the nicknames to grep for has disclosed the topology it was written to protect. So they are never hardcoded; they come from a vocabulary file supplied at run time.

## The generic classes

| Class | What it catches |
|---|---|
| Private IPv4 ranges | `10.x`, `172.16–31.x`, `192.168.x` |
| CGNAT / overlay-network ranges | `100.64.0.0/10`, which mesh VPNs allocate from |
| Absolute home paths | `/home/<user>/…`, `/Users/<user>/…` — should be `~/` |
| Credential prefixes | Vendor-issued token prefixes, session-cookie names |
| Bearer / auth headers | `Authorization:` lines carrying anything but a placeholder |
| SSH / connection strings | `user@host` forms, `ssh -i`, explicit ports on named hosts |
| Internal URLs | Non-public schemes and hostnames without a dot, or with a non-public TLD |

These fire on shape alone. Expect false positives — that is fine, the check reports rather than refuses.

## The identity vocabulary file

One extended regex per line; `#` comments and blank lines ignored.

```
# ~/.config/topology-vocab.txt  — never committed to a public repo
\b(nickname-one|nickname-two)\b
\.internal-suffix\b
\b(client-name|product-codename)\b
```

Resolution order, first hit wins:

1. `$TOPOLOGY_VOCAB` if set
2. `~/.config/topology-vocab.txt`
3. A path passed as `--vocab <file>`

If no vocabulary is found, the script runs the generic classes and prints a **loud warning** that the identity half did not run. It does not fail — a partial check reported honestly beats a skipped check reported as clean.

Keep the file wherever private material already lives for you. It is a short list, it changes rarely, and it is the one artifact of this skill that must not be published.

## Substitution vocabulary

When the human decides a hit should change, these are the replacements — established once so that separately-scrubbed documents still cohere as one voice:

- **Host nickname → a capability description.** "the box with the GPU", "the always-on host". Never a replacement name: a fake hostname is still a topology claim, and it invites a reader to build a mental map of infrastructure that does not exist.
- **Internal DNS suffix → `example.com`.** Reserved for documentation precisely for this.
- **Absolute home paths → `~/`.** All layouts, one form.
- **Client and customer identifiers → the `acme` vocabulary** — `acme`, its orders and customers. Reuse it rather than inventing a fresh alias per document.
- **Worked examples keep their shape and magnitude.** Row counts, byte sizes, timings, ratios stay real. A scrub that collapses every number to `N` destroys the pedagogy the example existed for — and magnitudes are not topology.

## What the check is not

It is **not** a secret scanner over source material. Pointed at a raw working-notes directory it runs at roughly 1% signal and buries its two real hits under a hundred and forty-nine placeholders and vendored strings.

It runs over **newly-authored prose only** — small, and with a finite, known leak vocabulary. That inversion is the whole reason it earns its place.
