import type { Metadata } from 'next'
import { Card } from '@/components/ui/Card'
import { Badge } from '@/components/ui/Badge'
import { CodeBlock } from '@/components/ui/CodeBlock'
import { Button } from '@/components/ui/Button'
import { 
  DOCUMENTATION_LINKS, 
  EXECUTION_CLIENTS, 
  CONSENSUS_CLIENTS, 
  SITE_CONFIG 
} from '@/lib/constants'
import { FileText, Github, ExternalLink, BookOpen } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Learn - Ethereum Node Setup Documentation',
  description: 'Comprehensive documentation for Ethereum node setup, client configuration, security, MEV integration, and RPC endpoints.',
}

const configExamples = [
  {
    title: 'Basic Configuration',
    description: 'Core settings in exports.sh',
    code: `# In exports.sh
export ETH_NETWORK='mainnet'
export FEE_RECIPIENT='0xYourAddress'
export GRAFITTI='YourNode'`,
  },
  {
    title: 'Client Selection',
    description: 'Choose your execution and consensus clients',
    code: `# Execution client
export EXEC_CLIENT='geth'

# Consensus client
export CONS_CLIENT='prysm'`,
  },
  {
    title: 'MEV Configuration',
    description: 'Set up MEV-Boost for validator rewards',
    code: `# MEV-Boost setup
export MEV_RELAYS='https://relay1,https://relay2'
export MIN_BID=0.002`,
  },
]

/**
 * Learn/Documentation page with docs links, client comparison, and examples
 */
export default function LearnPage() {
  return (
    <div className="min-h-screen py-12 sm:py-16">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center">
          <Badge variant="primary" className="mb-4">
            Documentation
          </Badge>
          <h1 className="font-mono text-3xl font-bold text-foreground sm:text-4xl lg:text-5xl">
            <span className="text-gradient">Learn & Explore</span>
          </h1>
          <p className="mx-auto mt-4 max-w-2xl text-lg text-muted-foreground">
            Comprehensive guides, client comparisons, and configuration examples
          </p>
        </div>
        
        {/* Documentation Links */}
        <section className="mt-12">
          <h2 className="flex items-center gap-2 font-mono text-2xl font-bold text-foreground">
            <BookOpen className="h-6 w-6 text-primary" />
            Documentation Hub
          </h2>
          
          <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {DOCUMENTATION_LINKS.map((doc) => (
              <a
                key={doc.path}
                href={`${SITE_CONFIG.github}/blob/main/${doc.path}`}
                target="_blank"
                rel="noopener noreferrer"
                className="group block"
              >
                <Card hover padding="md" className="h-full">
                  <div className="flex items-start gap-3">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 transition-colors group-hover:bg-primary/20">
                      <FileText className="h-5 w-5 text-primary" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <h3 className="flex items-center gap-1 font-semibold text-foreground">
                        {doc.title}
                        <ExternalLink className="h-3 w-3 text-muted-foreground" />
                      </h3>
                      <p className="mt-1 text-sm text-muted-foreground line-clamp-2">
                        {doc.description}
                      </p>
                    </div>
                  </div>
                </Card>
              </a>
            ))}
          </div>
        </section>
        
        {/* Execution Clients Table */}
        <section className="mt-16">
          <h2 className="font-mono text-2xl font-bold text-foreground">
            Execution Clients
          </h2>
          <p className="mt-2 text-muted-foreground">
            Choose from 6 execution layer clients
          </p>
          
          <div className="mt-6 overflow-x-auto">
            <table className="w-full border-collapse">
              <thead>
                <tr className="border-b border-border/30">
                  <th className="px-4 py-3 text-left font-mono text-sm font-semibold text-foreground">Client</th>
                  <th className="px-4 py-3 text-left font-mono text-sm font-semibold text-foreground">Language</th>
                  <th className="px-4 py-3 text-left font-mono text-sm font-semibold text-foreground">Description</th>
                  <th className="px-4 py-3 text-left font-mono text-sm font-semibold text-foreground">Best For</th>
                  <th className="px-4 py-3 text-left font-mono text-sm font-semibold text-foreground">Script</th>
                </tr>
              </thead>
              <tbody>
                {EXECUTION_CLIENTS.map((client, index) => (
                  <tr 
                    key={client.name} 
                    className={index % 2 === 0 ? 'bg-card/30' : ''}
                  >
                    <td className="px-4 py-3">
                      <Badge variant="primary" size="sm">{client.name}</Badge>
                    </td>
                    <td className="px-4 py-3 text-sm text-muted-foreground">{client.language}</td>
                    <td className="px-4 py-3 text-sm text-muted-foreground">{client.description}</td>
                    <td className="px-4 py-3 text-sm text-muted-foreground">{client.bestFor}</td>
                    <td className="px-4 py-3">
                      <code className="rounded bg-muted px-2 py-1 text-xs text-secondary">
                        {client.script}
                      </code>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
        
        {/* Consensus Clients Table */}
        <section className="mt-12">
          <h2 className="font-mono text-2xl font-bold text-foreground">
            Consensus Clients
          </h2>
          <p className="mt-2 text-muted-foreground">
            Choose from 6 consensus layer clients
          </p>
          
          <div className="mt-6 overflow-x-auto">
            <table className="w-full border-collapse">
              <thead>
                <tr className="border-b border-border/30">
                  <th className="px-4 py-3 text-left font-mono text-sm font-semibold text-foreground">Client</th>
                  <th className="px-4 py-3 text-left font-mono text-sm font-semibold text-foreground">Language</th>
                  <th className="px-4 py-3 text-left font-mono text-sm font-semibold text-foreground">Description</th>
                  <th className="px-4 py-3 text-left font-mono text-sm font-semibold text-foreground">Best For</th>
                  <th className="px-4 py-3 text-left font-mono text-sm font-semibold text-foreground">Script</th>
                </tr>
              </thead>
              <tbody>
                {CONSENSUS_CLIENTS.map((client, index) => (
                  <tr 
                    key={client.name} 
                    className={index % 2 === 0 ? 'bg-card/30' : ''}
                  >
                    <td className="px-4 py-3">
                      <Badge variant="secondary" size="sm">{client.name}</Badge>
                    </td>
                    <td className="px-4 py-3 text-sm text-muted-foreground">{client.language}</td>
                    <td className="px-4 py-3 text-sm text-muted-foreground">{client.description}</td>
                    <td className="px-4 py-3 text-sm text-muted-foreground">{client.bestFor}</td>
                    <td className="px-4 py-3">
                      <code className="rounded bg-muted px-2 py-1 text-xs text-secondary">
                        {client.script}
                      </code>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
        
        {/* Configuration Examples */}
        <section className="mt-16">
          <h2 className="font-mono text-2xl font-bold text-foreground">
            Configuration Examples
          </h2>
          <p className="mt-2 text-muted-foreground">
            Quick reference for common configuration patterns
          </p>
          
          <div className="mt-6 space-y-6">
            {configExamples.map((example) => (
              <Card key={example.title} padding="md">
                <h3 className="font-semibold text-foreground">{example.title}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{example.description}</p>
                <div className="mt-4">
                  <CodeBlock code={example.code} language="bash" />
                </div>
              </Card>
            ))}
          </div>
        </section>
        
        {/* GitHub Section */}
        <section className="mt-16">
          <Card padding="lg" className="bg-gradient-to-r from-primary/10 to-secondary/10 border-primary/20">
            <div className="flex flex-col items-center text-center sm:flex-row sm:text-left">
              <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full bg-card border border-border/30">
                <Github className="h-8 w-8 text-foreground" />
              </div>
              <div className="mt-4 flex-1 sm:ml-6 sm:mt-0">
                <h2 className="font-mono text-xl font-bold text-foreground">
                  Contribute on GitHub
                </h2>
                <p className="mt-2 text-muted-foreground">
                  Found an issue? Have a suggestion? Contributions are welcome! 
                  Check out our repository for the latest updates.
                </p>
                <div className="mt-4 flex flex-wrap justify-center gap-3 sm:justify-start">
                  <Button href={SITE_CONFIG.github} external size="sm">
                    View Repository
                  </Button>
                  <Button 
                    href={`${SITE_CONFIG.github}/issues`} 
                    external 
                    variant="secondary" 
                    size="sm"
                  >
                    Open Issue
                  </Button>
                  <Button 
                    href={`${SITE_CONFIG.github}/discussions`} 
                    external 
                    variant="secondary" 
                    size="sm"
                  >
                    Discussions
                  </Button>
                </div>
              </div>
            </div>
          </Card>
        </section>
      </div>
    </div>
  )
}
