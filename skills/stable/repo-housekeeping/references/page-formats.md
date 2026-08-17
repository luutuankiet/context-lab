# Page formats

Three collections plus a decision record. The distinction is not cosmetic — it
decides how a page is indexed, and therefore whether anyone ever finds it.

## Which collection

| directory | test | indexed by |
|---|---|---|
| `docs/traps/` | **it has a symptom** — someone would observe something wrong | the symptom, verbatim |
| `docs/architecture/` | it says **where behaviour lives**, one page per area | what you would be looking for |
| `docs/reference/` | it is **simply true**, no symptom attached | what it is about |

> **If a fact has a symptom it is a trap. If it is just true it is reference.**

Aim for **3–6 architecture areas**. Fewer and the pages are too coarse to route
with; more and nobody can hold the list in their head.

## Frontmatter

Flat `key: value`, one per line, between `---` fences, at the very top of the file.
Not nested YAML — index generators for this format parse it line by line on
purpose, so that a page never fails to index because of a quoting rule.

```yaml
# docs/traps/SCREAMING_SNAKE_NAME.md
---
symptom: "the verbatim string a frustrated person would paste into a search box"
area: <which part of the system>
verified: YYYY-MM-DD
---
```

```yaml
# docs/architecture/kebab-case-name.md
---
title: <human name of the area>
covers: <what someone would be looking for, phrased the way they would phrase it>
verified: YYYY-MM-DD
---
```

```yaml
# docs/reference/kebab-case-name.md
---
title: <human name>
summary: <one line: what this is about>
verified: YYYY-MM-DD
---
```

**`symptom:` and `covers:` are search keys, not topic names.** `"state I kept in a
component is gone when I switch tabs and switch back"` is right. `"Tab lifecycle"`
is useless — nobody in trouble types that.

## Filenames

- **Traps: `SCREAMING_SNAKE_CASE`, naming the symptom, not the fix.** The filename
  is an identifier. It gets quoted in code comments, commit messages and issue
  threads, so it is never renamed. If the understanding changes, edit the body.
- **Architecture and reference: `kebab-case`.**

## Page body

Order matters more than headings do. Someone mid-bug reads the first two lines and
stops.

**Symptom → mechanism → fix → how to verify.**

- **Self-contained.** The reader opened this one file from a search result and has
  nothing else loaded. Resolve every reference inline. If a line of code matters,
  quote it.
- **Published tone.** A page on the project's documentation site, not a note to
  self.
- **Include the evidence** — measured numbers, observed values, verbatim code. A
  claim without evidence gets argued with instead of used.
- **Say what is deliberate.** Write down which half of the surprising behaviour was
  a trade someone made on purpose, and what the trade was.
- End with **the general rule**, one short paragraph. It is what makes the page
  transfer to the next instance of the same mistake, which is the only reason a
  page beats a comment.

### Line numbers in architecture pages

Include them — in a 3,000-line file, "it's in `server.js`" is not an answer. But say
plainly in the page that they are a **starting point, not an address**: jump roughly
there, confirm by what the code says, and if a range is off by more than a screen,
fix it and re-date the page. That instruction is what keeps the map honest as it
drifts.

## Decision records

`docs/adr/NNNN-kebab-slug.md`, sequential, created lazily — scan the directory for
the highest number and add one. Numbers are never reused.

```md
# {Short title of the decision}

{One to three sentences: the context, what was decided, and why.}
```

That is the whole requirement. An ADR can be one paragraph; the value is recording
*that* a decision was made and *why*, not filling in sections.

Add these **only when they earn it**:

- **Considered options** — when the rejected alternatives are worth remembering,
  which is whenever someone would otherwise propose one again in six months.
- **Consequences** — when a downstream effect is non-obvious, especially a cost
  accepted knowingly.

Offer an ADR only when **all three** hold: hard to reverse, surprising without
context, and the result of a real trade-off. If it is easy to reverse, skip it —
you will just reverse it. If there was no genuine alternative, there is nothing to
record beyond "we did the obvious thing".

**A merged ADR is immutable.** Superseding means a *new* file that names what it
replaces; the old one stays readable, because the reason a decision was made is not
invalidated by the decision changing. Reference a superseded ADR by number and
tolerate a missing target.

The idiom across all of it: **the issue holds the question, the ADR holds the
conclusion, the pull request links them.**

## What never goes in a page

- A credential, or anything copied verbatim out of a private notes directory. If you
  must refer to one, write `[redacted credential-shaped value at <file>:<line>]`.
- Host names, endpoints, internal addresses, account-to-project mappings. That is
  fleet state. Describe the *capability* instead — "a host without `bc`" — because a
  substituted fake hostname is still a topology claim.
- A private shorthand from whatever system this replaced: log ids, task numbers,
  internal codenames. Resolve each to plain English with the evidence inline. A page
  that says "see LOG-042" is worthless to the reader it was written for.
