import type { Metadata } from 'next'
import { CodeBlock } from '@/components/ui/CodeBlock'
import { Button } from '@/components/ui/Button'
import {
  INSTALLATION_STEPS_ONELINER,
  INSTALLATION_STEPS_MANUAL,
  PREREQUISITES,
  SITE_CONFIG,
} from '@/lib/constants'
import { ArrowRight, Server, HardDrive, Cpu } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Quick Start - ETH2 Quick Start',
  description: 'Get your Ethereum node running in 30 minutes with automated scripts.',
}

const RECOMMENDED_SPECS = [
  { label: 'CPU', value: '8+ cores', icon: Cpu },
  { label: 'RAM', value: '32GB+', icon: Server },
  { label: 'Storage', value: '4TB NVMe', icon: HardDrive },
]

type Step = { step: number; title: string; description: string; code: string }

function InstallationStepsList({ steps, idPrefix }: { steps: Step[]; idPrefix: string }) {
  return (
    <div className="mt-6 sm:mt-8 space-y-8 sm:space-y-12">
      {steps.map((item, index) => (
        <div key={`${idPrefix}-${item.step}`}>
          <div className="flex items-start gap-3 sm:gap-4">
            <span className="font-mono text-sm text-muted-foreground shrink-0 mt-0.5">
              {String(index + 1).padStart(2, '0')}
            </span>
            <div className="flex-1 min-w-0">
              <h3 className="font-medium text-foreground">{item.title}</h3>
              <p className="mt-1 text-sm text-muted-foreground">{item.description}</p>
            </div>
          </div>
          <div className="mt-3 sm:mt-4 ml-0 sm:ml-10 overflow-x-auto">
            <CodeBlock code={item.code} language="bash" />
          </div>
        </div>
      ))}
    </div>
  )
}

export default function QuickstartPage() {
  return (
    <div className="min-h-screen py-12 sm:py-16 md:py-24">
      <div className="mx-auto max-w-3xl px-4 sm:px-6">
        {/* Header */}
        <header>
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Quick Start
          </p>
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            Get started in 30 minutes
          </h1>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            Transform a fresh server into a fully-configured Ethereum node.
          </p>
        </header>
        
        {/* Prerequisites */}
        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Prerequisites
          </h2>
          <ul className="mt-4 space-y-3">
            {PREREQUISITES.map((prereq) => (
              <li key={prereq.label} className="flex items-start gap-3">
                <span className="h-1.5 w-1.5 rounded-full bg-primary shrink-0 mt-2" />
                <div className="min-w-0">
                  <span className="font-medium text-foreground">{prereq.label}</span>
                  <span className="text-muted-foreground"> — {prereq.value}</span>
                </div>
              </li>
            ))}
          </ul>
        </section>
        
        {/* Recommended Specs */}
        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Recommended Specs
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Minimum: 4 cores, 16GB RAM, 2TB SSD. Cloud instances may not finish syncing; bare metal VPS preferred.
          </p>
          <div className="mt-4 flex flex-wrap gap-3 sm:gap-4">
            {RECOMMENDED_SPECS.map(({ label, value, icon: Icon }) => (
              <div
                key={label}
                className="flex items-center gap-2 rounded-lg border border-border bg-muted/30 px-3 py-2 sm:px-4 sm:py-2.5"
              >
                <Icon className="h-4 w-4 shrink-0 text-primary" />
                <span className="text-sm">
                  <span className="font-medium text-foreground">{label}:</span>{' '}
                  <span className="text-muted-foreground">{value}</span>
                </span>
              </div>
            ))}
          </div>
        </section>
        
        {/* Installation - One-liner */}
        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Option A: One-Line Installer
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Same command as the homepage. Runs the wizard, generates phase scripts.
          </p>
          
          <InstallationStepsList steps={INSTALLATION_STEPS_ONELINER} idPrefix="oneline" />
        </section>
        
        {/* Installation - Manual */}
        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Option B: Manual (git clone)
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Clone the repo, run run_1.sh, reboot, run_2.sh. Matches the README.
          </p>
          
          <InstallationStepsList steps={INSTALLATION_STEPS_MANUAL} idPrefix="manual" />
        </section>
        
        {/* Help section */}
        <section className="mt-10 sm:mt-16 rounded-xl border border-border bg-muted/30 p-4 sm:p-6">
          <h2 className="font-medium text-foreground">
            Need help?
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Check the documentation or open an issue on GitHub.
          </p>
          <div className="mt-4 flex flex-wrap gap-3">
            <Button href="/learn" variant="secondary" size="sm">
              Documentation
            </Button>
            <Button 
              href={`${SITE_CONFIG.github}/issues`} 
              variant="ghost" 
              size="sm" 
              external
            >
              Report Issue
            </Button>
          </div>
        </section>
        
        {/* Next Steps */}
        <section className="mt-10 sm:mt-16 flex flex-col sm:flex-row sm:items-center justify-between gap-4 rounded-xl border border-border p-4 sm:p-6">
          <div>
            <h2 className="font-medium text-foreground">
              Ready to learn more?
            </h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Explore client options and advanced configuration.
            </p>
          </div>
          <Button href="/learn" size="sm" className="shrink-0 self-start sm:self-center">
            Learn More
            <ArrowRight className="ml-2 h-4 w-4" />
          </Button>
        </section>
      </div>
    </div>
  )
}
