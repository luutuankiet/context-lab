#!/usr/bin/env bash
# Download a Teams meeting transcript through SharePoint's media API, as JSON,
# VTT and speaker-grouped markdown. Needs only curl and python3.
#
#   fetch.sh --from-curl request.txt [--out DIR] [--key TRANSCRIPT_ID]
#   fetch.sh --url URL --token-file FILE [--out DIR] [--key TRANSCRIPT_ID]
#   TEAMS_TOKEN=... fetch.sh --url URL [--out DIR]
#
# URL is any request the recap player made that contains
# /drives/<drive>/items/<item> on a *.sharepoint.com host; the player's
# cdnmedia/transcripts request is the usual one. request.txt is that request
# exported with the browser's "Copy as cURL". The token is a SharePoint bearer
# token (three dot-separated parts); it is read from a file or the environment,
# never from argv, and is written only to a mode-600 temp file removed on exit.
#
# Written for bash 3.2 under set -euo pipefail.
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CURL_FILE='' URL='' TOKEN_FILE='' OUT='.' KEY=''

usage() { sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
die() { printf 'fetch.sh: %s\n' "$1" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --from-curl)  CURL_FILE=$2; shift 2 ;;
    --url)        URL=$2; shift 2 ;;
    --token-file) TOKEN_FILE=$2; shift 2 ;;
    --key)        KEY=$2; shift 2 ;;
    --out)        OUT=$2; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *)            usage >&2; exit 2 ;;
  esac
done

TOKEN=${TEAMS_TOKEN:-}
if [ -n "$CURL_FILE" ]; then
  [ -f "$CURL_FILE" ] || die "no such file: $CURL_FILE"
  [ -n "$URL" ] || URL=$(grep -o "https://[^'\" ]*sharepoint\.com[^'\" ]*" "$CURL_FILE" | head -1 || true)
  [ -n "$TOKEN" ] || TOKEN=$(grep -o -i "authorization: *Bearer [A-Za-z0-9._-]*" "$CURL_FILE" | head -1 | sed 's/.*[Bb]earer //' || true)
fi
if [ -z "$TOKEN" ] && [ -n "$TOKEN_FILE" ]; then
  TOKEN=$(sed 's/^[[:space:]]*\(Authorization:[[:space:]]*\)\{0,1\}[Bb]earer[[:space:]]*//' "$TOKEN_FILE" | tr -d '[:space:]')
fi

[ -n "$URL" ]   || die "no SharePoint URL: pass --url or --from-curl"
[ -n "$TOKEN" ] || die "no token: pass --from-curl, --token-file or TEAMS_TOKEN"

dots=$(printf '%s' "$TOKEN" | tr -cd '.' | wc -c | tr -d ' ')
[ "$dots" = 2 ] || die "token has $((dots + 1)) parts, a whole one has 3: it was cut short when copied"

HOST=$(printf '%s' "$URL" | sed -n 's#^\(https://[^/]*\)/.*#\1#p')
DRIVE=$(printf '%s' "$URL" | sed -n 's#.*/drives/\([^/?]*\)/items/.*#\1#p')
ITEM=$(printf '%s' "$URL" | sed -n 's#.*/drives/[^/?]*/items/\([^/?]*\).*#\1#p')
[ -n "$KEY" ] || KEY=$(printf '%s' "$URL" | sed -n 's#.*[?&]transcriptkey=\([^&]*\).*#\1#p')
[ -n "$HOST" ] && [ -n "$DRIVE" ] && [ -n "$ITEM" ] || die "URL has no /drives/<drive>/items/<item>: $URL"

umask 077
HDR=$(mktemp)
trap 'rm -f "$HDR"' EXIT
printf 'Authorization: Bearer %s\n' "$TOKEN" > "$HDR"
unset TOKEN TEAMS_TOKEN

mkdir -p "$OUT"
BASE="$HOST/_api/v2.1/drives/$DRIVE/items/$ITEM/media/transcripts"

get() { # get <url> <outfile>; prints the HTTP status
  curl -sS --connect-timeout 15 --max-time 120 -H @"$HDR" -o "$2" -w '%{http_code}' "$1" || true
}

code=$(get "$BASE" "$OUT/transcripts-list.json")
case "$code" in
  200) ;;
  000) die "no answer from $HOST (network or TLS timeout); retry" ;;
  401) die "401 listing transcripts: the token expired (about 1 hour) or is not a SharePoint token" ;;
  403|404) die "$code listing transcripts: this account cannot read the recording, or the URL is not the recording file" ;;
  *) die "HTTP $code listing transcripts; body in $OUT/transcripts-list.json" ;;
esac

TAB=$(printf '\t')
pick=$(python3 -I "$HERE/pick.py" "$OUT/transcripts-list.json" "$KEY")
[ -n "$pick" ] || die "the recording has no transcript (listing is empty)"
KEY=${pick%%"$TAB"*}
TITLE=${pick#*"$TAB"}
rm -f "$OUT/transcripts-list.json"   # it carries signed download URLs

for fmt in json vtt; do
  code=$(get "$BASE/$KEY/streamContent?format=$fmt" "$OUT/transcript.$fmt")
  [ "$code" = 200 ] || die "HTTP $code downloading format=$fmt"
done

python3 -I "$HERE/to_markdown.py" "$OUT/transcript.json" "$OUT/transcript.md" "$TITLE"
printf 'saved: %s/transcript.{json,vtt,md}\n' "$OUT"
