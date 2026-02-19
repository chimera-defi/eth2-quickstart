'use client'

import Link from 'next/link'
import { motion } from 'framer-motion'
import { CodeBlock } from '@/components/ui/CodeBlock'
import { Badge } from '@/components/ui/Badge'
import { Card } from '@/components/ui/Card'
import { INSTALL_COMMAND, INSTALL_HIGHLIGHTS } from '@/lib/constants'
import { Grid3x3, Terminal, Shield } from 'lucide-react'

const iconMap = {
  Grid3x3,
  Terminal,
  Shield,
}

export function Install() {
  return (
    <section id="install" className="py-12 sm:py-16 md:py-20 lg:py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <div className="flex flex-col gap-8 sm:gap-10 lg:gap-12">
          {/* Header and description */}
          <div>
            <Badge variant="primary">Install</Badge>
            <motion.h2
              initial={{ opacity: 0, y: 12 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.4 }}
              transition={{ duration: 0.5 }}
              className="mt-4 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl"
            >
              One command, production-ready node
            </motion.h2>
            <motion.p
              initial={{ opacity: 0, y: 12 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.4 }}
              transition={{ duration: 0.5, delay: 0.1 }}
              className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground"
            >
              Copy the one-line installer to bootstrap a hardened server, then continue
              with the guided configuration wizard.
            </motion.p>
            <div className="mt-4 grid gap-2.5 sm:gap-3 text-sm text-muted-foreground">
              {[
                'Creates a locked-down operator user and enforces SSH best practices.',
                'Installs execution + consensus clients with MEV relay presets.',
                'Configures systemd services, health checks, and monitoring hooks.',
              ].map((item) => (
                <div key={item} className="flex items-start gap-2">
                  <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
                  <span>{item}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Install command and two-phase card - stacked vertically */}
          <div className="space-y-3 sm:space-y-4">
            <Card className="border-border/60 bg-muted/40">
              <div className="flex items-center justify-between text-xs text-muted-foreground">
                <span className="font-mono uppercase tracking-wide">Bootstrap command</span>
                <span>Ubuntu 20.04+</span>
              </div>
              <div className="mt-3 overflow-x-auto">
                <CodeBlock code={INSTALL_COMMAND} language="bash" />
              </div>
            </Card>
            <Card className="border-primary/20 bg-primary/5">
              <div className="flex items-start gap-3 text-sm text-muted-foreground">
                <Shield className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
                <div className="min-w-0">
                  <p className="font-medium text-foreground">Two-phase security model</p>
                  <p className="mt-1">
                    Phase one runs as root to harden the host. After reboot, phase two
                    completes client installs as the new operator.
                  </p>
                  <p className="mt-2 text-xs">
                    Prefer manual? Use the pre-existing <code className="rounded bg-muted px-1 py-0.5 font-mono">run_1.sh</code> and <code className="rounded bg-muted px-1 py-0.5 font-mono">run_2.sh</code> scripts—see <Link href="/quickstart#manual" className="text-primary underline-offset-2 hover:underline">Get Started</Link>.
                  </p>
                </div>
              </div>
            </Card>
          </div>

          {/* Highlight cards - grid layout: 1 col mobile, 2 cols tablet, 3 cols desktop */}
          <div className="grid gap-3 sm:gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {INSTALL_HIGHLIGHTS.map((item, index) => {
              const Icon = iconMap[item.icon as keyof typeof iconMap]
              return (
                <motion.div
                  key={item.title}
                  initial={{ opacity: 0, y: 12 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, amount: 0.4 }}
                  transition={{ duration: 0.4, delay: index * 0.1 }}
                >
                  <Card padding="sm" className="flex h-full items-start gap-3 sm:gap-4 bg-muted/40">
                    <div className="flex h-8 w-8 sm:h-9 sm:w-9 shrink-0 items-center justify-center rounded-lg bg-background">
                      <Icon className="h-4 w-4 text-primary" />
                    </div>
                    <div className="min-w-0">
                      <h3 className="font-medium text-foreground">{item.title}</h3>
                      <p className="mt-1 text-sm text-muted-foreground">
                        {item.description}
                      </p>
                    </div>
                  </Card>
                </motion.div>
              )
            })}
          </div>
        </div>
      </div>
    </section>
  )
}
