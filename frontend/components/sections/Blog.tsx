'use client'

import { useRef } from 'react'
import { motion, useInView } from 'framer-motion'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { ArrowRight } from 'lucide-react'

export function Blog() {
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-100px' })

  return (
    <section ref={ref} className="py-12 sm:py-16 md:py-20 lg:py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        {/* Section header */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={isInView ? { opacity: 1 } : {}}
          transition={{ duration: 0.6 }}
          className="max-w-2xl"
        >
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            From the lab
          </p>
          <h2 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            Field notes &amp; benchmarks
          </h2>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            Real results from running these clients in production — disk footprints, sync
            times, and hard-won operational lessons.
          </p>
        </motion.div>

        {/* Featured post */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.5, delay: 0.1 }}
          className="mt-8 sm:mt-10"
        >
          <Card
            hover
            className="border-border/60 bg-muted/30 transition-all duration-300 hover:border-primary/40 hover:bg-muted/50"
          >
            <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
              Client research
            </p>
            <h3 className="mt-2 text-xl font-semibold text-foreground">
              Ethereum client bake-off
            </h3>
            <p className="mt-2 max-w-2xl text-sm text-muted-foreground leading-relaxed">
              Results from a 23-day execution and consensus client sync campaign: disk,
              speed, and restart resilience across every client pairing.
            </p>
            <div className="mt-4 flex flex-col flex-wrap items-stretch gap-3 sm:flex-row sm:items-center">
              <Button
                href="/blog/ethereum-client-bakeoff"
                size="sm"
                className="justify-center shrink-0"
              >
                Read the write-up
                <ArrowRight className="ml-2 h-4 w-4 shrink-0" />
              </Button>
              <Button
                href="/blog"
                variant="ghost"
                size="sm"
                className="justify-center shrink-0"
              >
                All posts
              </Button>
            </div>
          </Card>
        </motion.div>
      </div>
    </section>
  )
}
