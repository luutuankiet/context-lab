---
name: promote-tmp
description: Promote a gitignored tmp/YYYYMMDD/<topic>/ folder into committed evidence, docs or issues, with every copy dehydrated and scanned clean, and record each file so the folder can be cleared safely. Use when the operator asks to promote, keep or clear a tmp/ topic folder, before deleting one, or when they wrap up a session that left work in tmp/; it hands off to repo-context-audit at the end.
---

# Promote a tmp/ topic folder

**Opt-in.** This runs only when the operator invokes it, in a repo with a `.env`. A
repo set up by repo-context-audit alone works exactly as before without it.

Each file in `tmp/YYYYMMDD/<topic>/` leaves as one of five handlings, decided by
whether it is **run**, **read as evidence** or **read as prose** (ADRs 0015 and 0017
in the context-lab repo):

| handling | for | what is committed | `--ref` |
|---|---|---|---|
| `snapshot` | authored and runnable: a script, a fixture generator, an answer key; **or tool output a page cites as evidence**: a run log, a build or test result | a dehydrated copy in `evidence/YYYYMMDD-<topic>/` | commit SHA |
| `write-up` | authored prose: notes, a handoff | a fresh page, decision or issue; never a copy | commit SHA or `issue:<n>` |
| `cache` | rebuildable or passed through: downloads, generated output, vendor text | a pointer entry in the evidence `README.md` | commit SHA |
| `discard` | tool output nothing cites, scanner output | nothing | none |
| `refuse` | regulated data, credentials, another client's material | nothing | none |

**Tool output is read, never run**, so a snapshot of it only has to be safe to read:
every identifying value in it becomes a `$KEY` or is rewritten away, and the copy
scans clean. Prose still has no copy path.

A data file (`.csv .tsv .jsonl .ndjson .xlsx .xls .parquet .sqlite .db .avro .orc
.hyper .twbx .tdsx`) is never opened by you and never snapshot: cache, discard or
refuse. A nested clone is moved to `tmp/refs/<key>/`, outside the topic folder, not
promoted.

**Scope.** The menu is working output to the operator and may use resolved names.
Everything committed (snapshot, write-up, README, commit message) names each
sensitive thing as a bare `$KEY` and scans clean.

Run every command from the repo root. Commands write `<envscan>` for the
`envscan=` path step 1 prints; use that absolute path, because `$HOME/.local/bin`
may be off `PATH`.

## Steps

1. **Preflight.** Stop on any failure and show its message.

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/stable/promote-tmp/scripts/preflight.sh" tmp/YYYYMMDD/<topic>
   ```

   It checks: a commit exists and the clone is not shallow; `.env` and `tmp/` are
   ignored; the folder has the form `tmp/YYYYMMDD/<topic>/`; the binary is present
   (installing it through the launcher); `.env` exists; and it runs
   `<envscan> gate install` for the `pre-push` hook. Exit 2 means an existing hook
   refused it: print the hook's message, stop. Exit 3 means no binary: stop. On
   success it prints `envscan=`, `root=`, `folder=` and `default=`.

2. **Status.** List what still needs a decision; `recorded` rows are hidden.

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/stable/promote-tmp/scripts/menu.sh" <envscan> tmp/YYYYMMDD/<topic>
   ```

   One row per `none` or `changed` file: `inbound state sha256 kind path`, most
   cited first. Empty output means every file is recorded: go to step 11.

3. **Scan.** Two scans, both read from their JSON.

   ```bash
   <envscan> scan --known-only --no-ignore --json tmp/YYYYMMDD/<topic>
   <envscan> scan --json <each menu file of kind text, named one by one>
   ```

   The first covers the whole folder, recorded files included, because a file that
   passed can fail once a value is added to `.env`. The second runs judgement on
   the menu files only, because only files named on the command line reach the
   judge. Exit 1 is leaks found. Exit 3 with `data_files` listing a file
   `"scanned": false` is a result: that file is unscanned, never clean. Exit 3
   with no JSON is an error: stop. The tier is the machine's setting; leave it.

4. **Draw the menu.** One row per menu file, in step 2's order (inbound
   references, then the verdict line): path, kind, inbound count, first 12
   characters of the digest, proposed handling and a one-line reason. Under each
   row, every leak and candidate in that file with its proposal: **variable**
   (an existing `$KEY`, or a new neutral key such as `CLIENT_B`), **rewrite**, or
   **refuse**. Read file names as well as scores: a durable file can score 0. Raw
   scanner output is a row with handling `discard`, shown as one.

   A tool-output row proposed as `snapshot` needs more than the scan: **read the
   whole file yourself.** The judge does not read every extension (`.log` and
   `.json` among them), so a host, account, path or person not yet in `.env` gets
   no candidate. List each one you find under the row as a new **variable** or a
   **rewrite**. Output too long to read, or holding regulated data, is `discard` or
   `refuse`, never a snapshot.

5. **Stop for approval. One approval covers one menu.** End your turn and wait for
   the operator. Change nothing until they approve this exact menu. When they
   approve, rerun step 2: if any digest differs from the menu, or a row was edited
   or added, draw the menu again and stop again.

6. **Record discards and refusals.**

   ```bash
   <envscan> promotion add tmp/YYYYMMDD/<topic>/<file> --sha256 <digest> --handling discard
   <envscan> promotion add tmp/YYYYMMDD/<topic>/<file> --sha256 <digest> --handling refuse
   ```

   `<digest>` is the full digest from step 2. Exit 3 means the file changed since
   the menu: it goes back to the menu, step 4.

7. **Branch.**

   ```bash
   git switch -c promote/<topic> <default>
   ```

   Each new variable approved on the menu goes into `.env` and `.env.example`
   together, the example line with a `# what:` line that does not name the value
   (`skills/stable/repo-context-audit/references/env-file.md` in the context-lab
   repo).

8. **Write the evidence.** Everything goes under `evidence/YYYYMMDD-<topic>/`.

   - **Snapshot**, per file; rename any name that holds an identifier:

     ```bash
     bash "${CLAUDE_PLUGIN_ROOT}/skills/stable/promote-tmp/scripts/snapshot.sh" <envscan> tmp/YYYYMMDD/<topic>/<file> evidence/YYYYMMDD-<topic>/<name>
     ```

     It copies through `envscan dehydrate` and scans the copy. Exit 1 means the copy
     is not clean: apply the menu's rewrites to the copy and scan it again with
     `<envscan> scan --no-ignore <copy>`; still not clean, stop.
   - **Write-up**: author the page, decision or issue fresh from what you learned,
     never by pasting the file. Scan the page with `<envscan> scan <page>` before
     committing; an issue body goes through `--body-file` after the same scan.
   - **Cache**: one pointer entry in the README. A row with no rebuild command
     goes back to the menu as write-up or discard.
   - **README**, `evidence/YYYYMMDD-<topic>/README.md`, in this shape:

     ```markdown
     # <topic>: snapshot, not maintained

     Promoted from the YYYYMMDD/<topic> topic folder. Frozen when committed; read it
     as evidence, never as current truth.

     ## <name>
     - was: `<file>` in the YYYYMMDD/<topic> topic folder
     - handling: snapshot | cache
     - pin: sha256 `<digest>`, or `owner/repo@sha:path:line`
     - captured: <UTC time>
     - rebuild: `<command using $KEY names only>`
     ```

     A dehydrated script reruns through a pipe, so no command cites `tmp/`:
     `envscan hydrate evidence/YYYYMMDD-<topic>/<name> | bash -s` (or `| python3 -`).
     For tool output, `rebuild:` is the command that produced it, or `none: a
     recorded run` when a rerun would differ. Write the original location without
     the `tmp/` prefix, as above.
   - Rewrite every tracked citation of the topic folder's files (the `inbound`
     column) to the evidence path or the page that replaced it.

9. **Commit named paths only.**

   ```bash
   git add -- evidence/YYYYMMDD-<topic> <each page, .env.example, each rewritten citation>
   git commit -F <message file>
   ```

   Then confirm no citation of the folder is left: `git grep -nE 'tmp/[0-9]{8}/'`
   prints nothing for this topic.

10. **Record the rest, after the commit.** For every snapshot, write-up and cache
    row, with the commit that holds its copy, page or pointer:

    ```bash
    <envscan> promotion add tmp/YYYYMMDD/<topic>/<file> --sha256 <digest> --handling snapshot --ref <full SHA of that commit>
    ```

    A write-up filed as an issue takes `--ref issue:<n>`. Exit 3 sends the file
    back to the menu.

11. **Report the verdict.** Print this command's output verbatim:

    ```bash
    <envscan> promotion status tmp/YYYYMMDD/<topic>
    ```

    `safe_to_clear` stays `false` until the operator merges the branch into the
    default branch; that is correct. You never delete the folder: clearing it is
    the operator's call, after they see `refused_deleted_on_clear`.

12. **Wrap up the session's context.** Promotion keeps the evidence; it does not
    decide what the repo should now say. Invoke the `context-lab:repo-context-audit`
    skill next and follow its route, so what this session learned reaches
    `AGENTS.md`, `docs/` or an issue. It ends in its own menu, so this is a second
    approval, not a continuation of the first.

## Proof

`tests/route.sh` runs this route end to end on a synthetic folder, including a
changed file returning to the menu and a fresh-checkout rebuild.
