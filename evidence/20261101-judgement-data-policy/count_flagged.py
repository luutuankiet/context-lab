#!/usr/bin/env python3
"""Count lines the scanner's candidate extractor flags in a directory. Counts only.

  python3 -I count_flagged.py DIR [--exclude REL/PATH]... [--anon-folders]
  python3 -I - DIR ... < count_flagged.py     (nothing is written anywhere)

Stdlib only. No network. Prints no matched value, line, file content, or path below
the top-level folder name. --anon-folders replaces those names with folder-NN too.
"""
import fnmatch, json, os, re, sys

# ---- copied unchanged from research-typed-llm/trial.py; verify_extractor.py checks the match ----
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
# ---- end of copied code ----


SKIP_DIRS = {".git", "node_modules", ".venv", "venv", "virtualenv", "__pycache__", ".tox", ".mypy_cache",
             ".pytest_cache", ".ruff_cache"}
MAX_BYTES = 5 * 1024 * 1024
SAFE_EXT = re.compile(r"^\.[A-Za-z0-9_+-]{1,10}$")


def is_secret_name(name):
    """Never open these, even to count: a line count is not worth touching key material."""
    n = name.lower()
    return (n == ".env" or n.startswith(".env.") or n.endswith((".env", ".pem", ".key", ".p12", ".pfx"))
            or n.startswith("id_rsa") or n.startswith("client_secret"))


def parse_gitignore(path):
    rules = []
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for raw in f:
                p = raw.rstrip("\r\n")
                if not p.strip() or p.startswith("#"):
                    continue
                neg = p.startswith("!")
                p = p[1:] if neg else p
                dir_only = p.endswith("/")
                p = p.rstrip("/")
                anchored = "/" in p
                rules.append((neg, dir_only, anchored, p.lstrip("/")))
    except OSError:
        pass
    return rules


def rule_matches(rule, rel, is_dir):
    _, dir_only, anchored, pat = rule
    if dir_only and not is_dir:
        return False
    if anchored:
        if fnmatch.fnmatchcase(rel, pat):
            return True
        if pat.startswith("**/"):
            tail = pat[3:]
            return any(fnmatch.fnmatchcase("/".join(rel.split("/")[i:]), tail) for i in range(rel.count("/") + 1))
        return False
    return fnmatch.fnmatchcase(rel.rsplit("/", 1)[-1], pat)


def ignored(stack, full, is_dir):
    """stack: (base_dir, rules), outermost first. Last matching rule wins, as in git."""
    verdict = False
    for base, rules in stack:
        rel = os.path.relpath(full, base).replace(os.sep, "/")
        for r in rules:
            if rule_matches(r, rel, is_dir):
                verdict = not r[0]
    return verdict


def blank():
    return {"files": 0, "lines": 0, "flagged": 0, "candidates": 0, "flagged_chars": 0}


def add(d, key, st):
    b = d.setdefault(key, blank())
    for k in b:
        b[k] += st[k]


def scan_file(path):
    with open(path, "rb") as f:
        data = f.read()
    if b"\0" in data[:8192]:
        return None
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return None
    st = blank()
    st["files"] = 1
    for line in text.splitlines():
        st["lines"] += 1
        n = len(extract(line))
        if n:
            st["flagged"] += 1
            st["candidates"] += n
            st["flagged_chars"] += len(line)
    return st


def walk(root, excludes):
    by_top, by_ext, totals = {}, {}, {}
    skipped = {"binary": 0, "over_5mb": 0, "gitignored_files": 0, "gitignored_dirs": 0, "skip_dirs": 0,
               "virtualenv_dirs": 0, "secret_named": 0, "symlinks": 0, "unreadable": 0, "excluded_paths": 0}

    def rec(d, stack):
        gi = os.path.join(d, ".gitignore")
        if os.path.isfile(gi):
            stack = stack + [(d, parse_gitignore(gi))]
        try:
            entries = sorted(os.scandir(d), key=lambda e: e.name)
        except OSError:
            skipped["unreadable"] += 1
            return
        for e in entries:
            rel = os.path.relpath(e.path, root).replace(os.sep, "/")
            if rel in excludes:
                skipped["excluded_paths"] += 1
                continue
            if e.is_symlink():
                skipped["symlinks"] += 1
                continue
            if e.is_dir():
                if e.name in SKIP_DIRS:
                    skipped["skip_dirs"] += 1
                elif os.path.exists(os.path.join(e.path, "pyvenv.cfg")):
                    skipped["virtualenv_dirs"] += 1
                elif ignored(stack, e.path, True):
                    skipped["gitignored_dirs"] += 1
                else:
                    rec(e.path, stack)
                continue
            if not e.is_file():
                continue
            if is_secret_name(e.name):
                skipped["secret_named"] += 1
            elif ignored(stack, e.path, False):
                skipped["gitignored_files"] += 1
            else:
                try:
                    if e.stat().st_size > MAX_BYTES:
                        skipped["over_5mb"] += 1
                        continue
                    st = scan_file(e.path)
                except OSError:
                    skipped["unreadable"] += 1
                    continue
                if st is None:
                    skipped["binary"] += 1
                    continue
                top = rel.split("/", 1)[0] if "/" in rel else "(files at root)"
                ext = os.path.splitext(e.name)[1].lower()
                ext = ext if SAFE_EXT.match(ext) else ("(none)" if not ext else "(other)")
                add(by_top, top, st); add(by_ext, ext, st); add(totals, "t", st)

    rec(root, [])
    return totals.get("t", blank()), by_top, by_ext, skipped


def finish(b):
    return {"files": b["files"], "lines": b["lines"], "flagged": b["flagged"], "candidates": b["candidates"],
            "ratio": round(b["flagged"] / b["lines"], 4) if b["lines"] else None,
            "candidates_per_flagged": round(b["candidates"] / b["flagged"], 2) if b["flagged"] else None,
            "chars_per_flagged": round(b["flagged_chars"] / b["flagged"], 1) if b["flagged"] else None}


def main():
    args = sys.argv[1:]
    excludes, anon, root = set(), False, None
    while args:
        a = args.pop(0)
        if a == "--exclude":
            excludes.add(args.pop(0).strip("/"))
        elif a == "--anon-folders":
            anon = True
        else:
            root = a
    if not root or not os.path.isdir(root):
        sys.exit("directory not found")
    total, by_top, by_ext, skipped = walk(os.path.abspath(root), excludes)
    tops = sorted(by_top, key=lambda k: -by_top[k]["lines"])
    names = {k: (f"folder-{i + 1:02d}" if anon else k) for i, k in enumerate(tops)}
    print(json.dumps({"total": finish(total),
                      "by_top": {names[k]: finish(by_top[k]) for k in tops},
                      "by_ext": {k: finish(by_ext[k]) for k in sorted(by_ext, key=lambda k: -by_ext[k]["lines"])},
                      "skipped": skipped}, indent=1))


if __name__ == "__main__":
    main()
