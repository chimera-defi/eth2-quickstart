# Frontend Guide

This repo includes a marketing frontend in `frontend/`. It is live at
**[eth2quickstart.com](https://eth2quickstart.com)** (no hyphen), and **merging to `master`
publishes it automatically** — within minutes, edits included. The deploy pipeline lives
outside this repo (no workflow or deploy config here) and serves the Next.js standalone build
behind CloudFront, so a merged `frontend/` change is public immediately: build and preview it
locally first. Details in [`frontend/README.md`](../frontend/README.md#deployment); the blog and
slide deck are covered in [`BLOG_GUIDE.md`](BLOG_GUIDE.md).

## Canonical Sources

- `frontend/README.md` - Setup, local dev, and build commands
- `frontend/app/` - Routes/pages
- `frontend/components/` - Reusable UI components
- `frontend/lib/constants.ts` - Shared marketing content/config values

## Tooling Rules

- Use **Bun** (not npm): `bun install`, `bun run dev`, `bun run build`, `bun run lint`
- Keep content and docs links aligned with root `README.md` and `docs/README.md`

## Historical Docs

Older frontend planning, prompt, and migration documents were moved to
`docs/archive/frontend/` to reduce active-context bloat.
