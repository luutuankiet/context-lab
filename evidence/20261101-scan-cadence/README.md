# Snapshot, not maintained

Evidence for "Scan cadence and verdict cache" (issue 65). Nothing here calls a service.

| file | what it does |
|---|---|
| `repeat_cost.py` | models what a repeat judgement run costs per topic folder, with no store, a promotion record, or a line cache; prints counts only |
| `store_probe.py` | eight processes append synthetic records to one JSON Lines file, then a reader checks for loss |
| `repo_identity_probe.sh` | tests the root commit as a repo identity on a synthetic repo, and counts root commits across local clones |

## Rebuild

`TMP_ROOT` is a repo's `tmp/`, `SCRATCH` an empty folder, and `CLONES` a folder of clones.

```sh
python3 -I repeat_cost.py ../20261101-judgement-data-policy/count_flagged.py "$TMP_ROOT"
python3 -I store_probe.py "$SCRATCH"
bash repo_identity_probe.sh "$SCRATCH" "$CLONES"
```

## Measured

Repeat cost across 19 real topic folders, when one file (the folder's largest) gains one flagged line. Dollars use the as-run price, about $3.2e-5 per candidate; trimmed questions cost about a sixth.

| | median | p90 | largest folder |
|---|---:|---:|---:|
| flagged lines | 137 | 5,773 | 688,610 |
| first run | $0.0087 | $0.99 | $31.24 |
| repeat, no store | $0.0087 | $0.99 | $31.24 |
| repeat, promotion record | $0.0038 | $0.21 | $2.06 |
| repeat, line cache | $0.00003 | $0.00003 | $0.00003 |

- Candidates on repeated lines within a folder: 31%, which removing duplicates in memory saves with no store.
- Distinct flagged lines already seen in an earlier folder: 0.15%.
- The largest folder has 16,559 files and probably holds third-party source.

Store: 8 writers, 40,000 records, none lost, a full read in 0.16 s, and a torn final line skipped. Python on a local disk; not Rust, not a network filesystem.

Identity: a moved clone, a full clone and a removed remote keep the root commit; a shallow clone gets a different one. Of 40 local clones, 34 have one root, 3 several, 3 no commits, and 4 no remote.

Limits: lines were read in memory to extract and hash, never displayed or sent. `.json`, `.jsonl`, `.log`, data files and files over 2 MB were skipped. No client repo was measured.

## Jev client

`jev_client.py` is the trial client behind the measured scores, kept so the request shape and questions can be read. It was run from a dated `tmp/` folder, so its relative paths and `.env` key lookup do not resolve here. One word in its question text was changed before committing, because it equals a machine alias in the local `.env`. The scores were measured before that change, and the build spec's live test covers the new wording.
