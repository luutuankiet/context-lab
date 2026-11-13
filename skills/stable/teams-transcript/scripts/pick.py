"""From a media/transcripts listing, print "<id>\\t<display name>" for the
transcript to fetch: the one whose id was asked for, else the default one,
else the first. Prints nothing when the listing is empty.

Usage: python3 -I pick.py transcripts-list.json [wanted-id]
"""
import json
import sys

items = json.load(open(sys.argv[1], encoding="utf-8-sig")).get("value", [])
want = sys.argv[2] if len(sys.argv) > 2 else ""
hit = [t for t in items if t["id"] == want] if want else []
hit = hit or [t for t in items if str(t.get("isDefault")).lower() == "true"] or items
if hit:
    t = hit[0]
    name = t.get("displayName", "transcript").rsplit(".", 1)[0]
    print(t["id"] + "\t" + name)
