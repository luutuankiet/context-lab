#!/usr/bin/env python3
"""Can a plain append-only file hold the promotion record with concurrent writers?

Synthetic records only. Eight processes each append 5,000 records with one O_APPEND
write per line, then a reader checks that every line parses and none is lost, and
times a full read. A torn final line is also simulated, as a crash would leave.

  python3 -I store_probe.py SCRATCH_DIR
"""
import json, multiprocessing, os, sys, time

path = os.path.join(sys.argv[1], "records.jsonl")
WRITERS, EACH = 8, 5000


def writer(w):
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    for i in range(EACH):
        rec = {"repo": "%040x" % w, "folder": "tmp/20261101/topic-%d" % (i % 50), "file": "script-%d.py" % i,
               "sha256": "%064x" % i, "handling": "snapshot", "at": 1793500000 + i, "w": w, "i": i}
        os.write(fd, (json.dumps(rec) + "\n").encode())
    os.close(fd)


if __name__ == "__main__":
    if os.path.exists(path):
        os.remove(path)
    t = time.time()
    ps = [multiprocessing.Process(target=writer, args=(w,)) for w in range(WRITERS)]
    [p.start() for p in ps]
    [p.join() for p in ps]
    wrote = time.time() - t

    with open(path, "a") as f:
        f.write('{"repo": "torn')

    t = time.time()
    good, bad, seen = 0, 0, set()
    with open(path) as f:
        for line in f:
            try:
                r = json.loads(line)
                seen.add((r["w"], r["i"]))
                good += 1
            except ValueError:
                bad += 1
    print(json.dumps({"expected": WRITERS * EACH, "parsed": good, "unique": len(seen), "bad_lines": bad,
                      "write_seconds": round(wrote, 2), "read_seconds": round(time.time() - t, 3),
                      "file_mb": round(os.path.getsize(path) / 1e6, 1)}, indent=1))
