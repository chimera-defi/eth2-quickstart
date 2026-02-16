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

Push to GitHub and connect to Vercel for automatic deployment.
