#!/usr/bin/env python3
"""Live trial: regex-only baseline vs broad-extract + Jev judgement, on the SYNTHETIC fixture only.
  python3 -I trial.py [per-line|batched|both] [--model jev-1.14.0]
Key: read from ../../../.env line by line (JEV_API_KEY). Never printed, logged or written.
Raw request bodies and responses go to raw/ (they never contain the key; headers are not saved).
"""
import json, os, re, sys, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ENV = os.path.abspath(os.path.join(HERE, "../../../.env"))
API = "https://api.typesafe.ai/v1/systemone"
PRICE_PER_TOK = 0.042 / 1e6
MODEL = sys.argv[sys.argv.index("--model") + 1] if "--model" in sys.argv else "jev-1.14.0"
RAW = os.path.join(HERE, "raw")
os.makedirs(RAW, exist_ok=True)


def load_key():
    with open(ENV) as f:
        for line in f:
            line = line.strip()
            if line.startswith("JEV_API_KEY="):
                v = line.split("=", 1)[1].strip()
                return v[1:-1] if v[:1] in "\"'" and v[-1:] == v[:1] else v
    sys.exit("JEV_API_KEY not found")


KEY = None


def call(body, tag):
    data = json.dumps(body).encode()
    req = urllib.request.Request(API, data=data, method="POST", headers={
        "Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    t0 = time.time()
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                resp = json.loads(r.read())
            break
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace").replace(KEY, "<REDACTED>")
            if e.code in (429, 529) and attempt < 4:
                time.sleep(2 ** attempt); continue
            raise SystemExit(f"HTTP {e.code} on {tag}: {msg[:500]}")
    dt = time.time() - t0
    with open(os.path.join(RAW, tag + ".json"), "w") as f:
        json.dump({"request_body": body, "response": resp, "latency_s": round(dt, 3)}, f, indent=1)
    return resp, dt


# ---------------- candidate extraction (code, broad, high recall) ----------------
SHAPES = [  # order = priority; a later span overlapping an earlier one is dropped
    ("bucket", r"\b(?:gs|s3)://[A-Za-z0-9._-]+"),
    ("email", r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"),
    ("url-host", r"(?<=://)[A-Za-z0-9.-]+"),
    ("gh-repo", r"(?<=github\.com/)[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+"),
    ("home-path", r"(?:/home|/Users)/[^\s\"'`:,)]+"),
    ("ip", r"(?<![\d.])\d{1,3}(?:\.\d{1,3}){3}(?:/\d{1,2})?(?![\d])"),
    ("filename", r"[A-Za-z0-9_.-]+\.(?:csv|xlsx|pdf|txt|parquet)\b"),
    ("hostname", r"\b[a-z0-9-]+(?:\.[a-z0-9-]+)+\.[a-z]{2,}\b|\b[a-z0-9-]+\.(?:internal|lan|local|corp)\b"),
    ("owner-repo", r"(?<![/\w.-])[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9_.-]*(?![/\w])"),
    ("account-id", r"\b\d{12}\b"),
    ("handle", r"(?<![\w.])@[a-z][a-z0-9_-]+"),
    ("slug", r"\b[a-z][a-z0-9]*(?:-[a-z0-9]+){1,}\b"),
    ("proper-noun", r"\b[A-Z][a-z]{3,}(?: [A-Z][a-z]{3,})*\b"),
]
COMMON_CAPS = set("""Session Context Client What Open Questions Decisions Should Probably Retried Exported Ask Upgrade
Keep Nothing Ping Move Delete Confirm Notes Steps Opened Compared Checked Handoff Dashboard Their Landing Repo
Remember Another Look Compare Measure Write Version Public Scratch Old Prod Raw The This That Ran Retry Use
Weekly Monday Thursday Timezone Ping Try Remember Moved Done Starting""".split())


def extract(line):
    taken, out = [], []
    for kind, rx in SHAPES:
        for m in re.finditer(rx, line):
            s, e = m.span()
            if any(s < te and ts < e for ts, te in taken):
                continue
            v = m.group(0).rstrip(".")
            if kind == "proper-noun" and (v in COMMON_CAPS or s <= 2):
                continue
            if kind == "ip" and v.count(".") != 3:
                continue
            taken.append((s, e)); out.append({"value": v, "shape": kind})
    return out


# ---------------- regex-only baseline (ported shapes + stoplist of the earlier probe) ----------------
BASE = [
    ("home-path", r"(?:/home|/Users)/([A-Za-z0-9._-]+)"),
    ("email", r"\b([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})\b"),
    ("private-ip", r"(?<![\d.])((?:10\.\d{1,3}|192\.168|172\.(?:1[6-9]|2\d|3[01])|100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7]))\.\d{1,3}\.\d{1,3})(?![\d.])"),
    ("internal-host", r"\b([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:lan|local|internal|corp|home|ts\.net))\b"),
    ("bucket", r"\b((?:gs|s3)://[A-Za-z0-9._-]+)"),
    ("gh-owner", r"github\.com[/:]([A-Za-z0-9-]+)/"),
    ("fqdn", r"\b((?:[a-z0-9-]+\.)+(?:com|net|org|io|dev|ai|co|app|cloud))\b"),
]
STOP = set("github.com example.com example.org localhost npmjs.com googleapis.com anthropic.com claude.com gitlab.com "
           "docs.github.com raw.githubusercontent.com api.github.com noreply".split())


def baseline(line):
    out = []
    for kind, rx in BASE:
        for m in re.finditer(rx, line):
            v = m.group(1)
            if v.lower() in STOP or (kind == "home-path" and v.lower() in ("runner", "user")):
                continue
            out.append({"value": v, "shape": kind})
    return out


# ---------------- Jev questions ----------------
KINDS = {
    "client_or_company_name": "The name of a specific company, client, or organisation (not a software project or library)",
    "person_name": "A person's real name",
    "username_or_handle": "A login name or @handle of a specific person",
    "hostname_or_domain": "A server hostname or a domain name",
    "ip_address_or_range": "An IP address or IP range",
    "email_address": "An email address",
    "home_directory_path": "A file path inside a person's home directory",
    "storage_bucket": "A cloud storage bucket such as gs:// or s3://",
    "cloud_project_or_region": "A cloud project ID, region, or zone",
    "account_id": "A numeric cloud or billing account ID",
    "code_repository": "A source code repository name",
    "software_or_version": "A library, tool, package, image, or version number",
    "other": "Anything else",
}
NOUL_TRUE = ("The value points at one particular private organisation, person, machine, or account: for example a client "
             "company name, an internal or private hostname, a private IP address, a private repository, a private bucket, "
             "a cloud project or account ID, an individual's email, a username, or a path in someone's home directory. "
             "Publishing it would reveal who the work is for or where it runs.")
NOUL_FALSE = ("The value is public or generic: a well-known public website or service, a public open-source project or its "
              "GitHub owner, a library or tool name, a version number, a loopback or public DNS address such as 127.0.0.1 or "
              "8.8.8.8, a system path such as /var/log, or an ordinary word.")


def qs_for(cid, value, where):
    return {
        f"{cid}__private": {"type": "noul",
                            "instructions": f"Is the value `{value}` in {where} a private identifier that should be moved into a local .env file before this text is published?",
                            "criteria": {"true": NOUL_TRUE, "false": NOUL_FALSE}},
        f"{cid}__kind": {"type": "choice", "instructions": f"What kind of value is `{value}` in {where}?",
                         "criteria": KINDS},
    }


def fixture_lines():
    for root, _, files in os.walk(os.path.join(HERE, "fixture")):
        for fn in sorted(files):
            p = os.path.join(root, fn); rel = os.path.relpath(p, os.path.join(HERE, "fixture"))
            with open(p) as f:
                for n, l in enumerate(f.read().splitlines(), 1):
                    yield rel, n, l


def run_per_line(lines):
    jobs = []
    for rel, n, l in lines:
        cands = extract(l)
        if not cands:
            continue
        qs = {}
        for i, c in enumerate(cands):
            qs.update(qs_for(f"c{i}", c["value"], "`line`"))
        jobs.append((rel, n, l, cands, {"model": MODEL, "state": {"file": rel, "line": l}, "questions": qs}))
    results, lat, toks = [], [], 0
    t0 = time.time()
    with ThreadPoolExecutor(8) as ex:
        futs = [ex.submit(call, j[4], f"perline__{j[0].replace('/', '_')}__{j[1]:03d}") for j in jobs]
        for j, fu in zip(jobs, futs):
            resp, dt = fu.result(); lat.append(dt); toks += resp["usage"]["input_tokens"]
            for i, c in enumerate(j[3]):
                a = resp["answers"]
                results.append({"file": j[0], "line": j[1], **c, "p": a[f"c{i}__private"]["noul"],
                                "kind": a[f"c{i}__kind"]["choice"]})
    return results, {"requests": len(jobs), "wall_s": round(time.time() - t0, 2), "latencies": lat, "input_tokens": toks}


def run_batched(lines):
    byfile = {}
    for rel, n, l in lines:
        byfile.setdefault(rel, []).append((n, l))
    jobs = []
    for rel, ls in byfile.items():
        state = {"file": rel, "lines": {f"L{n:03d}": l for n, l in ls if l.strip()}}
        qs, meta = {}, []
        for n, l in ls:
            for i, c in enumerate(extract(l)):
                cid = f"L{n:03d}c{i}"
                qs.update(qs_for(cid, c["value"], f"`lines.L{n:03d}`")); meta.append((cid, n, c))
        jobs.append((rel, meta, {"model": MODEL, "state": state, "questions": qs}))
    results, lat, toks = [], [], 0
    t0 = time.time()
    with ThreadPoolExecutor(8) as ex:
        futs = [ex.submit(call, j[2], f"batched__{j[0].replace('/', '_')}") for j in jobs]
        for j, fu in zip(jobs, futs):
            resp, dt = fu.result(); lat.append(dt); toks += resp["usage"]["input_tokens"]
            for cid, n, c in j[1]:
                a = resp["answers"]
                results.append({"file": j[0], "line": n, **c, "p": a[f"{cid}__private"]["noul"], "kind": a[f"{cid}__kind"]["choice"]})
    return results, {"requests": len(jobs), "wall_s": round(time.time() - t0, 2), "latencies": lat, "input_tokens": toks}


# ---------------- scoring ----------------
def overlap(a, b):
    a, b = a.lower(), b.lower()
    return a in b or b in a


def score(preds, key, label):
    planted = [k for k in key if k["planted"]]
    tp_preds = [p for p in preds if any(k["file"] == p["file"] and k["line"] == p["line"] and overlap(k["value"], p["value"]) for k in planted)]
    fp = [p for p in preds if p not in tp_preds]
    hit = [k for k in planted if any(k["file"] == p["file"] and k["line"] == p["line"] and overlap(k["value"], p["value"]) for p in preds)]
    miss = [k for k in planted if k not in hit]
    prec = len(tp_preds) / len(preds) if preds else 0
    rec = len(hit) / len(planted)
    return {"label": label, "flagged": len(preds), "true_pos": len(tp_preds), "false_pos": len(fp),
            "planted": len(planted), "found": len(hit), "precision": round(prec, 3), "recall": round(rec, 3),
            "missed": [f"{k['file']}:{k['line']} {k['kind']} {k['value']}" for k in miss],
            "false_positives": [f"{p['file']}:{p['line']} {p['shape']} {p['value']}" + (f" p={p['p']:.2f}" if "p" in p else "") for p in fp]}


KIND_MAP = {"client": "client_or_company_name", "person": "person_name", "username": "username_or_handle",
            "hostname": "hostname_or_domain", "domain": "hostname_or_domain", "ip": "ip_address_or_range",
            "email": "email_address", "home-path": "home_directory_path", "bucket": "storage_bucket",
            "cloud-project": "cloud_project_or_region", "region": "cloud_project_or_region", "account-id": "account_id",
            "repo": "code_repository"}


def kind_acc(results, key):
    ok = tot = 0
    for r in results:
        for k in key:
            if k["planted"] and k["file"] == r["file"] and k["line"] == r["line"] and overlap(k["value"], r["value"]):
                tot += 1; ok += KIND_MAP[k["kind"]] == r["kind"]; break
    return {"kind_correct": ok, "kind_total": tot, "kind_accuracy": round(ok / tot, 3) if tot else None}


def pct(xs, q):
    xs = sorted(xs); return round(xs[min(len(xs) - 1, int(q * len(xs)))], 3) if xs else None


def main():
    global KEY
    mode = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "both"
    key = json.load(open(os.path.join(HERE, "answer-key.json")))
    lines = list(fixture_lines())
    report = {"model": MODEL, "lines": len(lines), "chars": sum(len(l) + 1 for _, _, l in lines)}
    base = [{"file": r, "line": n, **c} for r, n, l in lines for c in baseline(l)]
    report["regex_baseline"] = score(base, key, "regex-only (earlier probe shapes)")
    cands = [{"file": r, "line": n, **c} for r, n, l in lines for c in extract(l)]
    report["extractor_ceiling"] = score(cands, key, "broad extractor, everything flagged")
    KEY = load_key()
    for m, fn in (("per-line", run_per_line), ("batched", run_batched)):
        if mode not in (m, "both"):
            continue
        res, st = fn(lines)
        json.dump(res, open(os.path.join(HERE, f"results-{m}.json"), "w"), indent=1)
        st.update({"p50_s": pct(st["latencies"], .5), "p95_s": pct(st["latencies"], .95), "max_s": pct(st["latencies"], 1),
                   "cost_usd": round(st["input_tokens"] * PRICE_PER_TOK, 6),
                   "tokens_per_fixture_line": round(st["input_tokens"] / len(lines), 1)})
        del st["latencies"]
        report[m] = {"stats": st, **kind_acc(res, key)}
        for th in (0.3, 0.5, 0.7):
            report[m][f"t{th}"] = score([r for r in res if r["p"] > th], key, f"jev {m} noul>{th}")
    json.dump(report, open(os.path.join(HERE, "trial-report.json"), "w"), indent=1)
    def brief(s): return {k: s[k] for k in ("flagged", "true_pos", "false_pos", "found", "planted", "precision", "recall")}
    print(json.dumps({k: (brief(v) if isinstance(v, dict) and "precision" in v else
                          {kk: (brief(vv) if isinstance(vv, dict) and "precision" in vv else vv) for kk, vv in v.items()} if isinstance(v, dict) else v)
                      for k, v in report.items()}, indent=1))


if __name__ == "__main__":
    main()
