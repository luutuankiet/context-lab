#!/usr/bin/env python3
"""What would a repeat judgement-tier run on one topic folder cost, per cache design?

Local only, no network. Prints counts and dollars only: no value, line, or path.
Reads real lines in memory to extract and hash them; nothing is kept or displayed.

  python3 -I repeat_cost.py EXTRACTOR_PY TMP_ROOT [TMP_ROOT...]

Scenario: a folder was judged once, then one file (its largest by flagged lines)
changes by one appended flagged line, and the menu runs again.
  no store       every flagged line in the folder is resent
  promotion rec  unchanged files are hidden by digest, so the whole changed file is resent
  line cache     only the new line is sent
Worst case for the promotion record, because the largest file is the one edited.

Price: $3.2e-5 per candidate as run, $5.4e-6 trimmed. Derived from the published
300k-line row: $2.443 and $0.414 for 60,480 flagged lines at the model's 1.26 candidates.
"""
import hashlib, importlib.util, json, os, re, statistics, sys

spec = importlib.util.spec_from_file_location("count_flagged", sys.argv[1])
cf = importlib.util.module_from_spec(spec)
roots = sys.argv[2:]
sys.argv = ["x"]
spec.loader.exec_module(cf)

AS_RUN, TRIMMED = 2.443 / 60480 / 1.26, 0.414 / 60480 / 1.26
DATA = {".csv", ".tsv", ".xlsx", ".xls", ".parquet", ".json", ".jsonl", ".ndjson", ".log", ".avro", ".orc", ".db", ".sqlite"}
SKIP = cf.SKIP_DIRS | {"target", "dist", "build", "vendor", "site-packages"}


def files_of(topic):
    for root, dirs, fs in os.walk(topic):
        dirs[:] = [d for d in dirs if d not in SKIP and not os.path.exists(os.path.join(root, d, ".git"))
                   and not os.path.exists(os.path.join(root, d, "pyvenv.cfg"))]
        for fn in fs:
            p = os.path.join(root, fn)
            if not os.path.islink(p) and not cf.is_secret_name(fn) and os.path.splitext(fn)[1].lower() not in DATA:
                yield p


def topics():
    for r in roots:
        for day in sorted(os.listdir(r)):
            dp = os.path.join(r, day)
            if re.fullmatch(r"\d{8}", day) and os.path.isdir(dp):
                for t in sorted(os.listdir(dp)):
                    tp = os.path.join(dp, t)
                    if os.path.isdir(tp) and not t.startswith("grill--65"):
                        yield tp


rows, seen_any, cross_total, cross_repeat = [], set(), 0, 0
for tp in topics():
    r = {"files": 0, "flagged": 0, "cands": 0, "max_file_flagged": 0, "max_file_cands": 0}
    distinct = {}
    for p in files_of(tp):
        try:
            if os.path.getsize(p) > 2_000_000:
                continue
            text = open(p, "rb").read().decode("utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        r["files"] += 1
        ff = fc = 0
        for l in text.splitlines():
            n = len(cf.extract(l))
            if n:
                ff += 1
                fc += n
                distinct[hashlib.sha256(l.strip().encode()).digest()] = n
        r["flagged"] += ff
        r["cands"] += fc
        if fc > r["max_file_cands"]:
            r["max_file_flagged"], r["max_file_cands"] = ff, fc
    if r["files"]:
        r["distinct_lines"] = len(distinct)
        r["distinct_cands"] = sum(distinct.values())
        for h in distinct:
            cross_total += 1
            if h in seen_any:
                cross_repeat += 1
            seen_any.add(h)
        rows.append(r)


def dist(v):
    v = sorted(v)
    return {"median": round(statistics.median(v), 6), "p90": round(v[int(len(v) * .9)], 6),
            "max": round(v[-1], 6), "sum": round(sum(v), 6)}


print(json.dumps({
    "topic_folders": len(rows),
    "files": dist([r["files"] for r in rows]),
    "flagged_lines": dist([r["flagged"] for r in rows]),
    "candidates": dist([r["cands"] for r in rows]),
    "first_run_as_run": dist([r["cands"] * AS_RUN for r in rows]),
    "first_run_trimmed": dist([r["cands"] * TRIMMED for r in rows]),
    "repeat_no_store_as_run": dist([r["cands"] * AS_RUN for r in rows]),
    "repeat_promotion_record_as_run_worst": dist([(r["max_file_cands"] + 1) * AS_RUN for r in rows]),
    "repeat_line_cache_as_run": 1 * AS_RUN,
    "share_saved_by_dedup_within_folder": round(1 - sum(r["distinct_cands"] for r in rows) / max(1, sum(r["cands"] for r in rows)), 4),
    "share_of_distinct_lines_seen_in_an_earlier_folder": round(cross_repeat / max(1, cross_total), 4),
}, indent=1))
