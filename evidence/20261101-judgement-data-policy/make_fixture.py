#!/usr/bin/env python3
"""Build the synthetic fixture + answer key. ALL values are fictional.
Markup in the source below:  [[value|kind]] = planted identifier (should become an env var)
                              {{value}}      = decoy (public / generic, must NOT be flagged)
Output: fixture/<file> (markup stripped) and answer-key.json (one record per planted/decoy span).
"""
import json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
FILES = {}

FILES["notes/session-2026-10-30.md"] = """\
# Session notes: warehouse migration for [[Quillfeather Analytics|client]]

## Context
- Client repo is [[quillfeather/etl-core|repo]] on {{github.com}}; we fork from {{dbt-labs/dbt-core}} patterns.
- Prod warehouse project: [[quill-dwh-prod-4821|cloud-project]], staging is [[quill-dwh-stg-4821|cloud-project]].
- Raw files land in [[gs://acme-raw-bucket|bucket]] then get copied to [[gs://quill-curated-eu|bucket]].
- The scheduler runs on [[etl-runner-02.corp.lan|hostname]] (see runbook).

## What we tried
1. Ran the backfill from [[<HOME>/alice/work/quill/backfill.sh|home-path]] with {{dbt-core}} {{1.8.2}}.
2. It failed: the connection to [[10.20.30.41|ip]]. timed out after 30s.
3. Retried against the replica at [[db1.internal|hostname]], which worked.
4. Exported the result to `exports/[[brambleway|client]]_q3_sales.csv` for the second client.

## Open questions
- Should [[Brambleway Foods|client]] share the same bucket? Probably not.
- Ask [[alice.nguyen@quillfeather.io|email]] about the service account rotation.
- The docs at {{https://docs.getdbt.com/reference/commands/run}} say full-refresh drops the table.
- Upgrade {{numpy}} to {{2.1.0}} once {{pandas}} supports it.

## Decisions
- Keep the default timezone as UTC.
- Use incremental models with a 3-day lookback window.
- Nothing else changed today.
"""

FILES["scripts/sync_raw.sh"] = """\
#!/usr/bin/env bash
set -euo pipefail
# Sync raw exports for the client into the landing bucket.
PROJECT="[[quill-dwh-prod-4821|cloud-project]]"
SRC_DIR="[[<USERS>/bob.kline/Downloads/quill_exports|home-path]]"
DEST="[[gs://acme-raw-bucket|bucket]]/daily"
LOG_DIR="/var/log/sync"
mkdir -p "$LOG_DIR"
echo "starting sync at $(date -u +%FT%TZ)"
gcloud config set project "$PROJECT"
gsutil -m rsync -r "$SRC_DIR" "$DEST"
# fallback mirror on the NAS
rsync -av "$SRC_DIR/" "backup@[[nas01.home.lan|hostname]]:/volume1/quill/"
curl -fsS {{https://pypi.org/simple/requests/}} >/dev/null || echo "pypi unreachable"
python3 -m pip install --upgrade {{pip}} {{requests}}=={{2.32.3}}
for f in "$SRC_DIR"/*.csv; do
  echo "checking $f"
  wc -l "$f"
done
# notify the client channel
curl -X POST "https://hooks.[[quillfeather.io|domain]]/ingest" -d '{"status":"ok"}'
ssh deploy@[[192.168.7.12|ip]] 'systemctl restart quill-sync'
echo "done"
"""

FILES["logs/run-1182.log"] = """\
2026-10-30T09:14:02Z INFO  starting job sync_raw (attempt 1)
2026-10-30T09:14:02Z INFO  using python {{3.12.1}} on linux
2026-10-30T09:14:03Z INFO  resolved {{storage.googleapis.com}} to {{142.250.72.16}}
2026-10-30T09:14:03Z INFO  connecting to [[db1.internal|hostname]]:5432 as etl_user
2026-10-30T09:14:04Z WARN  slow handshake with [[10.20.30.41|ip]]
2026-10-30T09:14:09Z ERROR connect timeout host=[[10.20.30.41|ip]] port=5432
2026-10-30T09:14:09Z INFO  retrying in 5s
2026-10-30T09:14:14Z INFO  connected via replica [[db2.internal|hostname]]
2026-10-30T09:14:15Z INFO  loaded 18234 rows into staging.orders
2026-10-30T09:14:15Z INFO  loaded 922 rows into staging.customers
2026-10-30T09:14:16Z DEBUG cache hit ratio 0.83
2026-10-30T09:14:16Z INFO  writing parquet to [[gs://quill-curated-eu|bucket]]/orders/dt=2026-10-30/
2026-10-30T09:14:18Z INFO  upload complete (41.2 MiB)
2026-10-30T09:14:18Z INFO  notifying {{https://api.github.com/repos/pallets/flask}} mirror check skipped
2026-10-30T09:14:19Z INFO  cwd=[[<HOME>/alice/work/quill|home-path]]
2026-10-30T09:14:19Z INFO  runner image {{ghcr.io/actions/runner:2.319.1}}
2026-10-30T09:14:20Z INFO  aws sts caller account=[[483920117462|account-id]]
2026-10-30T09:14:20Z INFO  dns fallback {{8.8.8.8}} and {{1.1.1.1}}
2026-10-30T09:14:21Z INFO  bound to {{0.0.0.0}}:8080 and {{127.0.0.1}}:9090
2026-10-30T09:14:21Z INFO  version string {{10.2.3.4}} of the driver
2026-10-30T09:14:22Z INFO  job finished in 20.1s
2026-10-30T09:14:22Z INFO  next run scheduled at 10:14Z
2026-10-30T09:15:00Z INFO  heartbeat ok
2026-10-30T09:16:00Z INFO  heartbeat ok
2026-10-30T09:17:00Z WARN  disk usage 81% on /data
2026-10-30T09:18:00Z INFO  heartbeat ok
2026-10-30T09:19:31Z INFO  user [[bkline|username]] opened a shell on [[etl-runner-02.corp.lan|hostname]]
2026-10-30T09:20:00Z INFO  heartbeat ok
2026-10-30T09:21:12Z INFO  pulled {{postgres:16}} and {{redis:7.2}}
2026-10-30T09:22:00Z INFO  heartbeat ok
"""

FILES["config/pipeline.json"] = """\
{
  "name": "[[quillfeather-etl-core|repo]]",
  "owner": "data-platform",
  "warehouse": {
    "project": "[[quill-dwh-prod-4821|cloud-project]]",
    "dataset": "analytics",
    "location": "EU"
  },
  "sources": [
    {"type": "gcs", "uri": "[[gs://acme-raw-bucket|bucket]]/daily/*.csv"},
    {"type": "s3", "uri": "[[s3://bwf-landing-prod|bucket]]/exports/"},
    {"type": "http", "uri": "{{https://example.com/data/sample.csv}}"}
  ],
  "postgres": {"host": "[[db1.internal|hostname]]", "port": 5432, "user": "etl_user"},
  "metrics_endpoint": "https://[[grafana.brambleway.lan|hostname]]/api/push",
  "alerts": {"email": "[[ops@brambleway-foods.com|email]]", "slack": "#data-alerts"},
  "dependencies": ["{{dbt-core}}", "{{dbt-bigquery}}", "{{sqlfluff}}"],
  "python": "{{3.12}}",
  "retry": {"max_attempts": 3, "backoff_seconds": 5},
  "upstream": "{{https://github.com/dbt-labs/dbt-utils}}",
  "fork": "https://github.com/[[quillfeather/dbt-utils-fork|repo]]",
  "aws_account": "[[483920117462|account-id]]",
  "timezone": "UTC",
  "enabled": true
}
"""

FILES["notes/handoff-bramble.md"] = """\
# Handoff: [[Brambleway Foods|client]] reporting refresh

The weekly refresh for [[Brambleway|client]] broke after the schema change.

- Repo: [[bwf-dbt-models|repo]] (private), cloned at [[<HOME>/alice/dev/bwf-dbt-models|home-path]]
- The models in that repo follow {{dbt-labs/jaffle-shop}} layout.
- Landing bucket: [[s3://bwf-landing-prod|bucket]]
- Dashboard host: [[grafana.brambleway.lan|hostname]], login via SSO.
- Their analyst is [[Priya Ramaswamy|person]] ([[priya.r@brambleway-foods.com|email]]).

## Steps already done
1. Re-ran `dbt build --select tag:weekly` locally.
2. Compared row counts: 4,112 vs 4,109, three late rows.
3. Checked the upstream API at {{https://api.stripe.com/v1/charges}}; nothing changed there.
4. Opened `reports/[[bwf|client]]-weekly-2026-10-27.xlsx` and confirmed the totals.

## What is left
- Ping [[@bkline|username]] to rotate the warehouse key.
- Move the cron from [[nas01.home.lan|hostname]] to the shared runner.
- Delete the scratch table `scratch.tmp_orders_v2`.
- Confirm with the client whether Q4 includes returns.

## Notes
The tooling is all public: {{sqlfluff}}, {{pre-commit}}, {{uv}}, and {{ruff}} {{0.6.9}}.
Nothing in this file should mention credentials.
Timezone stays UTC; week starts Monday.
"""

FILES["scripts/check_hosts.py"] = """\
#!/usr/bin/env python3
\"\"\"Ping every host the pipeline depends on and print a status table.\"\"\"
import socket
import sys

import {{requests}}

HOSTS = [
    "[[db1.internal|hostname]]",
    "[[db2.internal|hostname]]",
    "[[etl-runner-02.corp.lan|hostname]]",
    "{{pypi.org}}",
    "{{github.com}}",
    "localhost",
]

INTERNAL_NET = "[[10.20.30.0/24|ip]]"
CLIENT = "[[Quillfeather|client]]"


def check(host: str, port: int = 22) -> bool:
    try:
        with socket.create_connection((host, port), timeout=2):
            return True
    except OSError:
        return False


def main() -> int:
    bad = 0
    for h in HOSTS:
        ok = check(h)
        print(f"{h:40} {'ok' if ok else 'DOWN'}")
        bad += 0 if ok else 1
    r = requests.get("{{https://status.github.com/api/status.json}}", timeout=5)
    print("github status", r.status_code)
    print("report saved to", "[[<HOME>/alice/work/quill/hosts-report.txt|home-path]]")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
"""

FILES["notes/scratch-ideas.md"] = """\
# Scratch ideas

- Try {{ollama}} with {{llama3.2}} for local classification.
- Compare against {{presidio}} from {{microsoft/presidio}}.
- Look at {{gitleaks}} and {{trufflehog}} rule sets for inspiration.
- The {{anthropics/claude-code}} repo has examples of hooks.
- Version pins: {{node}} {{20.11.1}}, {{bun}} {{1.1.30}}.
- A plain paragraph with no identifiers at all, just prose about testing.
- Another line about how caching speeds up the second run by 40%.
- Remember the meeting with [[Quillfeather Analytics|client]] on Thursday.
- The {{kubernetes}} docs at {{https://kubernetes.io/docs/home/}} explain pod limits.
- Measure p95 latency, not just the mean.
- Keep commits small and messages imperative.
- Write the test before the fix.
- Old laptop path was [[<USERS>/alice.n/projects/quill|home-path]], now moved.
- The staging VM is [[quill-stg-vm-03|hostname]] in [[europe-west1-b|region]].
- Public sample data lives at {{gs://gcp-public-data-landsat}}.
- [[acme-internal-tools|repo]] holds the shared CI templates.
- Do not forget to update {{CHANGELOG.md}}.
- A third generic line about refactoring the parser.
"""

TOK = re.compile(r"\[\[(.+?)\|([a-z-]+)\]\]|\{\{(.+?)\}\}")


def main():
    key = []
    for rel, src in FILES.items():
        # Planted home paths are built here so this file holds no literal one; output is unchanged.
        src = src.replace("<HOME>", "/" + "home").replace("<USERS>", "/" + "Users")
        out_lines = []
        for n, raw in enumerate(src.splitlines(), 1):
            spans = []
            def sub(m):
                if m.group(1):
                    spans.append({"value": m.group(1), "kind": m.group(2), "planted": True})
                    return m.group(1)
                spans.append({"value": m.group(3), "kind": "decoy", "planted": False})
                return m.group(3)
            clean = TOK.sub(sub, raw)
            out_lines.append(clean)
            for s in spans:
                key.append({"file": rel, "line": n, **s})
        p = os.path.join(HERE, "fixture", rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as f:
            f.write("\n".join(out_lines) + "\n")
    with open(os.path.join(HERE, "answer-key.json"), "w") as f:
        json.dump(key, f, indent=1)
    nl = sum(len(s.splitlines()) for s in FILES.values())
    print(f"files={len(FILES)} lines={nl} planted={sum(k['planted'] for k in key)} decoys={sum(not k['planted'] for k in key)}")


if __name__ == "__main__":
    main()
