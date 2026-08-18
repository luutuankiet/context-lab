#!/usr/bin/env bash
# Regression tests for both scripts this skill ships that have behaviour worth
# pinning: scripts/topology-check.sh and scripts/audit.sh.
#
# The topology numbers below — 7 / 9 / 0 — were a claim in the build that script
# was ported from, with no fixtures behind them. They are a test now.
#
# The audit fixtures pin the ordered state gate and the two orthogonal flags. The
# `verified:` dates in them are fixed at 2020-01-01 and the threshold is passed
# per fixture, so no assertion here rots as the calendar moves.
#
#   ./tests/run.sh

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../scripts/topology-check.sh"
AUDIT="$HERE/../scripts/audit.sh"
FIX="$HERE/fixtures"

pass=0
fail=0

ok() {
  printf 'PASS  %s\n' "$1"
  pass=$((pass + 1))
}
no() {
  printf 'FAIL  %s\n' "$1"
  fail=$((fail + 1))
}

# Count the hits the check reports. "no hits." is zero.
hits_in() {
  local out="$1"
  if [[ $out == *"no hits."* ]]; then
    echo 0
  else
    sed -n 's/^\([0-9]\{1,\}\) hit(s).*/\1/p' <<<"$out" | tail -1
  fi
}

echo "======== the three fixtures"

out=$(TOPOLOGY_VOCAB=/nonexistent "$CHECK" "$FIX/dirty.md")
n=$(hits_in "$out")
[[ $n == 7 ]] && ok "dirty, generic classes only: 7 hits" || no "dirty: expected 7, got ${n:-none}"

out=$("$CHECK" --vocab "$FIX/vocab.txt" "$FIX/dirty-with-vocabulary.md")
n=$(hits_in "$out")
[[ $n == 9 ]] && ok "dirty with vocabulary: 9 hits" || no "dirty-with-vocabulary: expected 9, got ${n:-none}"

out=$("$CHECK" --vocab "$FIX/vocab.txt" "$FIX/clean.md")
n=$(hits_in "$out")
[[ $n == 0 ]] && ok "clean: 0 hits" || no "clean: expected 0, got ${n:-none}"

echo
echo "======== a missing vocabulary is loud, not clean"

out=$(TOPOLOGY_VOCAB=/nonexistent "$CHECK" "$FIX/dirty-with-vocabulary.md")
[[ $out == *"NO IDENTITY VOCABULARY FOUND"* ]] \
  && ok "missing vocabulary warns" || no "missing vocabulary did not warn"
n=$(hits_in "$out")
[[ $n == 7 ]] \
  && ok "and the two identity lines go unseen (7, not 9)" || no "expected 7 without vocabulary, got ${n:-none}"

echo
echo "======== an empty vocabulary is NOT RUN, not a pass"

empty="${TMPDIR:-/tmp}/topology-vocab-empty.$$"
printf '# only a comment\n\n' >"$empty"
out=$("$CHECK" --vocab "$empty" "$FIX/dirty-with-vocabulary.md")
rm -f "$empty"
[[ $out == *"IDENTITY VOCABULARY IS EMPTY"* ]] \
  && ok "empty vocabulary is reported as not run" || no "empty vocabulary was reported as clean"

echo
echo "======== resolution order: --vocab beats \$TOPOLOGY_VOCAB"

out=$(TOPOLOGY_VOCAB=/nonexistent "$CHECK" --vocab "$FIX/vocab.txt" "$FIX/dirty-with-vocabulary.md")
n=$(hits_in "$out")
[[ $n == 9 ]] && ok "--vocab wins over the environment" || no "--vocab did not win, got ${n:-none}"

echo
echo "======== it reports, it never refuses"

TOPOLOGY_VOCAB=/nonexistent "$CHECK" "$FIX/dirty.md" >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "exit 0 even with hits" || no "non-zero exit on hits — this check must not block"

echo
echo "======== audit.sh: the ordered state gate"

# summary <fixture> <stale-days> -- the one-line summary the scanner ends on.
summary() {
  "$AUDIT" --repo "$FIX/$1" --stale-days "$2" | grep -E '^(cold|structured|wired) '
}

out=$(summary cold 100000)
[[ $out == cold* ]] \
  && ok "no contract file -> cold" || no "cold fixture reported: $out"

out=$(summary structured 100000)
[[ $out == structured* ]] \
  && ok "contract + collections, no emitted skills -> structured" || no "structured fixture reported: $out"
[[ $out == *"2 missing emitted skills"* ]] \
  && ok "and it names both missing skills" || no "structured fixture did not name the missing skills"

out=$(summary wired 100000)
[[ $out == wired* ]] \
  && ok "all five checks pass -> wired" || no "wired fixture reported: $out"
[[ $out == *"no drift"* ]] \
  && ok "and it is clean" || no "wired fixture reported drift: $out"

echo
echo "======== audit.sh: the two flags never change the state"

out=$(summary drifted 1)
[[ $out == wired* ]] \
  && ok "an orphan page and stale dates leave the state wired" || no "drifted fixture reported: $out"
[[ $out == *"1 orphan page"* && $out == *"stale page"* ]] \
  && ok "and both drift causes are named" || no "drifted fixture summary was: $out"

out=$("$AUDIT" --repo "$FIX/drifted" --stale-days 1)
[[ $out == *"route:  references/route-repair.md"* ]] \
  && ok "drift on a wired repo routes to repair" || no "drifted fixture did not route to repair"

out=$("$AUDIT" --repo "$FIX/structured" --stale-days 100000)
[[ $out == *"route:  references/route-author-skills.md"* ]] \
  && ok "missing skills route to authoring" || no "structured fixture did not route to authoring"

echo
echo "======== audit.sh: it reports, it never fails"

for f in cold structured wired drifted; do
  "$AUDIT" --repo "$FIX/$f" --stale-days 1 >/dev/null 2>&1 \
    && ok "exit 0 on the $f fixture" || no "non-zero exit on $f — the scanner must not block"
done

echo
echo "======== audit.sh: the drifted collection's frontmatter is printed"

out=$("$AUDIT" --repo "$FIX/drifted" --stale-days 1)
[[ $out == *"title, summary, verified"* ]] \
  && ok "the guide schema is printed for the orphan page" \
  || no "no frontmatter schema printed for the drifted collection"

echo
echo "======== gen-docs-index.sh: every fixture index is current"

for f in structured wired drifted; do
  "$HERE/../scripts/gen-docs-index.sh" --check --repo "$FIX/$f" >/dev/null 2>&1 \
    && ok "$f index is current" || no "$f index is stale — regenerate the fixture"
done

echo
echo "======== $pass passed, $fail failed"
[[ $fail -eq 0 ]]
