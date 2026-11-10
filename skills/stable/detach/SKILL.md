---
name: detach
description: Main thread only, never a subagent. Start a named background Claude session that outlives this one, for a new task or to hand this session's own work to a fresh one.
---

# Detach

Only the main thread runs this. If another agent spawned you, stop here and return a handoff to that agent instead.

Start one independent session with `claude --bg`. It is a separate process, so closing this session leaves it running. The new session starts cold, knowing only its prompt.

1. **Name it.** Use the given name, or a short kebab-case one from the task. Done when you have a name the user can type.

2. **Write the hand-off.** A task that fits in a sentence goes straight in the prompt. Anything that leans on this session goes in `<repo root>/tmp/YYYYMMDD/<name>/<name>-brief.md`. The brief carries the goal, the links and files to read, the rules that apply, the skills to call, and how to end. Done when a reader with no access to this conversation could start work.
   - Work with a person in the loop, such as a grilling session: open the ticket, call its skills, ask the first round, then wait for the user to attach.
   - Unattended work: name the results file, then wait to answer questions from later sessions.
   - Handing off this session's own work: the handoff file you already wrote is the brief, so write no second file. Launch in the checkout form, from the directory you are working in.

3. **Choose where it works.** Use the checkout unless the task needs isolation. Work there shares gitignored files such as `tmp/` and `.env`, and it shares the branch with any other session editing that checkout. Choose a worktree only when the task is cleanly isolated: it needs none of those gitignored files, and its edits could collide with other work. A worktree session gets a fresh copy under `.claude/worktrees/` before its first edit, so give it absolute paths into the main checkout for anything it must read or leave behind, including the results file.

4. **Launch from the directory the work belongs to.** Pass no `--permission-mode`, so the session inherits this machine's default.

   In the checkout:

   ```sh
   cd <target repo> && claude --bg -n <name> --settings '{"worktree":{"bgIsolation":"none"}}' -- "Read <brief path> and follow it."
   ```

   In a worktree, which is what `--bg` does when not told otherwise:

   ```sh
   cd <target repo> && claude --bg -n <name> -- "Read <absolute brief path> and follow it."
   ```

   Keep the `--` before the prompt, because options that take lists would otherwise swallow it. Done when the command prints a short id.

5. **Confirm it is alive.** Run `claude agents --json` and find the row with that name. Its `state` should be `working`, or `blocked` when it is waiting for the user. Plain `claude agents` needs a terminal.

6. **Report** the name, the attach command `claude attach <name>`, and the results path if there is one. A message sent to the session from another one may wait for the user's approval when their permission modes differ, so mention that if the user plans to message it.
