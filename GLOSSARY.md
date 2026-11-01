# Context Lab

The language for designing agent context and for moving what agents leave behind
into a repo's committed context.

## Language

### Promotion

**Promotion**:
Moving what matters from a repo's working folders into its committed context, approved one menu at a time.
_Avoid_: Sync, archive, migration

**Menu**:
The list of candidate files and proposed handling that the operator approves before anything is promoted.
_Avoid_: Plan, checklist

**Topic folder**:
One `tmp/YYYYMMDD/<topic>/` directory, the unit of `tmp/` promotion.
_Avoid_: Day folder, session folder

**Snapshot**:
A runnable file copied into dated evidence, frozen once committed.
_Avoid_: Copy, archive, backup

**Write-up**:
A page, decision or issue authored from material that is read, never a copy of it.
_Avoid_: Rewrite, port

**Pointer**:
A committed record of something left in `tmp/`, including the command that rebuilds it.
_Avoid_: Reference, link

**Cache**:
Anything rebuildable that stays in `tmp/` and is never committed.
_Avoid_: Scratch, leftovers

**Discard**:
A deliberate, operator-visible decision that a file will not be kept.
_Avoid_: Cleanup, skip

**Dehydration**:
Replacing identifying values in a file with variable names held in a local, gitignored `.env`.
_Avoid_: Redaction, scrubbing

### Sensitive items

**Candidate**:
Text that looks like an identifier and is not yet in `.env`.

**Plain tier**:
The scanner's local mode, which matches known values, lists candidates and sends nothing.
_Avoid_: Offline mode

**Judgement tier**:
The scanner's mode that sends flagged lines to a hosted decision model, which sorts candidates. It runs only after a saved choice on that machine.
_Avoid_: AI mode, live scan

**Variable**:
A sensitive item that is a stable literal and so belongs in `.env`.

**Rewrite**:
A sensitive item that needs judgement, which the operator reviews in the menu. It never means turning a file into a page; that is a write-up.

**Refuse**:
A sensitive item that is never promoted: regulated or row-level data, credentials, or another client's material.
