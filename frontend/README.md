# Ethereum Node Quick Setup - Frontend

Marketing website for the Ethereum Node Quick Setup project.

## Quick Start

```bash
npm install    # Install dependencies
npm run dev    # Start development server
npm run build  # Build for production
npm test       # Run tests
```

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
