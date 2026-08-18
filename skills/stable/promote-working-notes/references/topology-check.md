# Topology check — Gate 2

A non-blocking pattern scan over **newly-authored prose only**. Not over the source notes, not over vendored files, not over the repo at large.

```bash
"$CLAUDE_PLUGIN_ROOT"/skills/stable/promote-working-notes/scripts/topology-check.sh <new-file>...
```

The script ships the generic classes, which are public constants. It never ships
the identity half — that is derived below and handed to it as a **vocabulary
file**. Its regression tests live in `tests/`: `./tests/run.sh`.

That scoping is what makes it work. Over the source set the same scan was **1.32% signal** — 151 hits, 2 real. Over authored prose it earns its keep, because the prose is small and the leak vocabulary is finite and known.

## The pattern list is never committed

**A committed list of your host nicknames, in a public repo, leaks precisely what the check exists to catch.** So the list is not data this skill ships — it is derived on the host, at run time, from sources that are already local and already uncommitted. That also makes the check portable to any fleet rather than correct for one.

**The derived list is itself sensitive — it is the topology.** Keep it in shell variables or a file outside the repo. Never write it into the working tree, not even to a scratch path, and never paste it into a commit message, PR body, or issue comment. On a real fleet this derivation returns the employer's domain from `~/.ssh/config` on its first line; a public PR body is a leak surface too.

### The vocabulary file is the interface

The script resolves the vocabulary in this order, first hit wins:

1. `--vocab <file>`
2. `$TOPOLOGY_VOCAB`
3. `~/.config/topology-vocab.txt`

One extended-regex pattern per line, `#` comments allowed. Bare tokens are valid
EREs, so a plain nickname composes directly and the derivation below can write
straight into the file.

`$HOME/.config/` is deliberate: it is **outside the working tree**, which is the
one place this skill's own rule forbids the derived list from ever landing.

Two failure modes the script treats as *not run* rather than as clean, and any
rewrite must keep both:

- **No vocabulary file** — the generic classes run, the identity half does not,
  and it says so loudly.
- **An empty or comment-only vocabulary** — it scanned for nothing. Reporting
  "no hits" here would be a confident all-clear having checked nothing at all.

Derive it once per host, straight into that file:

```bash
umask 077                       # the topology is not world-readable
mkdir -p ~/.config
{
# host nicknames — this host, plus every host the operator has named locally.
# The filter is not optional: see below.
{ hostname -s
  rg '^Host\s+' ~/.ssh/config 2>/dev/null | tr ' ' '\n' | rg -v '^(Host)?$|\*'
  command -v tailscale >/dev/null && tailscale status 2>/dev/null | awk 'NF>1{print $2}'
} | sort -u | rg -v '\.' | awk 'length($0) >= 5' \
  | { WORDS=""
      for w in /usr/share/dict/words /usr/share/dict/american-english; do
        [ -f "$w" ] && { WORDS=$w; break; }
      done
      if [ -n "$WORDS" ]; then rg -vx -f "$WORDS"; else cat; fi; }

# domains: derived separately, because a public one is not topology
hostname -d
rg '^search\s' /etc/resolv.conf 2>/dev/null | tr ' ' '\n' | rg '\.'
command -v tailscale >/dev/null && tailscale status --json 2>/dev/null | jq -r '.MagicDNSSuffix // empty'

# home layout
echo "$HOME"
} | sort -u > ~/.config/topology-vocab.txt
```

Re-run it when the fleet changes. Nothing consumes it but the script, and the
script re-reads it on every run.

### Why the filter is not optional

Run unfiltered on the fleet this was built for, the nickname list came back holding aliases that are also ordinary English words. Scanning for one three-letter alias flagged **24 lines across three pages**, every one of them that word in a sentence, and zero real hits. A check that cries wolf 24 times gets switched off, and then the two real hits never get seen either. Hence: drop anything under five characters, drop anything in the system wordlist, and split domains into their own class. Filtered, the same run returns **zero** hits on the same three pages.

Two limits of that filter, stated because a silent filter is worse than a noisy check:

- **Short nicknames are missed.** The length floor drops any alias of four characters or fewer — and real ones exist. Add those by hand, once, from the derived list, after you have looked at it.
- **The wordlist may be absent.** Not every host ships `/usr/share/dict/words`; a Mac and a minimal container typically do not. The guard above falls back to length-only filtering rather than letting `rg -f` fail and hand back an **empty** nickname list — which would report a confident all-clear having scanned for nothing. If you rewrite this pipeline, keep that property: an empty pattern list must be an error, never a pass.

Then triage what survives by class, not by pattern:

| derived value | class |
|---|---|
| a fleet host nickname | **topology** — substitute |
| an employer or client domain | **engagement identity** — substitute, and it is the sharpest thing on the list |
| a mesh VPN DNS suffix | **topology** — substitute |
| `github.com`, `gitlab.com`, a package registry | **public** — leave it alone |

Anything the derivation cannot reach, **ask for once** rather than guessing — client and engagement identifiers beyond the domain have no local source, and guessing produces both false positives and false confidence.

These classes are public constants and can be matched directly:

| class | pattern |
|---|---|
| private IPv4 | `10\.`, `172\.(1[6-9]\|2[0-9]\|3[01])\.`, `192\.168\.` |
| CGNAT (mesh VPN) | `100\.(6[4-9]\|[7-9][0-9]\|1[01][0-9]\|12[0-7])\.` |
| link-local | `169\.254\.` |
| home layouts | `/home/[a-z]`, `/Users/[A-Za-z]`, `/root/` |
| credential shapes | `github_pat_`, `ghp_`, `AKIA`, `xoxb-`, `sk-[A-Za-z0-9]{20,}`, `-----BEGIN [A-Z ]*PRIVATE KEY-----` |
| session cookies | `user_session=`, `_gh_sess=`, `_octo=`, `sessionid=` |
| auth headers | `Authorization:` or `Bearer` followed by 16+ token characters |
| ssh / connection strings | `ssh user@host`, `user@host:port` |
| internal URLs | a scheme-qualified host ending `.local`, `.lan`, `.internal`, `.home`, `.corp`, `.intranet`, or a bare unqualified host |

A public URL is **not** an internal URL: `https://github.com/owner/repo` does not
match, because the host carries a public suffix. `https://buildbox.internal/status`
and `https://localhost:8080/` do.

## Substitutions

| found | becomes | why |
|---|---|---|
| a host nickname | a **capability description** — "the host without `bc`", "the ARM box", "the employer laptop" | **never a replacement name.** A fake hostname is still a topology claim: it asserts that a host exists, and it reads as real. |
| the DNS suffix or a mesh address | `example.com` | |
| an absolute home path | `~/` | one form for all three layouts |
| a client or engagement identifier | the neutral `acme` vocabulary — `acme`, orders, customers | keeps the domain shape without naming the engagement |
| a worked example's numbers | **left alone** | a scrub that collapses every number to `N` destroys the pedagogy the example existed for. Keep shape and magnitude. |
| a credential value | nothing — it is not substituted, it is removed, and the human is told to rotate it | |

Identifiers that are **not** leaks and stay as written: git SHAs, CI run IDs, cloud job IDs, `file:line` citations, public URLs, package and model names. Those are reproducible references, and the format asks for them.

## Expected false positives

Report them, do not silently drop them — but recognise them, because they were 72% of the noise in the measured run:

- **Elided placeholders inside prose** (38%) — `Bearer <PAT>`, `--token=<redacted>`. Already correct.
- **Vendored library strings** (34%) — a locale code that matches a key pattern, an `AKIA` occurring inside a base64-encoded test font. Should not appear at all if the scan is correctly scoped to authored prose; if they do, the scope is wrong, so fix the scope rather than adding an exclusion.

## Reporting

Output one line per hit — `path:line`, the class, the proposed substitution — then hand it to the human. **Do not edit and do not refuse.** Naming a host as inline evidence is a style call, and this format asks for inline evidence everywhere else; a check that refuses would be arguing with the format it serves.
