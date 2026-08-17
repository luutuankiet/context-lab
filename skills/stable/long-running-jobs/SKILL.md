---
name: long-running-jobs
description: Run and track remote jobs that could outlast the 1-hour proxy deadline — backgrounding, watcher subagents, ScheduleWakeup pacing, and completion sentinels. Load only for work plausibly exceeding an hour (warehouse backfills, multi-hour migrations, cold-cache image builds), or when a job must survive session compaction.
---

# Long-Running Jobs

## When this applies (and when it does not)

The proxy cuts a tool call off at **1 hour**. Below that, nothing here applies.

| Situation | Do this |
|---|---|
| Job finishes inside ~1h | **Foreground.** `run_command` with a fitting `timeout_sec` (`900`, `3600`). Stop reading. |
| Job could outlast ~1h | Background + watcher, below. |
| Job must survive a `/compact` | Background + watcher, below. Watchers survive compaction — verified. |
| Session must stay responsive while the job runs | Background + watcher, below. |

Backgrounding a job that would have finished in ten minutes is a net loss: a watcher subagent, several polling turns, and latency, for nothing.

## Launching

**Every backgrounded command ends with an exit-code sentinel.** A dead pid means the process ended — never that it succeeded. Only the `rc` separates a crash from a clean finish.

```
<the work> 2>&1; echo "=== JOBDONE_<slug> rc=$? ==="
```

Launch shape — returns `{job_id, pid, log_path}` in ~30ms:

```js
{command: "<work> 2>&1; echo \"=== JOBDONE_<slug> rc=$? ===\"", background: true}
```

**Check liveness before spawning a watcher:**

```
ps -p <pid> >/dev/null 2>&1 && echo ALIVE || echo DIED_FAST
```

Died fast → read the log and skip the watcher entirely. Fast failures die in under a second, and a watcher aimed at a corpse wastes a full subagent.

## Tracking

| Expected duration | Mechanism |
|---|---|
| up to ~25 min | **watcher subagent** — polls in a loop; its completion notification re-invokes the parent unprompted |
| beyond ~25 min | **`ScheduleWakeup`** self-pacing — wake every ~20 min and check once, instead of dozens of subagent turns |

### Watcher poll shape

The `sleep` is what makes this cheap: one tool call consumes ~100s of wall clock, so waiting costs turns instead of tokens. The `tail` rides along free.

```
ps -p <pid> >/dev/null 2>&1 && echo STILL_RUNNING || echo JOB_FINISHED; tail -2 <log_path>; sleep 100
```

Call it with `timeout_sec: 110` — enough headroom over the 100s sleep, well inside fs-mcp's own limit.

### Watcher prompt requirements (all mandatory)

- the verbatim poll call, exact `pid` and `log_path` filled in
- `timeout_sec: 110` + `sleep 100`, **with the reason stated** — otherwise the subagent "optimizes" them away
- `STILL_RUNNING` / `JOB_FINISHED` loop logic
- a derived poll cap: `ceil(expected_seconds / 80) + 3`
- the completion rule: the job is done only when the log contains `=== JOBDONE_<slug> rc=<N> ===`, relayed verbatim; pid absence is not completion
- an instruction to report the **tail progression across polls**, not just the terminal state
- the leaf-node clause (never spawn further agents)

Run watchers on **haiku** — the work is polling, not reasoning.

## Caveats

- **Background jobs die if the proxy restarts.** They are grandchildren of the proxy service process, so a `systemctl restart`, a watchdog action, or a host reboot kills every in-flight job. The watcher then reports the pid gone — indistinguishable from clean completion without the sentinel. This is the whole reason the sentinel is non-negotiable.
- **Watchers survive compaction.** A watcher launched before a `/compact`, with the parent context wiped mid-flight, still delivered its notification and re-woke the parent. Compaction is client-side only; the remote job and the harness-tracked watcher are untouched.
- **Job logs live at `/tmp/fs-mcp-jobs/*.log`**, written by the tool itself — one of the few sanctioned uses of host `/tmp`.
