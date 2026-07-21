# Design: Full campaign articles, native on the site

**Date:** 2026-07-21
**Status:** Approved (chimera_defi, in-session)
**Branch:** session/ah-eth2qs-build-0720-1425

## Problem

The bake-off blog page (`/blog/ethereum-client-bakeoff`) on the live site
(`eth2quickstart.com`) shows only a TL;DR + scorecard and links **out to GitHub**
for the full write-up. The campaign's long-form articles (the bake-off write-up,
the "how we tested with Claude" 23-day harness story, the harness engineering
deep-dive, and the raw results) are not readable natively on the site. The owner
wants to fully browse every article **on the site** — not be bounced to GitHub —
before signing off on the content.

## Goal

All four campaign articles render as native, on-site JSX pages under `/blog`,
faithful to their source markdown, styled with the existing design system.

## Source docs → routes

| Route | Source doc | Owner |
|---|---|---|
| `/blog/ethereum-client-bakeoff` (expand in place) | `docs/CLIENT_BAKEOFF_BLOG.md` | this branch |
| `/blog/bakeoff-harness` (new) | `docs/CLIENT_BAKEOFF_HARNESS.md` | this branch |
| `/blog/bakeoff-results` (new) | `docs/CLIENT_BAKEOFF_RESULTS.md` | this branch |
| `/blog/how-we-tested-with-claude` | `docs/HOW_WE_TESTED_WITH_CLAUDE.md` | **PR #202** (already a complete 552-line page; borrowed read-only for preview) |

## Approach (decided)

- **Hand-authored JSX pages**, one per article — no markdown pipeline. Matches the
  existing bake-off page and #202's how-we-tested page (the gold-standard full-article
  template: sections TL;DR → At a glance → narrative → Reproduce it).
- **Design system only:** `Card`, `Badge`, `Button`, `CodeBlock`, responsive tables
  (desktop `<table>` + mobile stacked cards), inline SVG charts. No new dependencies.
- **Fidelity is the point:** every number, verdict, and claim must match the source
  `.md` exactly. Builders must not paraphrase data or invent figures. Reviewer (Opus)
  diffs each finished page against its source doc before it counts as done.
- **Bake-off page:** keep the existing TL;DR/scorecards as the lede; add the full
  write-up narrative below; demote the four GitHub buttons to a "Sources" footer
  (view-on-GitHub), since the content now lives on-site.
- **Blog index (`/blog`):** list all four articles.

## Build mechanism

Opus orchestrates and reviews; **fresh Sonnet subagents** each author one page
(the delegation pattern used when the original article was built). Builders touch
only their single page file and do not run installs/builds — Opus verifies centrally
(typecheck + production build + render check) and reviews fidelity vs source.

## Coordination with PR #202 (non-destructive)

- Never modify or push the `feat/blog-how-we-tested-page` branch.
- For the preview only, surgically check out `#202`'s single page file
  (`frontend/app/blog/how-we-tested-with-claude/page.tsx`) into the working tree so
  all four articles render together for review. This borrows one file; it does not
  entangle this branch with #202's other 19 commits.
- The real merge-to-master sequencing and the `blog/page.tsx` index conflict with
  #202 are resolved **after** the owner vets the content — not now.

## Deliverable

A running build of the site with all four full articles rendering. Provide the owner
a way to read each (screenshots per page and/or the built pages) to vet content
before anything is pushed.

## Non-goals

- No markdown/MDX pipeline.
- No push / no PR / no branch merges to master until the owner signs off on content.
- No changes to #202's branch.

## Verification

`bunx tsc --noEmit` clean · `bun run build` succeeds with all routes generated ·
each page renders (prerendered HTML contains its sections) · Opus fidelity-diff of
each page against its source doc.
