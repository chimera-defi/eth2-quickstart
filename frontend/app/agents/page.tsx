import type { Metadata } from 'next'
import { AnchorHeading } from '@/components/ui/AnchorHeading'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { CodeBlock } from '@/components/ui/CodeBlock'
import { SITE_CONFIG } from '@/lib/constants'
import { ArrowRight, ExternalLink } from 'lucide-react'

const PAGE_TITLE = 'For AI Agents - ETH2 Quick Start'
const PAGE_DESCRIPTION =
  'How an AI agent can drive eth2-quickstart: the packaged skill, the MCP server, and the JSON-first CLI wrapper — plus the safety contract for validator funds.'
const PAGE_OG_ALT = 'eth2-quickstart for AI agents — skill, MCP server, and JSON CLI'

export const metadata: Metadata = {
  title: PAGE_TITLE,
  description: PAGE_DESCRIPTION,
  alternates: { canonical: '/agents' },
  openGraph: {
    type: 'website',
    siteName: SITE_CONFIG.shortName,
    url: '/agents',
    title: PAGE_TITLE,
    description: PAGE_DESCRIPTION,
    images: [{ url: '/og.png', width: 1200, height: 630, alt: PAGE_OG_ALT }],
  },
  twitter: {
    card: 'summary_large_image',
    title: PAGE_TITLE,
    description: PAGE_DESCRIPTION,
    images: [{ url: '/og.png', width: 1200, height: 630, alt: PAGE_OG_ALT }],
  },
}

const SKILL_INSTALL_SNIPPET = `# once published to ClawHub
clawhub install eth2-quickstart

# GitHub-path fallback (Codex-style skill installer)
python ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \\
  --repo chimera-defi/eth2-quickstart --path skills/eth2-quickstart`

const MCP_ADD_SNIPPET = `python3 -m pip install mcp

# Claude Code
claude mcp add eth2-quickstart -- ./mcp_server/run_eth2qs_mcp.sh
# or: ./scripts/install_claude_eth2qs_mcp.sh

# Codex
codex mcp add eth2-quickstart ./mcp_server/run_eth2qs_mcp.sh`

const CLI_SNIPPET = `# from an eth2-quickstart checkout
./scripts/eth2qs.sh doctor --json
./scripts/eth2qs.sh plan --json
./scripts/eth2qs.sh phase2 --execution=geth --consensus=prysm --mev=mev-boost
./scripts/eth2qs.sh validators --json`

const LEARN_MORE_LINKS = [
  {
    title: 'llms.txt',
    description: 'Raw-ingest agent instructions, served on this site.',
    href: '/llms.txt',
    external: true,
  },
  {
    title: 'llms-full.txt',
    description: 'Expanded agent-facing summary of install, operation, and cleanup.',
    href: '/llms-full.txt',
    external: true,
  },
  {
    title: 'SKILL.md',
    description: 'The skill entrypoint: routing rules and the full reference set.',
    href: `${SITE_CONFIG.github}/blob/master/skills/eth2-quickstart/SKILL.md`,
    external: true,
  },
  {
    title: 'Validator management',
    description: 'Full guide to the validator lifecycle commands and the MCP preview contract.',
    href: `${SITE_CONFIG.github}/blob/master/docs/VALIDATOR_MANAGEMENT.md`,
    external: true,
  },
]

export default function AgentsPage() {
  return (
    <div className="min-h-screen py-12 sm:py-16 md:py-24">
      <div className="mx-auto max-w-4xl px-4 sm:px-6">
        {/* Header */}
        <header>
          <Badge variant="primary">For Agents</Badge>
          <h1 className="mt-4 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            Run eth2-quickstart from an AI agent
          </h1>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            eth2-quickstart is a repo-aware toolkit for Ethereum node operators: a
            packaged agent skill, a local MCP server, and a JSON-first{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-sm">
              ./scripts/eth2qs.sh
            </code>{' '}
            CLI. An agent that clones the repo can bootstrap, operate, inspect,
            and clean a node stack using the same commands a human operator would
            run — without inventing a second toolchain.
          </p>
        </header>

        {/* What this is */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="what-this-is" className="text-lg sm:text-xl font-semibold text-foreground">
            What this is
          </AnchorHeading>
          <ul className="mt-4 space-y-3">
            <li className="flex items-start gap-3">
              <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
              <span className="text-muted-foreground">
                <span className="font-medium text-foreground">A packaged skill</span> —
                Anthropic skill-creator format, published via ClawHub, with 10 reference
                docs covering workflow, operator flows, safety, and sizing.
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
              <span className="text-muted-foreground">
                <span className="font-medium text-foreground">An MCP server</span> — a
                thin stdio wrapper for Claude Code and Codex that calls{' '}
                <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">
                  ./scripts/eth2qs.sh
                </code>{' '}
                directly; it does not reimplement install or operations logic.
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
              <span className="text-muted-foreground">
                <span className="font-medium text-foreground">A JSON CLI</span> — the
                same wrapper exposes <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">--json</code>{' '}
                on <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">doctor</code>,{' '}
                <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">plan</code>,{' '}
                <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">stats</code>,{' '}
                <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">validators</code>, and more,
                for agents that would rather parse structured output than screen-scrape.
              </span>
            </li>
          </ul>
        </section>

        {/* Install the skill */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="install-the-skill" className="text-lg sm:text-xl font-semibold text-foreground">
            Install the skill
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            The skill is repo-aware: install it, then use it from inside an
            <code className="mx-1 rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth2-quickstart</code>
            checkout.
          </p>
          <div className="mt-4 overflow-x-auto">
            <CodeBlock code={SKILL_INSTALL_SNIPPET} language="bash" />
          </div>
        </section>

        {/* Connect over MCP */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="connect-over-mcp" className="text-lg sm:text-xl font-semibold text-foreground">
            Connect over MCP
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            For agent runtimes with native tool support, register the local
            stdio server and run the agent from inside the repo checkout so it
            can resolve the canonical wrapper.
          </p>
          <div className="mt-4 overflow-x-auto">
            <CodeBlock code={MCP_ADD_SNIPPET} language="bash" />
          </div>
        </section>

        {/* Canonical commands */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="canonical-commands" className="text-lg sm:text-xl font-semibold text-foreground">
            Canonical commands
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Every command below has a machine-readable <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">--json</code> form.
            Prefer <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">doctor</code> and{' '}
            <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">plan</code> before any apply command.
          </p>
          <div className="mt-4 overflow-x-auto">
            <CodeBlock code={CLI_SNIPPET} language="bash" />
          </div>
        </section>

        {/* Safety contract */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="safety-contract" className="text-lg sm:text-xl font-semibold text-foreground">
            Safety contract
          </AnchorHeading>
          <Card className="mt-4 border-border/60 bg-muted/30">
            <ul className="space-y-3 text-sm text-muted-foreground">
              <li>
                <span className="font-medium text-foreground">No validator keys are generated or removed</span>{' '}
                by the agent layer — key generation happens on the node CLI (
                <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">validator-deploy</code>), never through MCP.
              </li>
              <li>
                <span className="font-medium text-foreground">Human confirmation is required</span> before
                root-required actions, reboot-causing steps, and destructive cleanup.
              </li>
              <li>
                <span className="font-medium text-foreground">Funds-affecting validator operations are preview-only via MCP.</span>{' '}
                The read-only tool <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">eth2qs_validator_op_preview</code>{' '}
                returns the exact node CLI command to run (exit, withdrawal-credential change,
                consolidation, EIP-7002 exit) — execution and confirmation always happen on the
                node CLI, never through MCP.
              </li>
              <li>
                <span className="font-medium text-foreground">Cleanup preserves secrets.</span>{' '}
                The data-purge flow is scoped to default data/state directories and is designed
                to preserve keys, keystores, wallets, and <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">~/secrets</code>.
              </li>
            </ul>
          </Card>
        </section>

        {/* Learn more */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="learn-more" className="text-lg sm:text-xl font-semibold text-foreground">
            Learn more
          </AnchorHeading>
          <div className="mt-4 sm:mt-6 grid gap-3 sm:gap-4 sm:grid-cols-2">
            {LEARN_MORE_LINKS.map((link) => (
              <a
                key={link.title}
                href={link.href}
                target={link.external ? '_blank' : undefined}
                rel={link.external ? 'noopener noreferrer' : undefined}
                className="group flex items-start gap-3 sm:gap-4 rounded-xl border border-border p-3 sm:p-4 transition-colors hover:border-primary/20 hover:bg-muted/30"
              >
                <div className="min-w-0 flex-1">
                  <h3 className="flex items-center gap-2 font-medium text-foreground">
                    {link.title}
                    <ExternalLink className="h-3.5 w-3.5 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
                  </h3>
                  <p className="mt-1 text-sm text-muted-foreground">{link.description}</p>
                </div>
              </a>
            ))}
          </div>
        </section>

        {/* CTA */}
        <section className="mt-10 sm:mt-16 flex flex-col sm:flex-row sm:items-center justify-between gap-4 rounded-xl border border-border p-4 sm:p-6">
          <div>
            <h2 className="font-medium text-foreground">Operating for a human?</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              The quickstart walks through the same two-phase install for people.
            </p>
          </div>
          <Button href="/quickstart" size="sm" className="shrink-0 self-start sm:self-center">
            Get Started
            <ArrowRight className="ml-2 h-4 w-4" />
          </Button>
        </section>
      </div>
    </div>
  )
}
