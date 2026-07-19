import type { Metadata } from 'next'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'

export const metadata: Metadata = {
  title: 'Blog - ETH2 Quick Start',
  description: 'Notes and results from the ETH2 Quick Start lab.',
}

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
            <Card hover>
              <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
                Client research
              </p>
              <h3 className="mt-2 text-xl font-semibold text-foreground">
                Ethereum client bake-off
              </h3>
              <p className="mt-2 text-sm text-muted-foreground">
                Results from a 23-day execution and consensus client sync campaign: disk, speed, and restart resilience.
              </p>
              <div className="mt-4">
                <Button href="/blog/ethereum-client-bakeoff" variant="ghost" size="sm">
                  Read more
                </Button>
              </div>
            </Card>
            <Card hover>
              <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
                Methodology
              </p>
              <h3 className="mt-2 text-xl font-semibold text-foreground">
                How we ran the bake-off with Claude
              </h3>
              <p className="mt-2 text-sm text-muted-foreground">
                The agent orchestration model, the harness, and what actually breaks when a benchmark runs for three weeks with an AI in the driver&apos;s seat.
              </p>
              <div className="mt-4">
                <Button href="/blog/how-we-tested-with-claude" variant="ghost" size="sm">
                  Read more
                </Button>
              </div>
            </Card>
          </div>
        </section>
      </div>
    </div>
  )
}
