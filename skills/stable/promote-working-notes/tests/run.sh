#!/usr/bin/env bash
# Regression test for scripts/topology-check.sh.
#
# The numbers below — 7 / 9 / 0 — were a claim in the build this script was
# ported from, with no fixtures behind them. They are a test now.
#
#   ./tests/run.sh

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../scripts/topology-check.sh"
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
echo "======== $pass passed, $fail failed"
[[ $fail -eq 0 ]]
