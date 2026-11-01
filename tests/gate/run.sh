#!/usr/bin/env bash
#
# The outbound gate shim, claude/hooks/outbound-gate.sh, fed real PreToolUse
# hook JSON from a main checkout and from a linked worktree of a throwaway repo.
#
# The shim decides three things itself: whether the repo is opted in, where
# envscan is, and what to do when it is missing. Everything else is the
# binary's judgement, so the cases that need it run the real envscan. Point
# ENVSCAN at a build, or put one on PATH; without one those cases are skipped
# and counted, never passed.
#
# Every value here is invented. Nothing touches the real HOME.

set -uo pipefail

REPO=$(cd -- "$(dirname -- "$0")/../.." && pwd)
SHIM="$REPO/claude/hooks/outbound-gate.sh"

PASS=0; FAIL=0; SKIP=0
pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf '  skip %s\n' "$1"; }

ENVSCAN=${ENVSCAN:-$(command -v envscan 2>/dev/null || true)}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home" "$WORK/with-bin"
SYS_PATH=/usr/bin:/bin
if [ -n "$ENVSCAN" ]; then
  ln -s "$ENVSCAN" "$WORK/with-bin/envscan"
fi

export GIT_AUTHOR_NAME=gate-test GIT_AUTHOR_EMAIL=gate-test
export GIT_COMMITTER_NAME=gate-test GIT_COMMITTER_EMAIL=gate-test
export GIT_CONFIG_NOSYSTEM=1

PLANTED=quokkafjord42

# A repo opted in the way #72 describes: a .env, and a .env.example with a
# `# what:` line per key. The worktree gets no .env of its own, as in life.
new_repo() {
  local d=$1
  mkdir -p "$d"
  git -C "$d" init -q -b main
  printf '.env\ntmp/\n' > "$d/.gitignore"
  printf '# what: an invented project codename | group: test\nCODENAME=\n' > "$d/.env.example"
  git -C "$d" add .gitignore .env.example
  git -C "$d" commit -q -m init
  printf 'CODENAME=%s\n' "$PLANTED" > "$d/.env"
}

# Pipe a hook payload into the shim from directory $1. Sets RC and ERR.
# $2 is "bin" (envscan reachable through PATH) or "nobin" (PATH and HOME hold none).
run_gate() {
  local dir=$1 mode=$2 payload=$3 path=$SYS_PATH
  [ "$mode" = bin ] && path="$WORK/with-bin:$SYS_PATH"
  ERR=$(cd "$dir" && printf '%s' "$payload" | env -i PATH="$path" HOME="$WORK/home" \
    GIT_AUTHOR_NAME=x GIT_AUTHOR_EMAIL=x \
    GIT_COMMITTER_NAME=x GIT_COMMITTER_EMAIL=x \
    "$BASH" "$SHIM" 2>&1 >/dev/null)
  RC=$?
}

bash_call() { printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"d"}}' "$1" "$2"; }
mcp_call()  { printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"mcp__claude_ai_gh-cli__%s","tool_input":%s}' "$1" "$2" "$3"; }

expect() {
  local name=$1 want=$2
  if [ "$RC" = "$want" ]; then pass "$name"; else fail "$name (want exit $want, got $RC: $ERR)"; fi
}
expect_says() {
  case "$ERR" in *"$2"*) pass "$1" ;; *) fail "$1 (missing [$2] in [$ERR])" ;; esac
}
expect_silent() {
  if [ "$RC" = 0 ] && [ -z "$ERR" ]; then pass "$1"; else fail "$1 (exit $RC, stderr [$ERR])"; fi
}

MAIN="$WORK/main"
new_repo "$MAIN"
git -C "$MAIN" worktree add -q "$WORK/wt" -b side
WT="$WORK/wt"

PLAIN="$WORK/plain"
mkdir -p "$PLAIN"; git -C "$PLAIN" init -q -b main
printf 'PORT=\n' > "$PLAIN/.env.example"

echo "1. a repo that is not opted in passes silently"
for mode in bin nobin; do
  run_gate "$PLAIN" "$mode" "$(bash_call "$PLAIN" "git push origin main --no-verify")"
  expect_silent "no .env, $mode: a push passes with no output"
  run_gate "$PLAIN" "$mode" "$(mcp_call "$PLAIN" gh '{"args":"issue comment 1 --body hi"}')"
  expect_silent "no .env, $mode: an MCP gh call passes with no output"
done
run_gate "$WORK" nobin "$(bash_call "$WORK" "gh pr create --body x")"
expect_silent "outside any git repo: passes"

echo "2. envscan missing: only what cannot post goes through"
for where in main wt; do
  dir=$MAIN; [ "$where" = wt ] && dir=$WT
  run_gate "$dir" nobin "$(bash_call "$dir" "ls -la && cat README")"
  expect "$where, no binary: a command with no git or gh word passes" 0
  run_gate "$dir" nobin "$(bash_call "$dir" "git push origin main")"
  expect "$where, no binary: git push denies" 2
  expect_says "$where, no binary: the reason names how to install" "skills/stable/promote-tmp/scripts/envscan"
  run_gate "$dir" nobin "$(bash_call "$dir" "echo ok\\ngit status")"
  expect "$where, no binary: git after an escaped newline denies" 2
  run_gate "$dir" nobin "$(bash_call "$dir" "rtk gh pr list")"
  expect "$where, no binary: gh behind a prefix denies" 2
  run_gate "$dir" nobin "$(mcp_call "$dir" gh '{"args":"issue comment 1 --body hi"}')"
  expect "$where, no binary: an MCP gh call denies" 2
  run_gate "$dir" nobin "$(mcp_call "$dir" read_files '{"paths":["README.md"]}')"
  expect "$where, no binary: an MCP read tool passes" 0
done
run_gate "$MAIN" nobin "$(bash_call "$MAIN" "legit-tool --digit 5")"
expect "no binary: git inside a longer word is not a git word" 0

echo "3. malformed hook input denies (fail closed)"
for mode in bin nobin; do
  if [ "$mode" = bin ] && [ -z "$ENVSCAN" ]; then skip "malformed, bin: no envscan build"; continue; fi
  run_gate "$MAIN" "$mode" '{"tool_name": "Bash", "tool_input": {"command": "git com'
  expect "malformed JSON, $mode: denies" 2
  run_gate "$MAIN" "$mode" 'not json at all'
  expect "garbage, $mode: denies" 2
done

echo "4. envscan present: planted values deny, clean calls pass"
if [ -z "$ENVSCAN" ]; then
  skip "section 4: no envscan build; set ENVSCAN or put envscan on PATH"
else
  for where in main wt; do
    dir=$MAIN; [ "$where" = wt ] && dir=$WT
    run_gate "$dir" bin "$(bash_call "$dir" "ls -la")"
    expect "$where: a plain command passes" 0
    run_gate "$dir" bin "$(bash_call "$dir" "git commit -m 'tidy the readme'")"
    expect "$where: a clean commit passes" 0
    run_gate "$dir" bin "$(bash_call "$dir" "git commit -m 'ship $PLANTED today'")"
    expect "$where: planted value in a commit message denies" 2
    expect_says "$where: the reason names the key" "CODENAME"
    case "$ERR" in *"$PLANTED"*) fail "$where: the reason must not print the value" ;; *) pass "$where: the reason does not print the value" ;; esac
    printf 'notes about %s\n' "$PLANTED" > "$dir/notes.txt"
    git -C "$dir" add notes.txt
    run_gate "$dir" bin "$(bash_call "$dir" "git commit -m 'add notes'")"
    expect "$where: planted value in the staged diff denies" 2
    git -C "$dir" rm -q --cached notes.txt; rm -f "$dir/notes.txt"
    run_gate "$dir" bin "$(bash_call "$dir" "gh pr create --title t --body 'see $PLANTED'")"
    expect "$where: planted value in gh --body denies" 2
    mkdir -p "$dir/tmp"; printf 'body %s\n' "$PLANTED" > "$dir/tmp/body.md"
    run_gate "$dir" bin "$(bash_call "$dir" "gh issue comment 1 --body-file tmp/body.md")"
    expect "$where: planted value in a gh --body-file denies" 2
    run_gate "$dir" bin "$(mcp_call "$dir" gh "{\"args\":\"issue comment 1 --body $PLANTED\"}")"
    expect "$where: planted value in an MCP gh call denies" 2
    run_gate "$dir" bin "$(mcp_call "$dir" gh '{"args":"issue comment 1 --body hello"}')"
    expect "$where: a clean MCP gh call passes" 0
  done

  BARE="$WORK/remote.git"
  git init -q --bare "$BARE"
  git -C "$MAIN" remote add origin "$BARE"
  git -C "$MAIN" push -q origin main 2>/dev/null
  printf 'leak %s\n' "$PLANTED" > "$MAIN/leak.txt"
  git -C "$MAIN" add leak.txt
  git -C "$MAIN" commit -q -m 'local only'
  run_gate "$MAIN" bin "$(bash_call "$MAIN" "git push origin main")"
  expect "main: push of an unpushed planted commit denies" 2
  run_gate "$WT" bin "$(bash_call "$WT" "git push origin side")"
  expect "worktree: the same unpushed commit denies a push from the worktree" 2

  printf 'CODENAME=\n' > "$MAIN/.env"
  run_gate "$MAIN" bin "$(bash_call "$MAIN" "git commit -m 'tidy'")"
  expect "half-filled .env: an outbound call denies" 2
  expect_says "half-filled .env: the reason names the empty key" "CODENAME"
  printf 'CODENAME=%s\n' "$PLANTED" > "$MAIN/.env"

  mkdir -p "$WORK/broken-bin"
  printf '#!/bin/sh\ncat >/dev/null\nexit 3\n' > "$WORK/broken-bin/envscan"; chmod +x "$WORK/broken-bin/envscan"
  ERR=$(cd "$MAIN" && bash_call "$MAIN" "ls" | env -i PATH="$WORK/broken-bin:$SYS_PATH" HOME="$WORK/home" "$BASH" "$SHIM" 2>&1 >/dev/null); RC=$?
  expect "an envscan IO error (exit 3) becomes a deny, never a pass" 2
fi

echo "5. envscan found at \$HOME/.local/bin when PATH has none"
if [ -z "$ENVSCAN" ]; then
  skip "section 5: no envscan build"
else
  mkdir -p "$WORK/home/.local/bin"; ln -s "$ENVSCAN" "$WORK/home/.local/bin/envscan"
  run_gate "$MAIN" nobin "$(bash_call "$MAIN" "gh pr create --body 'see $PLANTED'")"
  expect "home-dir binary: planted --body denies by scan" 2
  expect_says "home-dir binary: the reason comes from envscan, naming the key" "CODENAME"
  run_gate "$MAIN" nobin "$(bash_call "$MAIN" "git status")"
  expect "home-dir binary: a non-posting git command passes" 0
  rm -rf "$WORK/home/.local"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" = 0 ]
