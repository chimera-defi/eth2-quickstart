# Ethereum Node Quick Setup - Frontend

A modern, marketing-focused frontend website for the Ethereum Node Quick Setup project.

## Features

- 🎨 Modern dark theme with glassmorphism effects
- ⚡ Built with Next.js 14+ and TypeScript
- 💅 Styled with Tailwind CSS
- 🎭 Smooth animations with Framer Motion
- 📱 Fully responsive design
- ♿ WCAG 2.1 AA accessible
- 🔍 SEO optimized

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Animations**: Framer Motion
- **Icons**: Lucide React
- **Code Highlighting**: react-syntax-highlighter
- **Testing**: Jest + React Testing Library

## Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn

### Installation

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

### Running Tests

```bash
# Run tests
npm test

# Run tests in watch mode
npm run test:watch

# Generate coverage report
npm run test:coverage
```

## Project Structure

```
frontend/
├── app/                    # Next.js App Router pages
│   ├── layout.tsx         # Root layout
│   ├── page.tsx           # Homepage
│   ├── quickstart/        # Quickstart guide page
│   ├── learn/             # Documentation page
│   ├── loading.tsx        # Loading state
│   ├── error.tsx          # Error boundary
│   └── not-found.tsx      # 404 page
├── components/
│   ├── ui/                # Reusable UI components
│   │   ├── Button.tsx
│   │   ├── Card.tsx
│   │   ├── Badge.tsx
│   │   ├── Terminal.tsx
│   │   └── CodeBlock.tsx
│   ├── layout/            # Layout components
│   │   ├── Navbar.tsx
│   │   └── Footer.tsx
│   └── sections/          # Page sections
│       ├── Hero.tsx
│       └── Features.tsx
├── lib/                   # Utilities and constants
│   ├── utils.ts
│   └── constants.ts
├── __tests__/             # Test files
└── public/                # Static assets
```

## Components

### UI Components

| Component | Description |
|-----------|-------------|
| `Button` | Primary and secondary button variants with link support |
| `Card` | Glassmorphism card with hover effects |
| `Badge` | Colored badge for labels and tags |
| `Terminal` | macOS-style terminal mockup |
| `CodeBlock` | Syntax highlighted code with copy button |

### Layout Components

| Component | Description |
|-----------|-------------|
| `Navbar` | Responsive navigation with mobile menu |
| `Footer` | Site footer with links |

### Section Components

| Component | Description |
|-----------|-------------|
| `Hero` | Homepage hero with animations |
| `Features` | Feature cards with scroll animations |

## Pages

- **/** - Homepage with hero and features
- **/quickstart** - Step-by-step installation guide
- **/learn** - Documentation hub and client comparisons

## Deployment

### Vercel (Recommended)

1. Push to GitHub
2. Connect repo to Vercel
3. Deploy automatically

### Static Export

```bash
npm run build
# Output in .next/standalone
```

## Environment Variables

No environment variables required for basic functionality.

## Contributing

1. Follow the existing code style
2. Add tests for new components
3. Ensure all tests pass
4. Update documentation as needed

## License

MIT License - see the main project for details.
