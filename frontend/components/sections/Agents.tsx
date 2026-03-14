'use client'

import { motion } from 'framer-motion'
import { Badge } from '@/components/ui/Badge'
import { Card } from '@/components/ui/Card'
import { CodeBlock } from '@/components/ui/CodeBlock'
import { Bot, Shield, TerminalSquare, Binary } from 'lucide-react'

const AGENT_POINTS = [
  {
    title: 'ClawHub-ready, repo-aware',
    description: 'Publish through ClawHub, then run it inside an eth2-quickstart checkout so agents operate against the real repo, not a second toolchain.',
    icon: Bot,
  },
  {
    title: 'Canonical command surface',
    description: 'The skill routes through ./scripts/eth2qs.sh instead of inventing new lifecycle commands for install, run, update, or cleanup.',
    icon: TerminalSquare,
  },
  {
    title: 'Machine-readable health',
    description: 'Agents can rely on doctor --json for stable status checks, then pivot to logs for RCA.',
    icon: Binary,
  },
  {
    title: 'Safe cleanup defaults',
    description: 'The recommended cleanup path is dry-run first and preserves keys and secrets by design.',
    icon: Shield,
  },
]

const AGENT_SNIPPET = `# after publishing to ClawHub
clawhub install eth2-quickstart
git clone https://github.com/chimera-defi/eth2-quickstart.git
cd eth2-quickstart

# inside an eth2-quickstart checkout
./scripts/eth2qs.sh phase2 --execution=geth --consensus=prysm --mev=mev-boost
./scripts/eth2qs.sh doctor --json
./scripts/eth2qs.sh stats
./scripts/eth2qs.sh logs --run2 -n 200
./scripts/eth2qs.sh clean-data --dry-run`

export function Agents() {
  return (
    <section id="agents" className="py-12 sm:py-16 md:py-20 lg:py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <div className="grid gap-8 lg:grid-cols-[0.95fr_1.05fr] lg:gap-12 lg:items-start">
          <div>
            <Badge variant="primary">For Agents</Badge>
            <motion.h2
              initial={{ opacity: 0, y: 12 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.4 }}
              transition={{ duration: 0.5 }}
              className="mt-4 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl"
            >
              A tested AI interface over the real node workflows
            </motion.h2>
            <motion.p
              initial={{ opacity: 0, y: 12 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.4 }}
              transition={{ duration: 0.5, delay: 0.1 }}
              className="mt-3 text-base text-muted-foreground sm:text-lg"
            >
              External agents can use the ClawHub-ready skill to bootstrap, run,
              inspect, update, and clean node stacks without drifting from the supported
              command surface.
            </motion.p>
            <p className="mt-3 text-sm text-muted-foreground">
              It is intentionally repo-aware. Once published, install is one-line, but use still
              happens inside the repo checkout, and it does not manage validator secrets.
            </p>
          </div>

          <Card className="border-border/60 bg-muted/40">
            <div className="flex items-center justify-between text-xs text-muted-foreground">
              <span className="font-mono uppercase tracking-wide">Agent demo flow</span>
              <span>publish then install</span>
            </div>
            <div className="mt-3 overflow-x-auto">
              <CodeBlock code={AGENT_SNIPPET} language="bash" />
            </div>
          </Card>
        </div>

        <div className="mt-8 grid gap-4 sm:grid-cols-2">
          {AGENT_POINTS.map((point, index) => {
            const Icon = point.icon

            return (
              <motion.div
                key={point.title}
                initial={{ opacity: 0, y: 12 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.3 }}
                transition={{ duration: 0.4, delay: index * 0.08 }}
              >
                <Card padding="sm" className="h-full border-border/60 bg-muted/30">
                  <div className="flex items-start gap-3">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-background">
                      <Icon className="h-4 w-4 text-primary" />
                    </div>
                    <div>
                      <h3 className="font-medium text-foreground">{point.title}</h3>
                      <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                        {point.description}
                      </p>
                    </div>
                  </div>
                </Card>
              </motion.div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
