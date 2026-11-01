#!/usr/bin/env python3
"""Score a driving agent as the judge, on the synthetic fixture only.

  prepare FIXTURE EXTRACTOR OUTDIR     copy the fixture, write candidates.json (no answer key)
  score   OUTDIR ANSWER_KEY            score OUTDIR/verdicts.json against the key

Verdicts: [{"id": N, "private": true|false}], plus optional "extra":
[{"file":..., "line":..., "value":...}] for identifiers the extractor missed.
"""
import importlib.util, json, os, shutil, sys

mode = sys.argv[1]


def norm(s):
    return s.lower()


if mode == "prepare":
    fixture, extractor, out = sys.argv[2:5]
    spec = importlib.util.spec_from_file_location("count_flagged", extractor)
    cf = importlib.util.module_from_spec(spec)
    sys.argv = ["x"]
    spec.loader.exec_module(cf)
    shutil.rmtree(os.path.join(out, "fixture"), ignore_errors=True)
    shutil.copytree(fixture, os.path.join(out, "fixture"))
    seen, cands = set(), []
    for root, _, fs in sorted(os.walk(fixture)):
        for fn in sorted(fs):
            p = os.path.join(root, fn)
            rel = os.path.relpath(p, fixture)
            for i, l in enumerate(open(p, encoding="utf-8").read().splitlines(), 1):
                for c in cf.extract(l):
                    k = (rel, i, c["value"])
                    if k not in seen:
                        seen.add(k)
                        cands.append({"id": len(cands), "file": rel, "line": i, "value": c["value"], "shape": c["shape"]})
    json.dump(cands, open(os.path.join(out, "candidates.json"), "w"), indent=1)
    print(len(cands), "candidates")
else:
    out, keyf = sys.argv[2:4]
    key = json.load(open(keyf))
    planted = [k for k in key if k["planted"]]
    cands = {c["id"]: c for c in json.load(open(os.path.join(out, "candidates.json")))}
    v = json.load(open(os.path.join(out, "verdicts.json")))
    verdicts = v["verdicts"] if isinstance(v, dict) else v
    extra = v.get("extra", []) if isinstance(v, dict) else []

    def hit(file, line, value):
        return [k for k in planted if k["file"] == file and k["line"] == line
                and (norm(k["value"]) in norm(value) or norm(value) in norm(k["value"]))]

    def report(flagged):
        found, fp, fps = set(), 0, []
        for f, l, val in flagged:
            m = hit(f, l, val)
            if m:
                found.update((k["file"], k["line"], k["value"]) for k in m)
            else:
                fp += 1
                fps.append(val)
        missed = {}
        for k in planted:
            if (k["file"], k["line"], k["value"]) not in found:
                missed[k["kind"]] = missed.get(k["kind"], 0) + 1
        return {"flagged": len(flagged), "false_positive": fp, "found": len(found),
                "precision": round((len(flagged) - fp) / len(flagged), 3) if flagged else None,
                "recall": round(len(found) / len(planted), 3), "missed_by_kind": missed, "false_positives": fps}

    flagged = [(cands[x["id"]]["file"], cands[x["id"]]["line"], cands[x["id"]]["value"]) for x in verdicts if x["private"]]
    print(json.dumps({"judged": len(verdicts), "candidates": len(cands),
                      "candidates_only": report(flagged),
                      "with_extra": report(flagged + [(e["file"], e["line"], e["value"]) for e in extra])}, indent=1))
