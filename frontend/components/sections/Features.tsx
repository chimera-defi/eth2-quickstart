'use client'

import { useRef } from 'react'
import { motion, useInView } from 'framer-motion'
import { Card } from '@/components/ui/Card'
import { Badge } from '@/components/ui/Badge'
import { CodeBlock } from '@/components/ui/CodeBlock'
import { FEATURES, EXECUTION_CLIENTS, CONSENSUS_CLIENTS } from '@/lib/constants'
import { Grid3x3, Terminal, Shield, TrendingUp, Globe, Check } from 'lucide-react'

const iconMap = {
  Grid3x3,
  Terminal,
  Shield,
  TrendingUp,
  Globe,
}

const securityFeatures = [
  'UFW firewall configuration',
  'Fail2ban protection',
  'SSH key authentication',
  'Secure file permissions',
  'Localhost service binding',
]

/**
 * Features section component displaying 5 key value propositions.
 */
export function Features() {
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-100px' })
  
  return (
    <section ref={ref} className="relative py-20 sm:py-28">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.5 }}
          className="text-center"
        >
          <h2 className="font-mono text-3xl font-bold text-foreground sm:text-4xl">
            <span className="text-gradient">Everything You Need</span>
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-lg text-muted-foreground">
            A complete toolkit for running your own Ethereum infrastructure
          </p>
        </motion.div>
        
        <div className="mt-16 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((feature, index) => {
            const Icon = iconMap[feature.icon as keyof typeof iconMap]
            
            return (
              <motion.div
                key={feature.id}
                initial={{ opacity: 0, y: 20 }}
                animate={isInView ? { opacity: 1, y: 0 } : {}}
                transition={{ duration: 0.5, delay: index * 0.1 }}
              >
                <Card hover padding="lg" className="h-full">
                  <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-primary/10">
                    <Icon className="h-6 w-6 text-primary" />
                  </div>
                  
                  <h3 className="mt-4 font-mono text-xl font-semibold text-foreground">
                    {feature.title}
                  </h3>
                  
                  <p className="mt-2 text-muted-foreground">
                    {feature.description}
                  </p>
                  
                  {/* Feature-specific visual elements */}
                  <div className="mt-4">
                    {feature.id === 'client-diversity' && (
                      <div className="space-y-2">
                        <div className="flex flex-wrap gap-1.5">
                          {EXECUTION_CLIENTS.slice(0, 3).map((client) => (
                            <Badge key={client.name} variant="primary" size="sm">
                              {client.name}
                            </Badge>
                          ))}
                        </div>
                        <div className="flex flex-wrap gap-1.5">
                          {CONSENSUS_CLIENTS.slice(0, 3).map((client) => (
                            <Badge key={client.name} variant="secondary" size="sm">
                              {client.name}
                            </Badge>
                          ))}
                        </div>
                      </div>
                    )}
                    
                    {feature.id === 'one-liner' && (
                      <CodeBlock
                        code="curl -fsSL https://raw.githubusercontent.com/chimera-defi/eth2-quickstart/main/run_1.sh | bash"
                        language="bash"
                        className="mt-2"
                      />
                    )}
                    
                    {feature.id === 'security' && (
                      <ul className="mt-2 space-y-1.5">
                        {securityFeatures.map((item) => (
                          <li key={item} className="flex items-center gap-2 text-sm text-muted-foreground">
                            <Check className="h-4 w-4 text-green-400" />
                            {item}
                          </li>
                        ))}
                      </ul>
                    )}
                    
                    {feature.id === 'mev' && (
                      <div className="flex flex-wrap gap-2">
                        <Badge variant="success" size="sm">MEV-Boost</Badge>
                        <Badge variant="muted" size="sm">Commit-Boost</Badge>
                        <Badge variant="muted" size="sm">Multi-Relay</Badge>
                      </div>
                    )}
                    
                    {feature.id === 'rpc' && (
                      <div className="rounded-lg border border-border/30 bg-muted/30 p-3">
                        <code className="text-sm text-secondary">
                          https://your-node.com/rpc
                        </code>
                        <p className="mt-1 text-xs text-muted-foreground">
                          SSL • Rate Limited • Uncensored
                        </p>
                      </div>
                    )}
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
