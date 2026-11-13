"""Turn a Teams transcript JSON (streamContent?format=json) into markdown
grouped by speaker turn, each turn stamped with its start time.

Usage: python3 -I to_markdown.py transcript.json transcript.md "Meeting title"
"""
import json
import sys

src, dst, title = sys.argv[1], sys.argv[2], sys.argv[3]
entries = json.load(open(src, encoding="utf-8-sig"))["entries"]

lines = [f"# {title}", ""]
speaker, buf, start = None, [], None


def flush():
    if buf:
        lines.extend([f"**{speaker}** `{start}`", "", " ".join(buf).strip(), ""])


for e in entries:
    who = e.get("speakerDisplayName") or "Unknown"
    if who != speaker:
        flush()
        buf = []
        speaker, start = who, e["startOffset"].split(".")[0]
    buf.append(e["text"].strip())
flush()

with open(dst, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print(f"{len(entries)} entries -> {dst}")
