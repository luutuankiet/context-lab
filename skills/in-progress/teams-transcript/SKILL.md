---
name: teams-transcript
description: "Download a Microsoft Teams meeting transcript as text (JSON, VTT, markdown) when the recap's Download button is greyed out or missing. Use when asked to get, save or pull a Teams transcript or meeting recap into notes or project context."
---

# Teams transcript download

**Goal:** `transcript.json`, `transcript.vtt` and a speaker-grouped
`transcript.md` on disk, for a meeting the user can already read in the Teams
Recap → Transcript panel.

**Prerequisite:** the user is signed in to Teams on the web
(`teams.cloud.microsoft` or `teams.microsoft.com`) in a browser. The desktop app
hides its network calls; ask them to open the same meeting in the browser.

**Respect the policy.** A greyed-out Download usually means the organizer
turned downloads off. Tell the user so before you start, and keep the result
in a gitignored working folder for their own use.

## How it works

The browser never downloads a file. The recap player reads the transcript from
SharePoint, where the recording lives, and two facts decide the route:

| request | auth | body | use it? |
|---|---|---|---|
| `.../items/<item>/cdnmedia/transcripts?...P1=..&P4=..&kid=..` (what the panel calls) | none: the URL is pre-signed | **encrypted** (random bytes, `kid` = key id) | no; only mine its URL for ids |
| `.../_api/v2.1/drives/<drive>/items/<item>/media/transcripts[/<id>/streamContent?format=json\|vtt]` | `Authorization: Bearer <SharePoint token>` | plain JSON or VTT | **yes** |

Cookies do not open the second request: Teams web signs in to SharePoint with a
bearer token, so a browser tab on that URL says `unauthenticated`. What the
agent needs from the browser is **one request**: its URL (drive id, item id,
`transcriptkey`) and its bearer token. Everything after that is `curl`, done by
[`scripts/fetch.sh`](scripts/fetch.sh).

The token expires about an hour after Teams issues it. On `401`, grab a fresh
one; the ids stay valid.

## Steps

1. **Make a working folder** outside version control, e.g.
   `<repo>/tmp/YYYYMMDD/teams-transcript/`. Done when it exists and
   `git check-ignore` confirms it is ignored.
2. **Get one request with its token.** Take route A when you hold a browser
   tool that lists network requests; otherwise route B. Done when a file holds
   the request URL and a token whose three dot-separated parts are all there.
3. **Fetch.** From the working folder:

   ```sh
   <skill-dir>/scripts/fetch.sh --from-curl request.txt --out .
   # or: fetch.sh --url '<request url>' --token-file token.txt --out .
   ```

   Done when it prints `saved: ./transcript.{json,vtt,md}`.
4. **Check the result against the panel.** The first lines of `transcript.md`
   match the first lines the user sees in the Transcript panel, and the last
   entry's `endOffset` is close to the meeting length.
5. **Delete every file holding the token** (`request.txt`, `token.txt`, any
   saved request capture). Done when
   `grep -rlE 'eyJ0eXAi|[Bb]earer ' .` finds nothing.

### Route A: the agent drives the browser

Shown with a Firefox automation tool that exposes `list_network_requests`,
`get_network_request` and `navigate_page`; any tool with the same three
abilities works the same way.

1. Open the user's Teams tab on the meeting's **Recap** view. The network log
   starts only when the tool attaches and rolls over after a while, so **reload
   the tab** (navigate to the same URL) right before you look; Teams reopens the
   last chat and the recap refetches. Wait until the tab title names the meeting.
2. `list_network_requests` filtered on `sharepoint.com`, saved to a file, and
   pick from it by script. Take request ids from the listing and fetch details
   by id; lookup by URL substring can miss. The ids come from the
   `cdnmedia/transcripts` request (it also carries `transcriptkey`), or, if the
   panel has not fetched it yet, from any request whose URL holds
   `/drives/<drive>/items/<item>`.
3. Find the token. The panel's request sends it as `x-authorization`, but a
   tool may **shorten long header values** when it prints or saves them: a
   token with more or fewer than three parts was cut. The whole token also rides
   in the fragment of the player frame's request, filtered on `streamembed.aspx`:
   `...#access_token=<token>&...`.
4. Save the request to disk rather than into the conversation (the tool's
   save-to-file option), then pull the token out with a script that writes it
   to `token.txt` and prints only its part count:

   ```sh
   python3 -I -c 'import json,sys,urllib.parse as u
   r=json.load(open(sys.argv[1])); t=u.parse_qs(r["url"].split("#",1)[1])["access_token"][0]
   open("token.txt","w").write(t); print(len(t.split(".")),"parts")' request-capture.json
   ```

5. Step 3 above, with `--url '<request url>' --token-file token.txt`.

The recap panel sits in a cross-origin frame, so scripts run in the Teams page
cannot read its requests or its token; take them from the network log.

### Route B: the user drives, the agent coaches

Give the user these steps, word for word:

1. In the browser, open the meeting, then **Recap → Transcript**.
2. Press `F12`, open the **Network** tab, then reload the page.
3. In the filter box type `cdnmedia/transcripts` and wait for one row.
4. Right-click the row → **Copy Value → Copy as cURL** (Firefox) or
   **Copy → Copy as cURL (bash)** (Chrome, Edge).
5. Paste it into a file, `request.txt`, in the working folder. Do not paste it
   into the chat: it holds a live sign-in token.

Then run `fetch.sh --from-curl request.txt`. It reads the URL and the
`x-authorization` header from the copied command.

If the user cannot find that row, any row filtered on `sharepoint.com` whose URL
contains `/drives/` and `/items/` and whose headers carry a `Bearer` token works
too; pass `--key` only if the recording has several transcripts.

## When it fails

| symptom | meaning | move |
|---|---|---|
| `token has N parts` | the token was cut short when copied | take it from `#access_token=` (route A) or re-copy the whole request (route B) |
| `no answer from ...` (`curl: (28)`) | TCP connects but TLS stalls; seen after repeated token calls from a second machine | stop retrying; run `fetch.sh` from the machine the browser runs on, or wait |
| `401` | token expired, or it is not a SharePoint token | grab a fresh one; check the request host is `*.sharepoint.com` |
| `403` or `404` | the account cannot read the recording, or the ids are of a different file | confirm the panel still shows the transcript for this user |
| listing is empty | the recording has no transcript | transcription was off; nothing to fetch |
| bytes that will not parse as JSON | you downloaded the `cdnmedia` body | use `fetch.sh`, which calls `media/transcripts` instead |

## Scope

Verified once, November 2026, on Teams web for a meeting chat whose recording
sat in the organizer's OneDrive (`<tenant>-my.sharepoint.com/personal/...`).
Untested: channel meetings (recording in a team SharePoint site), the desktop
app, government clouds, and tenants that bind tokens to a device. If a step
here does not match what the browser shows, record what differs in this file.
