#!/usr/bin/env bash
#
# Derive this host's identity vocabulary for topology-check.sh. Run once per
# host, and again when the fleet changes.
#
#   derive-topology-vocab.sh [--out FILE]      default: ~/.config/topology-vocab.txt
#   derive-topology-vocab.sh --print           to stdout, write nothing
#
# WHY THIS IS NOT A COMMITTED LIST
#
# A committed list of your host nicknames, in a public repo, leaks precisely what
# the check exists to catch. So the identity half is derived on the host, at run
# time, from sources that are already local and already uncommitted -- which also
# makes the check portable to any fleet rather than correct for one.
#
# The derived list is itself the topology. It goes to $HOME/.config, which is
# outside every working tree, and it is never pasted into a commit message, a
# pull request body or an issue comment.
#
# THE FILTER IS NOT OPTIONAL
#
# Unfiltered on the fleet this was built for, the nickname list came back holding
# aliases that are also ordinary English words. Scanning for one three-letter
# alias flagged 24 lines across three pages -- every one of them that word in a
# sentence, and zero real hits. A check that cries wolf 24 times gets switched
# off, and then the two real hits are never seen either. Filtered, the same run
# returns zero. Hence: drop anything under five characters, drop anything in the
# system wordlist, and split domains into their own class.
#
# Two limits, stated because a silent filter is worse than a noisy check:
#
#   - Short nicknames are missed. The length floor drops any alias of four
#     characters or fewer, and real ones exist. Add those by hand, once, after
#     you have read the derived list.
#   - The wordlist may be absent. A Mac and a minimal container typically ship no
#     /usr/share/dict/words. The guard below falls back to length-only filtering
#     rather than letting `rg -f` fail and hand back an EMPTY nickname list --
#     which would report a confident all-clear having scanned for nothing.

set -euo pipefail

OUT="$HOME/.config/topology-vocab.txt"
PRINT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --out)   OUT="$2"; shift 2 ;;
    --print) PRINT=1; shift ;;
    *)       echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v rg >/dev/null 2>&1 || {
  echo "rg is required: grep in an agent sandbox is commonly shimmed to a" >&2
  echo "BRE-mode tool that silently returns zero matches on patterns it" >&2
  echo "cannot parse, which would produce an empty vocabulary." >&2
  exit 2
}

derive() {
  # host nicknames -- this host, plus every host the operator has named locally
  { hostname -s
    rg '^Host\s+' "$HOME/.ssh/config" 2>/dev/null | tr ' ' '\n' | rg -v '^(Host)?$|\*'
    command -v tailscale >/dev/null && tailscale status 2>/dev/null | awk 'NF>1{print $2}'
  } 2>/dev/null | sort -u | rg -v '\.' | awk 'length($0) >= 5' \
    | { WORDS=""
        for w in /usr/share/dict/words /usr/share/dict/american-english; do
          [ -f "$w" ] && { WORDS=$w; break; }
        done
        if [ -n "$WORDS" ]; then rg -vx -f "$WORDS"; else cat; fi; }

  # domains -- derived separately, because a public domain is not topology
  hostname -d 2>/dev/null || true
  rg '^search\s' /etc/resolv.conf 2>/dev/null | tr ' ' '\n' | rg '\.' || true
  command -v tailscale >/dev/null && tailscale status --json 2>/dev/null \
    | jq -r '.MagicDNSSuffix // empty' 2>/dev/null || true

  # home layout
  echo "$HOME"
}

if [ "$PRINT" = 1 ]; then
  derive | sort -u
  exit 0
fi

umask 077                       # the topology is not world-readable
mkdir -p -- "$(dirname -- "$OUT")"
derive | sort -u > "$OUT"

n=$(rg -cv '^\s*(#|$)' "$OUT" 2>/dev/null || echo 0)
printf 'wrote %s -- %s pattern(s)\n' "$OUT" "$n"
printf '\nRead it before trusting it. Two things need a human:\n'
printf '  - add any nickname of four characters or fewer, by hand, once.\n'
printf '  - a client or engagement identifier beyond the domain has no local\n'
printf '    source. Ask for it once rather than guessing; guessing produces both\n'
printf '    false positives and false confidence.\n'
printf '\nThen triage what is in the file by class, not by pattern:\n'
printf '  a fleet host nickname      topology            substitute\n'
printf '  an employer/client domain  engagement identity substitute -- the sharpest one\n'
printf '  a mesh VPN DNS suffix      topology            substitute\n'
printf '  github.com, a registry     public              leave it alone\n'
