---
name: detach
description: Start a named background Claude session that outlives this one, ready to attach to. Takes the task, and optionally a name.
disable-model-invocation: true
---

# Detach

Start one independent session with `claude --bg`. It is a separate process, so closing this session leaves it running. The new session starts cold, knowing only its prompt.

1. **Name it.** Use the given name, or a short kebab-case one from the task. Done when you have a name the user can type.

2. **Write the hand-off.** A task that fits in a sentence goes straight in the prompt. Anything that leans on this session goes in `<repo root>/tmp/YYYYMMDD/<name>/<name>-brief.md`. The brief carries the goal, the links and files to read, the rules that apply, the skills to call, and how to end. Done when a reader with no access to this conversation could start work.
   - Work with a person in the loop, such as a grilling session: open the ticket, call its skills, ask the first round, then wait for the user to attach.
   - Unattended work: name the results file, then wait to answer questions from later sessions.

3. **Use absolute paths in the hand-off.** A `--bg` session moves into a fresh git worktree under `.claude/worktrees/` before its first edit, and gitignored files such as `tmp/` and `.env` are absent there. Give every file to read or write as an absolute path into the main checkout, including the results file.

4. **Launch from the directory the work belongs to.**

   ```sh
   cd <target repo> && claude --bg -n <name> --permission-mode auto -- "Read <absolute brief path> and follow it."
   ```

   Keep the `--` before the prompt, because options that take lists would otherwise swallow it. Done when the command prints a short id.

5. **Confirm it is alive.** Run `claude agents --json` and find the row with that name. Its `state` should be `working`, or `blocked` when it is waiting for the user. Plain `claude agents` needs a terminal.

6. **Report** the name, the attach command `claude attach <name>`, and the results path if there is one. A message sent to the session from another one may wait for the user's approval when their permission modes differ, so mention that if the user plans to message it.
