# links

A cognitive friction skill for Claude. When invoked with `/links`, the agent
returns only curated links — no synthesis, no explanation, no AI-generated prose.
The human reads the sources and makes the connection themselves.

Usage : copy the `./SKILL.md` to your AI agent.


## Why this exists

### The problem: thinking entropy

AI coding agents are reshaping how software gets built. Developers delegate
substantial coding tasks to autonomous agents in pursuit of higher productivity.
The productivity gains are real. What is also real is that this delegation
short-circuits the effortful problem-solving through which software engineering
expertise has historically been built.

Anthropic's own research quantified this. In a randomized controlled trial
([Shen & Tamkin, 2026, "How AI Impacts Skill Formation"](https://www.anthropic.com/research/AI-assistance-coding-skills)),
developers learning a new Python library who used AI assistance scored 17% lower
on a comprehension quiz than those who coded by hand — roughly two letter grades.
The largest gap appeared in debugging, suggesting AI assistance particularly
undermines the ability to spot errors in code and understand why they happen.
Participants who fully delegated to the AI showed the steepest decline.

A July 2026 paper ([Ahmad et al., "Agents That Teach," arXiv:2607.06101](https://arxiv.org/abs/2607.06101))
coined the term **Knowledge Debt** — a developer-level analogue of Technical Debt
where changes the agent executes that the developer cannot fully understand accrue
over time. Developers remain productive in the short term while their independent
capability quietly lags behind, leaving them able to build with AI but
increasingly unable to debug, adapt, or extend that work on their own.

The interaction patterns that preserved learning in these studies all shared one
trait: they required more cognitive effort and active engagement. The patterns
that outsourced thinking entirely produced faster outputs and consistently weaker
skill development.

### The principle: desirable difficulty

The learning science literature calls this [**desirable difficulty**](https://en.wikipedia.org/wiki/Desirable_difficulty) (Bjork &
Bjork, 2011). Effective learning entails mental friction — it requires effort but
leads to deeper understanding and long-term retention. AI tools, by offering
quick, fluent, simplified answers, reduce the cognitive struggle essential to
learning. Their convenience leads to passive consumption, decreased reasoning
skills, and growing dependence on pre-digested knowledge.

A difficulty is desirable only when the learner has the background and resources
to overcome it. Hand a beginner a problem they cannot possibly solve and you have
not created a desirable difficulty — you have created frustration. The art is in
finding the band of difficulty high enough to demand real effort and low enough
to be conquered.

For an experienced developer who already knows how to code, who finds joy and
identity in doing the work themselves, that band is: *show me where to look,
then get out of the way.*

### The design philosophy

**Don't overstep trying to be helpful.**

Every AI product on the market is racing to give more answers faster. This skill
does the deliberate inverse. It uses the AI's contextual intelligence — its
ability to understand intent, decompose problems, and judge relevance — as a
search quality multiplier rather than a thinking replacement. The AI understands
*what* you're really asking (something keyword search often fails at), but
instead of answering, it returns the most relevant sources and lets you close the
loop.

The core differentiator over a search engine is **intent decomposition**. Google
cannot look at a question and determine that it is actually three entangled
sub-questions. This skill can. It groups links under sub-problem headings — the
AI writes the headings, which is structural organisation, not answering — and the
human does the reading, connecting, and synthesising.

### What this is not

This is not a new search engine. Google returns results in milliseconds; this
skill runs inside a Claude turn with inherent LLM latency. The competition is
not speed-to-results — it is **total time to understanding**. Google is fast to
results but slow to answers (you click four links, read SEO-gamed content,
backtrack). This skill is slower to results but faster to the right result.

## Design decisions

All decisions below were made through a structured grilling session. Each was
explicitly posed as a frontier question, weighed against alternatives, and
settled by the maintainer.

### Activation: opt-in per question

Trigger phrase: `/links`. The skill governs only the turn it is invoked on.
Other turns behave normally. The discipline of typing the trigger is itself a
micro-moment of intentionality that reinforces cognitive ownership.

Why not always-on: Claude is still useful for tasks where synthesis is the right
output (drafting commits, reviewing diffs, rubber-ducking architecture). The
skill should not cripple the tool.

### Output purity: pure links, structural decomposition allowed

The output contains only titles and URLs. No annotations, no relevance lines, no
section pointers, no AI-generated explanatory text of any kind. The human is the
one making the cognitive find.

The one permitted GenAI output is **sub-problem headings** when intent
decomposition fires. The AI can say "What does res.json() return?" as a heading
with links underneath. This is structural — routing, not answering. It tells the
human where to look, not what they will find. It is the equivalent of section
headers on a well-organised bookshelf: the librarian sorted the books into
shelves but did not read them to you.

### Link ordering: foundation first, then pragmatic

Links are grouped in two tiers:

1. **Foundation** — concept articles, specifications, official documentation that
   establish the baseline mental model.
2. **Pragmatic** — blog posts, tutorials, GitHub discussions that show real-world
   usage of the concept, relevant to the specific question asked.

The human builds the foundational understanding first, then reads how the concept
is applied in practice.

Within each tier, links are ranked by **closest match to confusion** — the
resource most likely to resolve the user's specific misunderstanding ranks first,
regardless of source authority. Authority is a tiebreaker, not the primary
signal.

### Source priority: developer ecosystem first

In order of preference:

1. **Developer ecosystem** — official docs + GitHub discussions + blog posts +
   Stack Overflow + RFCs/specs. The sweet spot: docs alone are often too dry, and
   the real learning happens when you read someone's blog post explaining *why*
   an API works the way it does, then go verify against the official docs. That
   cognitive triangulation is exactly the synthesis the *human* should be doing.
2. **Documentation-only** — when the question is purely about language or API
   semantics and community content would be noise.
3. **Web-wide** — last resort, for niche topics where the developer ecosystem has
   insufficient coverage.

### Speed architecture

For common questions (well-known libraries, standard APIs), the skill uses
training knowledge to curate links — no web search needed. The model already
knows that the MDN page for `Response.json()` exists and can emit the URL from
memory in 2–3 seconds.

For niche or recent topics (a library released after training, a recent API
change), the skill falls back to web search. Slower, but these are also the
questions Google would bury in SEO noise anyway.

The speed story: instant for things you should already know how to find, a few
seconds for things Google would bury.

### Link count: dynamic 3–5

Three to five links per response, scaled to question complexity. Three links
where each one earns its place is better than five where two are padding.

### Failure mode: honest, then clarify

When the skill cannot find strong links:

1. Ask one clarifying question to narrow the search.
2. If that also fails, say so. "I couldn't find strong resources for this. Try
   rephrasing."

The skill never silently falls back to a normal synthesised Claude response. The
whole point is the constraint. Breaking the contract without announcing it
defeats the purpose.

## Key references

These are the papers and articles that informed the design. A code reader
maintaining this skill should be able to understand the rationale without opening
any of them, but they are here for anyone who wants to go deeper.

| reference | what it establishes |
|---|---|
| [Shen & Tamkin (2026), "How AI Impacts Skill Formation," arXiv:2601.20245](https://www.anthropic.com/research/AI-assistance-coding-skills) | The 17% comprehension gap. Interaction patterns that preserve learning vs. those that don't. Anthropic's own research. |
| [Ahmad et al. (2026), "Agents That Teach," arXiv:2607.06101](https://arxiv.org/abs/2607.06101) | Knowledge Debt as a concept. Six design principles for embedding learning into agent workflows. The SHIELD system. |
| [Aiersilan (2026), "The Vibe-Check Protocol," arXiv:2601.02410](https://arxiv.org/pdf/2601.02410) | Theoretical framework for quantifying cognitive offloading in AI programming. Proposes metrics. |
| [Bjork & Bjork (2011), "Making Things Hard on Yourself, But in a Good Way"](https://en.wikipedia.org/wiki/Desirable_difficulty) | The desirable difficulty framework. Conditions under which friction improves long-term retention. |
| ["Do AI Tutors Empower or Enslave Learners?" arXiv:2507.06878](https://arxiv.org/pdf/2507.06878) | Connects desirable difficulty directly to AI tool design. How AI reduces cognitive struggle essential to learning. |
| [Faye (2026), "AI Coding Will Prevent Expertise"](https://larsfaye.com/articles/ai-coding-will-prevent-expertise) | Practitioner perspective on cognitive debt vs. cognitive offloading. Friction creates the lasting imprint that leads to expertise. |