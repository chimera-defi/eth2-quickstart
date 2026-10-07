# Blog drafts

Unpublished article rewrites waiting for an editorial pick. Nothing in this directory is
routed: the live site renders only `frontend/app/blog/*/page.tsx`, so these files never
reach eth2quickstart.com unless someone ports one into a page.

Drafts are still covered by CI: `test/ci_test_campaign_constants.sh` checks their measured
figures against `docs/CLIENT_BAKEOFF_RESULTS.md`, and `test/ci_test_docs_consistency.sh`
checks their links.

## Current drafts

| File | Rewrite of | Writer |
|---|---|---|
| [ethereum-client-bakeoff.opus.md](ethereum-client-bakeoff.opus.md) | `/blog/ethereum-client-bakeoff` | Claude Opus 5.5 |
| [ethereum-client-bakeoff.fable.md](ethereum-client-bakeoff.fable.md) | `/blog/ethereum-client-bakeoff` | Claude Fable 5.1 |

Both were written independently against
[`skills/blog-anti-patterns/SKILL.md`](../../../skills/blog-anti-patterns/SKILL.md) and a
facts packet checked line by line against the results arbiter.

## Audit (2026-10-07)

Each live article scored against the skill's checks 1–6 (0 clean, 1 minor, 2 bad). The
weighted total counts checks 1–3 double, because those are the ones that lose a reader
in the first screen. Reference reader: runs, or plans to run, one validator at home and
has never seen this repo.

| Article | 1 Intro | 2 Preamble | 3 Jargon | 4 Links | 5 Sequel | 6 Formal | Weighted | Words |
|---|---|---|---|---|---|---|---|---|
| how-we-tested-with-claude | 1 | 2 | 2 | 1 | 2 | 1 | 14 | ~2,200 |
| bakeoff-harness *(reference)* | 1 | 2 | 2 | 1 | 1 | 1 | 13 | ~4,100 |
| **ethereum-client-bakeoff** | 1 | 2 | 2 | 0 | 0 | 1 | 11 | ~5,500 |
| bakeoff-results *(reference)* | 1 | 2 | 2 | 0 | 0 | 1 | 11 | ~1,000 + tables |
| CLIENT_BAKEOFF_OPERATOR_GUIDE.md *(not on site)* | 0 | 1 | 1 | 1 | 0 | 1 | 6 | ~1,550 |

Checks 7–8 (mobile overflow, contrast): no problems found on the four rendered pages from
reading the JSX and CSS. Wide tables sit in `overflow-x-auto` wrappers with card fallbacks
on small screens, and muted text is about 7.5:1 on the dark background. These are static
reads, not rendered checks.

**Why `ethereum-client-bakeoff`, not the top scorer.** `how-we-tested-with-claude` scores
highest, mostly because it is framed as a sequel, but its readers are engineers curious
about agent workflows, it was rebuilt three weeks earlier (#272), and the fix there is
small (drop the companion framing and the callout). The two reference pages are dense by
design, and rewriting them for a general reader would undermine what they are for.
`ethereum-client-bakeoff` is the page home operators land on. It is the longest, it puts a
subtitle, buttons, a companion-post card, four "at a glance" cards and a 15-link contents
list in front of the TL;DR, and it leans on campaign-internal terms (anchor, re-snap,
pivot, Stage B, config-optimality gate). It has the most readers and the most to gain.
