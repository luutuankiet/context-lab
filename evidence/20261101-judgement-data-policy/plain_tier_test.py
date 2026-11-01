#!/usr/bin/env python3
"""Can promotion ship on the plain tier? Local only, no network, prints counts only.

Part A, synthetic fixture: what each free method finds against the planted answer key.
Part B, real topic folders: how many distinct candidates a promotion would have to review,
per topic folder, with folder names anonymised and no value, line or path printed.

  python3 -I plain_tier_test.py TMP_ROOT ENV_FILE FIXTURE_DIR ANSWER_KEY EXTRACTOR_PY
"""
import importlib.util, json, os, re, statistics, sys

TMP_ROOT, ENV_FILE, FIXTURE, KEY, EXTRACTOR = sys.argv[1:6]

spec = importlib.util.spec_from_file_location("count_flagged", EXTRACTOR)
cf = importlib.util.module_from_spec(spec)
sys.argv = ["x"]
spec.loader.exec_module(cf)

# Same seven shapes and stop list as the prototype scanner's main.rs.
PROTO = [
    ("home-path", r"(?:/home|/Users)/([A-Za-z0-9._-]+)"),
    ("email", r"\b([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})\b"),
    ("private-ip", r"(?<![\d.])((?:10\.\d{1,3}|192\.168|172\.(?:1[6-9]|2\d|3[01])|100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7]))\.\d{1,3}\.\d{1,3})(?!\d)"),
    ("internal-host", r"\b([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:lan|local|internal|corp|home|ts\.net))\b"),
    ("bucket", r"\b((?:gs|s3)://[A-Za-z0-9._-]+)"),
    ("gh-owner", r"github\.com[/:]([A-Za-z0-9-]+)/"),
    ("fqdn", r"\b((?:[a-z0-9-]+\.)+(?:com|net|org|io|dev|ai|co|app|cloud))\b"),
]
PROTO = [(k, re.compile(r)) for k, r in PROTO]
STOP = {"github.com", "example.com", "example.org", "localhost", "npmjs.com", "googleapis.com", "anthropic.com",
        "claude.com", "gitlab.com", "docs.github.com", "raw.githubusercontent.com", "api.github.com", "noreply",
        "runner", "user", "username", "me", "you"}


def proto_extract(line):
    out = []
    for kind, rx in PROTO:
        for m in rx.finditer(line):
            v = m.group(1)
            if v.lower() not in STOP:
                out.append(v)
    return out


def broad_extract(line):
    return [c["value"] for c in cf.extract(line)]


def env_values(path):
    vals = set()
    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            l = raw.strip()
            if not l or l.startswith("#") or "=" not in l:
                continue
            v = l.split("=", 1)[1].strip().strip("\"'")
            if len(v) >= 3:
                vals.add(v.lower())
    return vals


# ---- Part A: fixture
def part_a():
    key = json.load(open(KEY))
    planted = [k for k in key if k["planted"]]
    decoys = [k for k in key if not k["planted"]]
    lines = {}
    for root, _, fs in os.walk(FIXTURE):
        for fn in fs:
            p = os.path.join(root, fn)
            lines[os.path.relpath(p, FIXTURE)] = open(p, encoding="utf-8").read().splitlines()
    res = {"planted": len(planted), "decoys": len(decoys)}

    def score(fn, name):
        found = set()
        flagged = set()
        for rel, ls in lines.items():
            for i, l in enumerate(ls, 1):
                for v in fn(l):
                    flagged.add((rel, i, v))
        fp = 0
        for rel, i, v in flagged:
            match = [k for k in planted if k["file"] == rel and k["line"] == i
                     and (k["value"].lower() in v.lower() or v.lower() in k["value"].lower())]
            if match:
                for k in match:
                    found.add((k["file"], k["line"], k["value"]))
            else:
                fp += 1
        tp = len(flagged) - fp
        res[name] = {"flagged": len(flagged), "false_positive": fp, "planted_found": len(found),
                     "precision": round(tp / len(flagged), 2) if flagged else None,
                     "recall": round(len(found) / len(planted), 2)}
        kinds = {}
        for k in planted:
            if (k["file"], k["line"], k["value"]) not in found:
                kinds[k["kind"]] = kinds.get(k["kind"], 0) + 1
        res[name]["missed_by_kind"] = kinds

    score(proto_extract, "prototype_shapes")
    score(broad_extract, "broad_extractor")
    return res


# ---- Part B: real topic folders, authored files only
RUN = {".py", ".sh", ".bash", ".zsh", ".sql", ".js", ".ts", ".mjs", ".rs", ".go", ".rb", ".pl"}
PROSE = {".md", ".markdown", ".rst"}
SKIP = cf.SKIP_DIRS | {"target", "dist", "build", "vendor", "site-packages"}


def files_of(topic):
    for root, dirs, fs in os.walk(topic):
        dirs[:] = [d for d in dirs if d not in SKIP and not os.path.exists(os.path.join(root, d, ".git"))
                   and not os.path.exists(os.path.join(root, d, "pyvenv.cfg"))]
        for fn in fs:
            p = os.path.join(root, fn)
            if not os.path.islink(p) and not cf.is_secret_name(fn):
                yield p, os.path.splitext(fn)[1].lower()


def part_b():
    known = env_values(ENV_FILE)
    rows = []
    for day in sorted(os.listdir(TMP_ROOT)):
        dp = os.path.join(TMP_ROOT, day)
        if not (re.fullmatch(r"\d{8}", day) and os.path.isdir(dp)):
            continue
        for t in sorted(os.listdir(dp)):
            tp = os.path.join(dp, t)
            if not os.path.isdir(tp) or t.startswith("grill--61"):
                continue
            s = {"run_files": 0, "prose_files": 0, "run_lines": 0, "prose_lines": 0}
            sets = {"run_proto": set(), "prose_proto": set(), "run_broad": set(), "prose_broad": set()}
            hits = {"run": 0, "prose": 0}
            for p, ext in files_of(tp):
                cls = "run" if ext in RUN else "prose" if ext in PROSE else None
                if not cls:
                    continue
                try:
                    if os.path.getsize(p) > 2_000_000:
                        continue
                    text = open(p, "rb").read().decode("utf-8")
                except (OSError, UnicodeDecodeError):
                    continue
                s[cls + "_files"] += 1
                for l in text.splitlines():
                    s[cls + "_lines"] += 1
                    low = l.lower()
                    hits[cls] += sum(1 for v in known if v in low)
                    sets[cls + "_proto"].update(v.lower() for v in proto_extract(l) if v.lower() not in known)
                    sets[cls + "_broad"].update(v.lower() for v in broad_extract(l) if v.lower() not in known)
            if s["run_files"] + s["prose_files"]:
                rows.append({**s, **{k: len(v) for k, v in sets.items()},
                             "known_hits_run": hits["run"], "known_hits_prose": hits["prose"]})

    def dist(k):
        v = sorted(r[k] for r in rows)
        return {"median": statistics.median(v), "p90": v[int(len(v) * .9)], "max": v[-1], "sum": sum(v)}

    return {"topic_folders": len(rows),
            **{k: dist(k) for k in ("run_files", "run_lines", "prose_files", "prose_lines", "run_proto", "run_broad",
                                     "prose_proto", "prose_broad", "known_hits_run", "known_hits_prose")},
            "folders_with_a_known_value": sum(1 for r in rows if r["known_hits_run"] + r["known_hits_prose"])}


print(json.dumps({"fixture": part_a(), "real_topic_folders": part_b()}, indent=1))
