'use client'

import { motion } from 'framer-motion'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Terminal } from '@/components/ui/Terminal'
import { SITE_CONFIG, STATS } from '@/lib/constants'

const terminalCode = `$ curl -fsSL https://raw.githubusercontent.com/chimera-defi/eth2-quickstart/main/run_1.sh | bash

==================================================
       Ethereum Node Quick Start Setup
==================================================

[*] Checking system requirements...
[*] Updating system packages...
[*] Setting up firewall rules...
[*] Creating secure user...
[*] Installing dependencies...
[*] Configuration complete!

Run './run_2.sh' to install clients.`

/**
 * Hero section component for the homepage.
 * Features headline, description, CTAs, stats, and terminal mockup.
 */
export function Hero() {
  return (
    <section className="relative min-h-[calc(100vh-4rem)] overflow-hidden">
      {/* Background effects */}
      <div className="absolute inset-0 bg-gradient-hero" />
      <div className="absolute inset-0 bg-grid-pattern opacity-30" />
      
      {/* Animated glow circles */}
      <div className="absolute -left-40 top-20 h-80 w-80 rounded-full bg-primary/20 blur-[100px] animate-pulse-glow" />
      <div className="absolute -right-40 top-40 h-96 w-96 rounded-full bg-secondary/20 blur-[100px] animate-pulse-glow" style={{ animationDelay: '2s' }} />
      <div className="absolute bottom-20 left-1/3 h-64 w-64 rounded-full bg-purple-500/15 blur-[80px] animate-pulse-glow" style={{ animationDelay: '1s' }} />
      
      {/* Content */}
      <div className="relative mx-auto max-w-7xl px-4 py-16 sm:px-6 sm:py-24 lg:px-8 lg:py-32">
        <div className="grid gap-12 lg:grid-cols-2 lg:gap-16">
          {/* Left column - Content */}
          <div className="flex flex-col justify-center">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5 }}
            >
              <Badge variant="secondary" className="mb-6 w-fit">
                Zero to Ethereum node in 30 minutes
              </Badge>
            </motion.div>
            
            <motion.h1
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.1 }}
              className="font-mono text-4xl font-bold leading-tight sm:text-5xl lg:text-6xl"
            >
              <span className="text-gradient">Ethereum Node Setup</span>
              <br />
              <span className="text-foreground">In Minutes, Not Days</span>
            </motion.h1>
            
            <motion.p
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.2 }}
              className="mt-6 max-w-xl text-lg leading-relaxed text-muted-foreground"
            >
              Transform a fresh cloud server into a fully-configured Ethereum node. 
              Choose from 6 execution clients and 6 consensus clients. Set up MEV-Boost, 
              secure RPC endpoints, and comprehensive security hardening—all automated. 
              Save 2+ days compared to manual guides.
            </motion.p>
            
            {/* CTA Buttons */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.3 }}
              className="mt-8 flex flex-wrap gap-4"
            >
              <Button href="/quickstart" size="lg">
                Get Started
              </Button>
              <Button 
                variant="secondary" 
                href={SITE_CONFIG.github} 
                external 
                size="lg"
              >
                View on GitHub
              </Button>
            </motion.div>
            
            {/* Stats */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.4 }}
              className="mt-12 flex flex-wrap gap-8"
            >
              {STATS.map((stat) => (
                <div key={stat.label} className="text-center">
                  <div className="text-gradient font-mono text-3xl font-bold sm:text-4xl">
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
            initial={{ opacity: 0, x: 40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.6, delay: 0.3 }}
            className="hidden lg:flex lg:items-center lg:justify-end"
          >
            <Terminal 
              code={terminalCode} 
              language="bash"
              title="terminal"
              className="w-full max-w-lg"
            />
          </motion.div>
        </div>
      </div>
    </section>
  )
}
