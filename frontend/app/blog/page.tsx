import type { Metadata } from 'next'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'

export const metadata: Metadata = {
  title: 'Blog - ETH2 Quick Start',
  description: 'Notes and results from the ETH2 Quick Start lab.',
}

const posts = [
  {
    eyebrow: 'Client research',
    title: 'Ethereum client bake-off',
    description:
      'Results from a 23-day execution and consensus client sync campaign: disk, speed, and restart resilience across every client pairing.',
    href: '/blog/ethereum-client-bakeoff',
  },
  {
    eyebrow: 'Methodology',
    title: 'How we tested with Claude',
    description:
      'The orchestration model and harness behind the 23-day campaign — how a fleet of agents ran, sampled, and gated every client sync.',
    href: '/blog/how-we-tested-with-claude',
  },
  {
    eyebrow: 'Engineering',
    title: 'The bake-off harness',
    description:
      'A function-level engineering reference for the harness: the orchestrator, the per-candidate state machine, resource caps, and the probe/sample/gate library.',
    href: '/blog/bakeoff-harness',
  },
  {
    eyebrow: 'Data',
    title: 'Bake-off results',
    description:
      'The raw results: Stage A pass matrix, final synced disk footprints, the consensus-client matrices, and operational-viability notes.',
    href: '/blog/bakeoff-results',
  },
]

export default function BlogPage() {
  return (
    <div className="min-h-screen py-12 sm:py-16 md:py-24">
      <div className="mx-auto max-w-5xl px-4 sm:px-6">
        <header>
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Blog
          </p>
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            From the lab
          </h1>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            Field notes, benchmarks, and practical lessons from running Ethereum nodes.
          </p>
        </header>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Latest
          </h2>
          <div className="mt-4 sm:mt-6 space-y-4">
            {posts.map((post) => (
              <Card key={post.href} hover>
                <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
                  {post.eyebrow}
                </p>
                <h3 className="mt-2 text-xl font-semibold text-foreground">
                  {post.title}
                </h3>
                <p className="mt-2 text-sm text-muted-foreground">
                  {post.description}
                </p>
                <div className="mt-4">
                  <Button href={post.href} variant="ghost" size="sm">
                    Read more
                  </Button>
                </div>
              </Card>
            ))}
          </div>
        </section>
      </div>
    </div>
  )
}
