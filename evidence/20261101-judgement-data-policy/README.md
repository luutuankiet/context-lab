# Snapshot, not maintained

Evidence for "Judgement tier data policy: where may real workspace text be sent"
(issue 61). Every value in the fixture is fictional.

| file | what it does |
|---|---|
| `make_fixture.py` | builds the synthetic fixture and its answer key: 59 planted identifiers, 56 decoys |
| `count_flagged.py` | the broad candidate extractor, plus a counter that prints counts only |
| `plain_tier_test.py` | scores the free extractors on the fixture, and counts candidates per real topic folder |
| `agent_judge.py` | prepares a candidate list for a blind agent, then scores its verdicts |

## Rebuild

Run from this folder. `TMP_ROOT` is a repo's `tmp/` and `ENV_FILE` its `.env`. Nothing
is sent anywhere.

```sh
python3 -I make_fixture.py
python3 -I plain_tier_test.py "$TMP_ROOT" "$ENV_FILE" fixture answer-key.json count_flagged.py
python3 -I agent_judge.py prepare fixture count_flagged.py judge
python3 -I agent_judge.py score judge answer-key.json
```

`score` needs `judge/verdicts.json`. To produce it, give a fresh agent only
`judge/candidates.json` and `judge/fixture/`, and have it mark each candidate private
or not. Keep the answer key out of its reach.

## Measured

Fixture, one run each:

| method | flagged | precision | recall |
|---|---:|---:|---:|
| prototype's seven shapes | 53 | 0.75 | 0.61 |
| broad extractor alone | 92 | 0.62 | 0.97 |
| broad extractor plus blind agent | 57 | 0.98 | 0.95 |

The blind agent's verdicts depend on the agent and will differ on a rerun, so its raw
file is not kept here.

17 real topic folders, distinct candidates per folder, excluding values already in `.env`:

| files | extractor | median | p90 | max |
|---|---|---:|---:|---:|
| runnable | seven shapes | 1 | 35 | 956 |
| runnable | broad | 30 | 154 | 25,573 |
| prose | seven shapes | 2 | 92 | 257 |
| prose | broad | 125 | 1,421 | 3,567 |

One folder holds 11,227 of the 11,274 runnable files and probably sets the runnable
maximums. No real line was read, so these counts say nothing about accuracy on real text.
