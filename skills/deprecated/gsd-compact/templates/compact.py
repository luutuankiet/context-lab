#!/usr/bin/env python3
"""gsd-compact splice driver.

Copy to <project>/gsd-lite/tmp/compact.py, edit CONFIG, run via run_command.
Stage replacement bodies as files in the same tmp/ dir and name them below.

Invariants this script enforces so you cannot forget them:
  - backs up all three artifacts before any write
  - splices by ANCHOR SEARCH, never by line number
  - demotes heading levels of every demoted block (the boundary-destroying bug)
  - never deletes: demoted blocks are appended verbatim under a dated archive heading
"""
import io, os, shutil, sys, re

# ------------------------- CONFIG -------------------------
ROOT = '/abs/path/to/project/gsd-lite'
STAMP = 'YYYY-MM-DD'
TAG = 'vX.Y.Z'            # or a sprint name; used in archive headings

# ARCHITECTURE.md zone-A sections to demote, by exact heading prefix.
# Staged replacement body file (in tmp/) or None to remove the section entirely
# from zone A (it still lands in the archive verbatim).
ARCH_DEMOTE = [
    # ('## Source File Hot Zones', 'arch-hotzones.md'),
    # ('## Notes / Gotchas',       None),
]

# New zone-A sections to insert immediately BEFORE this anchor.
ARCH_INSERT_BEFORE = '## Version Archive'
ARCH_NEW_SECTIONS = [
    # 'arch-landmines.md',
]

PROJECT_NEW = None        # e.g. 'project-new.md' for a full rewrite, or None
WORK_SEC2_NEW = None      # e.g. 'work-events.md' to replace section 2, or None
WORK_SEC1_NEW = None      # e.g. 'work-sec1.md' to replace ALL of section 1, or None
# ----------------------------------------------------------

TMP = os.path.join(ROOT, 'tmp')
ARCH_ANCHOR = '## Version Archive'
H1B = '## 1b. Prior Sprint Statuses (archive - not read at boot)'
H2B = '## 2b. Older Key Events (archive - not read at boot)'


def rd(p):
    with io.open(p, encoding='utf-8') as f:
        return f.read()


def wr(p, s):
    with io.open(p, 'w', encoding='utf-8') as f:
        f.write(s)


def stage(name):
    return rd(os.path.join(TMP, name)).rstrip()


def demote(block, to='#####'):
    """Lower every ATX heading in a block. Iterates lines - a str.replace on
    '\\n## ' misses the FIRST heading, which is how the boundary bug ships."""
    out = []
    for line in block.split('\n'):
        if re.match(r'^#{1,5} ', line):
            out.append(to + ' ' + line.lstrip('#').lstrip())
        else:
            out.append(line)
    return '\n'.join(out)


def find(lines, prefix, start=0):
    for i in range(start, len(lines)):
        if lines[i].startswith(prefix):
            return i
    return -1


def next_h2(lines, start):
    for i in range(start, len(lines)):
        if lines[i].startswith('## ') and not lines[i].startswith('### '):
            return i
    return len(lines)


# ------------------------- backups -------------------------
if not os.path.isdir(TMP):
    os.makedirs(TMP)
for n in ('ARCHITECTURE.md', 'WORK.md', 'PROJECT.md'):
    p = os.path.join(ROOT, n)
    if os.path.exists(p):
        shutil.copy2(p, os.path.join(TMP, n + '.pre-compact.bak'))
print('backups written to tmp/')

# ------------------------- PROJECT.md -------------------------
if PROJECT_NEW:
    wr(os.path.join(ROOT, 'PROJECT.md'), stage(PROJECT_NEW) + '\n')
    print('PROJECT.md rewritten')

# ------------------------- ARCHITECTURE.md -------------------------
ap = os.path.join(ROOT, 'ARCHITECTURE.md')
s = rd(ap)

# ensure the archive anchor exists (Phase 1 repair)
if not re.search(r'^' + re.escape(ARCH_ANCHOR), s, re.M):
    s = s.rstrip() + '\n\n' + ARCH_ANCHOR + '\n\nVersion-stamped and superseded material. Never read at boot.\n'
    print('ARCHITECTURE.md: inserted missing ' + ARCH_ANCHOR)

lines = s.split('\n')
demoted_blocks = []

for heading, repl in ARCH_DEMOTE:
    i = find(lines, heading)
    if i < 0:
        sys.exit('anchor not found: ' + heading)
    if i > find(lines, ARCH_ANCHOR):
        sys.exit('anchor is already inside the archive: ' + heading)
    j = next_h2(lines, i + 1)
    block = '\n'.join(lines[i:j]).rstrip()
    demoted_blocks.append((heading, block))
    body = stage(repl).split('\n') if repl else []
    lines = lines[:i] + body + ([''] if body else []) + lines[j:]

# insert new zone-A sections before the archive anchor
if ARCH_NEW_SECTIONS:
    k = find(lines, ARCH_INSERT_BEFORE)
    if k < 0:
        sys.exit('insert anchor not found: ' + ARCH_INSERT_BEFORE)
    add = []
    for name in ARCH_NEW_SECTIONS:
        add += stage(name).split('\n') + ['']
    lines = lines[:k] + add + lines[k:]

s = '\n'.join(lines).rstrip() + '\n'

if demoted_blocks:
    s += '\n### ' + TAG + ' - zone-A compaction (demoted verbatim, nothing deleted)\n\n'
    s += 'Moved out of the always-read zone on ' + STAMP + '. Content is unchanged; only heading levels were lowered so the archive boundary survives.\n'
    for heading, block in demoted_blocks:
        s += '\n#### (archived) ' + heading.lstrip('#').strip() + '\n\n'
        s += demote(block) + '\n'

wr(ap, s)
print('ARCHITECTURE.md spliced (%d sections demoted)' % len(demoted_blocks))

# ------------------------- WORK.md -------------------------
wp = os.path.join(ROOT, 'WORK.md')
w = rd(wp)
lines = w.split('\n')

i3 = find(lines, '## 3. Atomic Session Log')
if i3 < 0:
    i3 = find(lines, '## 3.')
if i3 < 0:
    sys.exit('WORK.md: section 3 anchor not found')

# Phase 1 repair: 1b / 2b must exist and must sit BEFORE section 3
has1b = find(lines, '## 1b.')
has2b = find(lines, '## 2b.')
if has1b < 0 or has2b < 0 or has1b > i3 or has2b > i3:
    # NOTE: find() is line-anchored (startswith) on purpose - a substring test
    # would match the pattern quoted inside a Context Landmines section.
    ins = []
    if has1b < 0 or has1b > i3:
        ins += [H1B, '', 'Superseded sprint statuses. Never read at boot.', '']
    if has2b < 0 or has2b > i3:
        ins += [H2B, '', 'Verbose event rows demoted from section 2. Never read at boot.', '']
    lines = lines[:i3] + ins + lines[i3:]
    print('WORK.md: inserted missing archive headings before section 3')

w = '\n'.join(lines)

if WORK_SEC1_NEW:
    i1 = w.index('## 1. Current Understanding')
    e1 = w.index('## 2. Key Events')
    old1 = w[i1:e1].rstrip()
    w = w[:i1] + stage(WORK_SEC1_NEW) + '\n\n' + w[e1:]
    j = w.index(H1B) + len(H1B)
    body1 = old1.split('\n', 1)[1].lstrip('\n')
    w = w[:j] + '\n\n### Section 1 as written before ' + STAMP + ' (demoted verbatim)\n\n' + demote(body1, '####') + '\n' + w[j:]
    print('WORK.md: section 1 compressed, prior body demoted to 1b')

if WORK_SEC2_NEW:
    i2 = w.index('## 2. Key Events')
    end = w.index(H1B)
    old2 = w[i2:end].rstrip()
    w = w[:i2] + stage(WORK_SEC2_NEW) + '\n\n' + w[end:]
    k = w.index(H2B) + len(H2B)
    body = old2.split('\n', 1)[1].lstrip('\n')
    w = w[:k] + '\n\n### Verbose key events (demoted ' + STAMP + ')\n\n' + demote(body, '####') + '\n' + w[k:]
    print('WORK.md: section 2 compressed, verbose rows demoted to 2b')

wr(wp, w)
print('WORK.md spliced')
print('NOW RUN PHASE 5 VERIFY')
