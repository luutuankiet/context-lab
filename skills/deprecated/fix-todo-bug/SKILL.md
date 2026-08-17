---
name: fix-todo-bug
description: Fix the TUI bug where tasks disappear from the task list display. Invoke with /fix-todo-bug when tasks stop showing in Ctrl+T.
user-invocable: true
---

# Fix Todo Display Bug

Tasks sometimes disappear from the TUI task list (Ctrl+T) even though they still exist (TaskList returns them). Fix by touching each task with a minimal update.

## Steps
1. Call TaskList to get all current tasks
2. For each task, call TaskUpdate with the same subject + a trailing space (or remove trailing space if already present)
3. Exit clean no need to filler words.