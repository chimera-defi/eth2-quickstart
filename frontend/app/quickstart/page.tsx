import type { Metadata } from 'next'
import { Card } from '@/components/ui/Card'
import { CodeBlock } from '@/components/ui/CodeBlock'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { INSTALLATION_STEPS, PREREQUISITES, TROUBLESHOOTING, SITE_CONFIG } from '@/lib/constants'
import { CheckCircle, AlertTriangle, ArrowRight, Server, HardDrive, Wifi, Key } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Quick Start Guide - Ethereum Node Setup',
  description: 'Get your Ethereum node running in 30 minutes. Step-by-step guide with automated scripts, client selection, and security configuration.',
}

const prerequisiteIcons = {
  Server,
  Hardware: HardDrive,
  Network: Wifi,
  Access: Key,
}

/**
 * Quickstart guide page with installation steps and troubleshooting
 */
export default function QuickstartPage() {
  return (
    <div className="min-h-screen py-12 sm:py-16">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center">
          <Badge variant="primary" className="mb-4">
            Quick Start Guide
          </Badge>
          <h1 className="font-mono text-3xl font-bold text-foreground sm:text-4xl lg:text-5xl">
            <span className="text-gradient">Get Started in 30 Minutes</span>
          </h1>
          <p className="mx-auto mt-4 max-w-2xl text-lg text-muted-foreground">
            Follow these steps to transform a fresh cloud server into a fully-configured Ethereum node.
          </p>
        </div>
        
        {/* Prerequisites */}
        <section className="mt-12">
          <h2 className="flex items-center gap-2 font-mono text-2xl font-bold text-foreground">
            <CheckCircle className="h-6 w-6 text-green-400" />
            Prerequisites
          </h2>
          <p className="mt-2 text-muted-foreground">
            Before you begin, ensure you have the following:
          </p>
          
          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            {PREREQUISITES.map((prereq) => {
              const Icon = prerequisiteIcons[prereq.label as keyof typeof prerequisiteIcons] || Server
              return (
                <Card key={prereq.label} padding="md">
                  <div className="flex items-start gap-3">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary/10">
                      <Icon className="h-5 w-5 text-primary" />
                    </div>
                    <div>
                      <h3 className="font-semibold text-foreground">{prereq.label}</h3>
                      <p className="mt-1 text-sm text-muted-foreground">{prereq.value}</p>
                    </div>
                  </div>
                </Card>
              )
            })}
          </div>
        </section>
        
        {/* Installation Steps */}
        <section className="mt-16">
          <h2 className="font-mono text-2xl font-bold text-foreground">
            Installation Steps
          </h2>
          
          <div className="mt-8 space-y-8">
            {INSTALLATION_STEPS.map((item) => (
              <div key={item.step} className="relative">
                {/* Step number */}
                <div className="flex items-start gap-4">
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary text-white font-mono font-bold">
                    {item.step}
                  </div>
                  <div className="flex-1">
                    <h3 className="font-mono text-xl font-semibold text-foreground">
                      {item.title}
                    </h3>
                    <p className="mt-2 text-muted-foreground">
                      {item.description}
                    </p>
                    <div className="mt-4">
                      <CodeBlock code={item.code} language="bash" />
                    </div>
                  </div>
                </div>
                
                {/* Connector line */}
                {item.step < INSTALLATION_STEPS.length && (
                  <div className="absolute left-5 top-12 h-[calc(100%-1rem)] w-px bg-border/50" />
                )}
              </div>
            ))}
          </div>
        </section>
        
        {/* Troubleshooting */}
        <section className="mt-16">
          <h2 className="flex items-center gap-2 font-mono text-2xl font-bold text-foreground">
            <AlertTriangle className="h-6 w-6 text-warning" />
            Troubleshooting
          </h2>
          <p className="mt-2 text-muted-foreground">
            Common issues and how to resolve them:
          </p>
          
          <div className="mt-6 space-y-4">
            {TROUBLESHOOTING.map((item, index) => (
              <Card key={index} padding="md">
                <h3 className="font-semibold text-foreground">{item.issue}</h3>
                <p className="mt-2 text-sm text-muted-foreground">{item.solution}</p>
              </Card>
            ))}
          </div>
          
          <Card padding="md" className="mt-6 bg-primary/5 border-primary/20">
            <h3 className="font-semibold text-foreground">Need more help?</h3>
            <p className="mt-2 text-sm text-muted-foreground">
              Check the full documentation, review logs with <code className="rounded bg-muted px-1 py-0.5 text-xs">journalctl -u service_name</code>, 
              or open an issue on GitHub.
            </p>
            <div className="mt-4 flex flex-wrap gap-3">
              <Button href="/learn" variant="secondary" size="sm">
                View Documentation
              </Button>
              <Button 
                href={`${SITE_CONFIG.github}/issues`} 
                variant="secondary" 
                size="sm" 
                external
              >
                Open Issue
              </Button>
            </div>
          </Card>
        </section>
        
        {/* Next Steps */}
        <section className="mt-16">
          <Card padding="lg" className="bg-gradient-to-r from-primary/10 to-secondary/10 border-primary/20">
            <div className="flex flex-col items-center text-center sm:flex-row sm:text-left">
              <div className="flex-1">
                <h2 className="font-mono text-xl font-bold text-foreground">
                  Ready to dive deeper?
                </h2>
                <p className="mt-2 text-muted-foreground">
                  Explore our comprehensive documentation for advanced configuration, 
                  client selection guides, and MEV optimization.
                </p>
              </div>
              <div className="mt-4 sm:ml-6 sm:mt-0">
                <Button href="/learn" size="lg">
                  Learn More
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Button>
              </div>
            </div>
          </Card>
        </section>
      </div>
    </div>
  )
}
