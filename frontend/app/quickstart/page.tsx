import type { Metadata } from 'next'
import { CodeBlock } from '@/components/ui/CodeBlock'
import { Button } from '@/components/ui/Button'
import {
  INSTALLATION_STEPS_ONELINER,
  INSTALLATION_STEPS_MANUAL,
  PREREQUISITES,
  DOCUMENTATION_LINKS,
  EXECUTION_CLIENTS,
  CONSENSUS_CLIENTS,
  SITE_CONFIG,
} from '@/lib/constants'
import { ArrowRight, Server, HardDrive, Cpu, ExternalLink } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Get Started - ETH2 Quick Start',
  description: 'Get your Ethereum node running in 30 minutes. One-liner or manual install with run_1.sh and run_2.sh.',
}

const RECOMMENDED_SPECS = [
  { label: 'CPU', value: '8+ cores', icon: Cpu },
  { label: 'RAM', value: '32GB+', icon: Server },
  { label: 'Storage', value: '4TB NVMe', icon: HardDrive },
]

const CONFIG_EXAMPLES = [
  {
    title: 'Basic Setup',
    code: `# exports.sh
export ETH_NETWORK='mainnet'
export FEE_RECIPIENT='0xYourAddress'`,
  },
  {
    title: 'Client Selection',
    code: `export EXEC_CLIENT='geth'
export CONS_CLIENT='prysm'`,
  },
  {
    title: 'MEV Configuration',
    code: `export MEV_RELAYS='https://relay1,https://relay2'
export MIN_BID=0.002`,
  },
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
      <div className="mx-auto max-w-5xl px-4 sm:px-6">
        {/* Header */}
        <header>
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Get Started
          </p>
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            Set up your Ethereum node in 30 minutes
          </h1>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            Transform a fresh server into a fully-configured Ethereum node. Choose the one-liner or manual install.
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
            Same command as the homepage. Runs the wizard, generates install_phase1.sh and install_phase2.sh.
          </p>
          
          <InstallationStepsList steps={INSTALLATION_STEPS_ONELINER} idPrefix="oneline" />
        </section>
        
        {/* Installation - Manual */}
        <section id="manual" className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Option B: Manual (run_1.sh and run_2.sh)
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Clone the repo and use the pre-existing <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_1.sh</code> and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_2.sh</code> scripts. No wizard—these scripts are included in the repository.
          </p>
          
          <InstallationStepsList steps={INSTALLATION_STEPS_MANUAL} idPrefix="manual" />
        </section>
        
        {/* Documentation Links */}
        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Documentation
          </h2>
          <div className="mt-4 sm:mt-6 grid gap-3 sm:gap-4 sm:grid-cols-2">
            {DOCUMENTATION_LINKS.map((doc) => (
              <a
                key={doc.path}
                href={`${SITE_CONFIG.github}/blob/master/${doc.path}`}
                target="_blank"
                rel="noopener noreferrer"
                className="group flex items-start gap-3 sm:gap-4 rounded-xl border border-border p-3 sm:p-4 transition-colors hover:border-primary/20 hover:bg-muted/30"
              >
                <div className="flex-1 min-w-0">
                  <h3 className="flex items-center gap-2 font-medium text-foreground">
                    {doc.title}
                    <ExternalLink className="h-3.5 w-3.5 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
                  </h3>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {doc.description}
                  </p>
                </div>
              </a>
            ))}
          </div>
        </section>
        
        {/* Clients - Execution */}
        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Execution Clients
          </h2>
          <div className="mt-4 sm:mt-6 hidden sm:block overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">Client</th>
                  <th className="pb-3 font-medium text-muted-foreground">Language</th>
                  <th className="pb-3 font-medium text-muted-foreground">Best For</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {EXECUTION_CLIENTS.map((client) => (
                  <tr key={client.name}>
                    <td className="py-3 font-medium text-foreground">{client.name}</td>
                    <td className="py-3 text-muted-foreground">{client.language}</td>
                    <td className="py-3 text-muted-foreground">{client.bestFor}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {EXECUTION_CLIENTS.map((client) => (
              <div key={client.name} className="rounded-lg border border-border p-3">
                <div className="flex items-center justify-between">
                  <span className="font-medium text-foreground">{client.name}</span>
                  <span className="text-xs text-muted-foreground font-mono">{client.language}</span>
                </div>
                <p className="mt-1 text-sm text-muted-foreground">{client.bestFor}</p>
              </div>
            ))}
          </div>
        </section>
        
        {/* Clients - Consensus */}
        <section className="mt-8 sm:mt-12">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Consensus Clients
          </h2>
          <div className="mt-4 sm:mt-6 hidden sm:block overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">Client</th>
                  <th className="pb-3 font-medium text-muted-foreground">Language</th>
                  <th className="pb-3 font-medium text-muted-foreground">Best For</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {CONSENSUS_CLIENTS.map((client) => (
                  <tr key={client.name}>
                    <td className="py-3 font-medium text-foreground">{client.name}</td>
                    <td className="py-3 text-muted-foreground">{client.language}</td>
                    <td className="py-3 text-muted-foreground">{client.bestFor}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {CONSENSUS_CLIENTS.map((client) => (
              <div key={client.name} className="rounded-lg border border-border p-3">
                <div className="flex items-center justify-between">
                  <span className="font-medium text-foreground">{client.name}</span>
                  <span className="text-xs text-muted-foreground font-mono">{client.language}</span>
                </div>
                <p className="mt-1 text-sm text-muted-foreground">{client.bestFor}</p>
              </div>
            ))}
          </div>
        </section>
        
        {/* Configuration Examples */}
        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Configuration Examples
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            For manual install, edit exports.sh before running run_2.sh.
          </p>
          <div className="mt-4 sm:mt-6 space-y-5 sm:space-y-6">
            {CONFIG_EXAMPLES.map((example) => (
              <div key={example.title}>
                <h3 className="text-sm font-medium text-foreground">{example.title}</h3>
                <div className="mt-2 overflow-x-auto">
                  <CodeBlock code={example.code} language="bash" />
                </div>
              </div>
            ))}
          </div>
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
            <Button href="/#install" variant="secondary" size="sm">
              Install Command
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
        
        {/* GitHub CTA */}
        <section className="mt-10 sm:mt-16 flex flex-col sm:flex-row sm:items-center justify-between gap-4 rounded-xl border border-border p-4 sm:p-6">
          <div>
            <h2 className="font-medium text-foreground">
              Contribute on GitHub
            </h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Found an issue? Contributions are welcome.
            </p>
          </div>
          <Button href={SITE_CONFIG.github} external size="sm" className="shrink-0 self-start sm:self-center">
            View Repository
            <ArrowRight className="ml-2 h-4 w-4" />
          </Button>
        </section>
      </div>
    </div>
  )
}
