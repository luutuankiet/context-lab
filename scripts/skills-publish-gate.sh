#!/usr/bin/env bash
# The publish gate. Four mechanical checks that decide whether this repo may be
# published as a plugin at all. Run it before pushing anything that touches
# skills/ or .claude-plugin/.
#
#   1. No symlink anywhere under skills/. A skill readable through a symlink can
#      be gitignored at the link's *target* and still publish its contents --
#      which is exactly how a private file once escaped a privacy gate. With no
#      symlink possible, resolved path and literal path coincide by construction.
#   2. Every SKILL.md frontmatter `name` equals its directory name. The plugin
#      invokes by frontmatter name; the bucket allowlist selects by directory. A
#      mismatch publishes a skill nobody can call.
#   3. The manifests validate --strict, so a typo fails here and not on a host.
#   4. Every `.sh` under skills/ is 100755 in the index. Mode publishes with the
#      file, and a script committed 100644 is read-only on every host that
#      installs it -- `permission denied` at the call site, with nothing wrong
#      anywhere the other three checks look.
#
# Written for bash 3.2 (m3): no associative arrays, no `${arr[*]}` on a possibly
# empty array under `set -u`.
set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO"
FAILURES=0
bad() { printf '  FAIL  %s\n' "$1"; FAILURES=$((FAILURES + 1)); }
ok()  { printf '  ok    %s\n' "$1"; }

printf '\n==> 1. symlink ban\n'
links=$(find skills -type l 2>/dev/null || true)
if [ -n "$links" ]; then
  printf '%s\n' "$links" | sed 's/^/        /'
  bad "symlinks under skills/ -- the resolved-path rule is broken"
else
  ok "find skills -type l is empty"
fi

printf '\n==> 2. frontmatter name matches directory\n'
mismatch=0
while IFS= read -r skill; do
  dir=$(basename -- "$(dirname -- "$skill")")
  name=$(sed -n '/^---$/,/^---$/p' "$skill" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d '"'"'"' ')
  if [ -z "$name" ]; then bad "$skill has no frontmatter name"; mismatch=1
  elif [ "$name" != "$dir" ]; then bad "$skill declares '$name' but sits in '$dir'"; mismatch=1
  fi
done <<EOF
$(find skills -name SKILL.md 2>/dev/null)
EOF
[ "$mismatch" -eq 0 ] && ok "every SKILL.md name equals its directory"

printf '\n==> 3. manifests validate\n'
if ! command -v claude >/dev/null 2>&1; then
  printf '  warn  claude CLI not on PATH; manifests unvalidated\n'
elif out=$(claude plugin validate . --strict 2>&1); then
  ok "claude plugin validate . --strict"
else
  # One warning is expected and deliberate: plugin.json declares no `version`,
  # which is what makes the plugin version the source commit sha and `git pull`
  # the whole update path (ADR 0006). Every *other* warning is a real failure,
  # so filter that one line rather than dropping --strict and going blind.
  rest=$(printf '%s\n' "$out" | grep '❯' | grep -v 'version: No version specified' || true)
  if [ -z "$rest" ]; then
    ok "claude plugin validate . --strict (versionless by design; see ADR 0006)"
  else
    printf '%s\n' "$rest" | sed 's/^/        /'
    bad "marketplace manifest failed --strict validation"
  fi
fi

printf '\n==> 4. shipped scripts carry the executable bit\n'
# Mode is part of what publishes. A skill script committed 100644 ships
# read-only, and a SKILL.md that invokes it by path gets `permission denied` on
# every host while the gate, the tests and `validate --strict` all stay green.
# Ask the index rather than the working tree: the index is what is pushed.
notexec=$(git ls-files --stage -- 'skills/*.sh' | grep -v '^100755' | sed 's/.*\t//' || true)
if [ -n "$notexec" ]; then
  printf '%s\n' "$notexec" | sed 's/^/        /'
  bad "shell scripts under skills/ committed without the executable bit"
else
  ok "every .sh under skills/ is 100755 in the index"
fi

printf '\n'
if [ "$FAILURES" -gt 0 ]; then
  printf 'publish gate: %d failure(s)\n' "$FAILURES"
  exit 1
fi
printf 'publish gate: clean\n'
