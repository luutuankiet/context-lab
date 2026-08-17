---
name: task-reconstruction
description: Use when tasks need to be reconstructed after a session fork, when TaskList returns empty but conversation history contains task references, or when user asks about current tasks, todos, or work items and the task list appears stale or empty. Also triggers on "reconstruct tasks", "rebuild tasks", "what are our todos", "what tasks do we have", or "where were we".
---

# Task Reconstruction After Fork

Tasks (`~/.claude/tasks/`) don't survive session forks. But conversation
history contains every TaskCreate/TaskUpdate call with full arguments.

## When to Trigger

- TaskList returns empty AND conversation references tasks
- User asks about current tasks/todos and list seems stale
- User explicitly asks to reconstruct/rebuild tasks
- Session appears to be a fork (fresh task state, rich conversation history)

## Reconstruction Steps

1. **Detect:** Call TaskList. If empty but conversation contains TaskCreate calls → fork happened.
2. **Scan:** Find all TaskCreate calls in conversation — extract `subject`, `description`, `activeForm` from args.
3. **Track updates:** Find all TaskUpdate calls — track latest `status`, `subject` changes, `description` updates per task ID.
4. **Compute final state:** For each original task, apply all updates to get current subject, description, status.
5. **Recreate sequentially:** TaskCreate each task one at a time (batch creation gives random IDs). Create in original creation order.
6. **Apply status:** TaskUpdate each recreated task to its final status (`in_progress`, `completed`, `pending`).
7. **Verify:** Echo the reconstructed list to user for confirmation.

## What NOT to Reconstruct

- Tasks with final status `deleted`
- Optionally skip completed tasks if user only wants active work (ask first)

## Important Notes

- Task IDs will differ from the original session (new IDs are assigned on creation)
- The `[REF] Session filesystem map` task is the highest-priority reconstruction target — it contains filesystem mapping, recommended `retrieve_tools` queries, and Known Good Calls (few-shot tool patterns) that subagents depend on for tool discovery (see §0.2 Tool Discovery Protocol)
- If conversation was compacted before the fork, some task descriptions may be lost — reconstruct what's available and flag gaps
- If the [REF] task description is lost, re-run `retrieve_tools` with a broad query and rebuild the Known Good Calls section from the discovery results