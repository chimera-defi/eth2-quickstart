'use client'

import { motion } from 'framer-motion'
import { Button } from '@/components/ui/Button'
import { Terminal } from '@/components/ui/Terminal'
import { SITE_CONFIG, STATS } from '@/lib/constants'
import { ArrowRight } from 'lucide-react'

const terminalCode = `$ curl -fsSL https://eth2.run/install | bash

[✓] System requirements verified
[✓] Firewall configured
[✓] Dependencies installed
[✓] Ready for client selection

Run './run_2.sh' to continue setup.`

export function Hero() {
  return (
    <section className="relative min-h-[90vh] flex items-center">
      {/* Subtle background gradient */}
      <div className="absolute inset-0 bg-gradient-radial from-primary/[0.03] via-transparent to-transparent" />
      
      {/* Content */}
      <div className="relative w-full mx-auto max-w-6xl px-6 py-24 lg:py-32">
        <div className="grid gap-16 lg:grid-cols-2 lg:gap-20 items-center">
          {/* Left column - Content */}
          <div className="max-w-xl">
            <motion.p
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.6 }}
              className="font-mono text-sm tracking-wide text-muted-foreground uppercase"
            >
              Ethereum Infrastructure
            </motion.p>
            
            <motion.h1
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.1 }}
              className="mt-4 font-mono text-4xl font-semibold tracking-tight sm:text-5xl lg:text-6xl"
            >
              <span className="text-foreground">Node Setup</span>
              <br />
              <span className="text-gradient">In Minutes</span>
            </motion.h1>
            
            <motion.p
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.2 }}
              className="mt-6 text-lg text-muted-foreground leading-relaxed"
            >
              Transform a fresh server into a fully-configured Ethereum node. 
              Choose from 12 clients, configure MEV, and secure everything—automatically.
            </motion.p>
            
            {/* CTA Buttons */}
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.3 }}
              className="mt-10 flex items-center gap-4"
            >
              <Button href="/quickstart" size="lg">
                Get Started
                <ArrowRight className="ml-2 h-4 w-4" />
              </Button>
              <Button 
                variant="ghost" 
                href={SITE_CONFIG.github} 
                external 
                size="lg"
              >
                View Source
              </Button>
            </motion.div>
            
            {/* Stats - Minimal */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.6, delay: 0.5 }}
              className="mt-16 flex gap-12"
            >
              {STATS.slice(0, 3).map((stat) => (
                <div key={stat.label}>
                  <div className="font-mono text-2xl font-semibold text-foreground">
                    {stat.value}
                  </div>
                  <div className="mt-1 text-sm text-muted-foreground">
                    {stat.label}
                  </div>
                </div>
              ))}
            </motion.div>
          </div>
          
          {/* Right column - Terminal */}
          <motion.div
            initial={{ opacity: 0, x: 24 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.4 }}
            className="hidden lg:block"
          >
            <Terminal 
              code={terminalCode} 
              language="bash"
              title="terminal"
            />
          </motion.div>
        </div>
      </div>
    </section>
  )
}
