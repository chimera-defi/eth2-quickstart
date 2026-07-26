# Ethereum Node Quick Setup - Frontend

Marketing website for the Ethereum Node Quick Setup project.

## Quick Start

```bash
bun install      # Install dependencies
bun run dev      # Start development server
bun run build    # Build for production
bun run test     # Run tests (uses Jest)
```

**Note:** This project uses [Bun](https://bun.sh) as the package manager for 2-3x faster installs and builds than npm. Install Bun: `curl -fsSL https://bun.sh/install | bash`

## Structure

```
frontend/
├── app/           # Next.js pages (/, /quickstart, /learn)
├── components/
│   ├── ui/        # Button, Card, Badge, Terminal, CodeBlock
│   ├── layout/    # Navbar, Footer
│   └── sections/  # Hero, Features
├── lib/           # utils.ts, constants.ts
└── __tests__/     # Jest tests
```

## Tech Stack

- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- Framer Motion
- Lucide Icons

## Deployment

**Live site: [eth2quickstart.com](https://eth2quickstart.com)** — note the spelling: no hyphen.
(`eth2-quickstart.com`, with a hyphen, does not resolve; it was a stale reference in the code
until it was corrected, so don't reintroduce it.)

**Merging to `master` publishes automatically.** There is no deploy step in this
repo — no workflow, no `vercel.json`/`amplify.yml`. The pipeline is configured
outside the repository: it builds the Next.js standalone output
(`output: 'standalone'` in `next.config.js`) and serves it behind CloudFront.
A merge goes live within minutes, for both new routes and edits to existing
pages, so treat a merge to `master` as publishing to a public website.

Because CloudFront caches aggressively (`s-maxage`, `stale-while-revalidate`),
give a change a minute and force-reload if you still see the old version.

To preview a production build locally before merging:

```bash
bun run build
bun run start                     # quick preview; Next warns it isn't the standalone server
node .next/standalone/server.js   # production-faithful (matches what's deployed)
```
