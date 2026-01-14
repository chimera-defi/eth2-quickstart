'use client'

import { useRef } from 'react'
import { motion, useInView } from 'framer-motion'
import { FEATURES } from '@/lib/constants'
import { Card } from '@/components/ui/Card'
import { Grid3x3, Terminal, Shield, TrendingUp, Globe } from 'lucide-react'

const iconMap = {
  Grid3x3,
  Terminal,
  Shield,
  TrendingUp,
  Globe,
}

export function Features() {
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-100px' })
  
  return (
    <section ref={ref} className="py-16 sm:py-20 lg:py-24">
      <div className="mx-auto max-w-6xl px-6">
        {/* Section header */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={isInView ? { opacity: 1 } : {}}
          transition={{ duration: 0.6 }}
          className="max-w-2xl"
        >
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Features
          </p>
          <h2 className="mt-2 text-3xl font-semibold tracking-tight text-foreground sm:text-4xl">
            Everything you need to go live
          </h2>
          <p className="mt-4 text-lg text-muted-foreground">
            A complete toolkit for running your own Ethereum infrastructure with confidence.
          </p>
        </motion.div>
        
        {/* Features grid */}
        <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((feature, index) => {
            const Icon = iconMap[feature.icon as keyof typeof iconMap]
            
            return (
              <motion.div
                key={feature.id}
                initial={{ opacity: 0, y: 16 }}
                animate={isInView ? { opacity: 1, y: 0 } : {}}
                transition={{ duration: 0.5, delay: index * 0.1 }}
                className="group"
              >
                <Card
                  hover
                  className="h-full border-border/60 bg-muted/30 transition-all duration-300 hover:border-primary/40 hover:bg-muted/50"
                >
                  <div className="flex items-start gap-4">
                    <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-background">
                      <Icon className="h-5 w-5 text-primary" />
                    </div>
                    <div>
                      <h3 className="font-medium text-foreground">
                        {feature.title}
                      </h3>
                      <p className="mt-2 text-sm text-muted-foreground leading-relaxed">
                        {feature.description}
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
