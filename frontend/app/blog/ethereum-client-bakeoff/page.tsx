import type { Metadata } from 'next'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { SITE_CONFIG } from '@/lib/constants'
import { ArrowRight } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Ethereum Client Bake-off - ETH2 Quick Start',
  description: 'Results from a 23-day Ethereum execution and consensus client sync campaign.',
}

const executionClients = [
  {
    name: 'Nethermind',
    result: 'synced',
    syncTime: '~14.5h',
    footprint: '~251 GiB (pruned) — smallest',
    syncMode: 'snap + Bonsai',
    mainnetShare: '36.0%',
    resultVariant: 'primary' as const,
  },
  {
    name: 'Geth',
    result: 'synced',
    syncTime: '~8h28m',
    footprint: '~1.13 TiB (pruned)',
    syncMode: 'snap + --history.chain postmerge',
    mainnetShare: '44.9%',
    resultVariant: 'default' as const,
  },
  {
    name: 'Ethrex',
    result: 'synced',
    syncTime: '~2h16m — fastest',
    footprint: '~286 → ~467 GiB (un-pruned, growing)',
    syncMode: 'snap (v19.0.0)',
    mainnetShare: '~0%',
    resultVariant: 'primary' as const,
  },
  {
    name: 'Besu',
    result: 'synced (un-pruned)',
    syncTime: '~19h18m',
    footprint: '~1.08 TiB (un-pruned)',
    syncMode: 'snap / Bonsai',
    mainnetShare: '17.4%',
    resultVariant: 'default' as const,
  },
  {
    name: 'Reth',
    result: 'hit 72h cap (~21%)',
    syncTime: 'did not finish',
    footprint: '~0.98 TiB (partial)',
    syncMode: 'full-sync-only',
    mainnetShare: '1.5%',
    resultVariant: 'default' as const,
  },
  {
    name: 'Nimbus-eth1',
    result: 'hit 72h cap (~21.6%)',
    syncTime: 'did not finish',
    footprint: '~40 GB (partial)',
    syncMode: 'full-sync-only',
    mainnetShare: '~0%',
    resultVariant: 'default' as const,
  },
  {
    name: 'Erigon',
    result: 'no-sync',
    syncTime: 'deadlocked',
    footprint: '—',
    syncMode: 'OtterSync',
    mainnetShare: '~0%',
    resultVariant: 'default' as const,
  },
]

const consensusClients = [
  {
    name: 'Lodestar',
    footprint: '~177 MiB — smallest',
    pruneLever: 'pruneHistory=true',
    variant: 'primary' as const,
  },
  {
    name: 'Lighthouse',
    footprint: '~518 MiB',
    pruneLever: 'checkpoint-sync-url',
    variant: 'default' as const,
  },
  {
    name: 'Grandine',
    footprint: '~725 MiB',
    pruneLever: '--prune-storage',
    variant: 'default' as const,
  },
  {
    name: 'Teku',
    footprint: '~936 MiB',
    pruneLever: 'data-storage-mode=minimal',
    variant: 'default' as const,
  },
  {
    name: 'Nimbus',
    footprint: '~1.2 GiB — largest',
    pruneLever: 'history=prune',
    variant: 'default' as const,
  },
]

const outboundLinks = [
  {
    label: 'Read the full writeup',
    href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_BLOG.md`,
  },
  {
    label: 'How we tested this with Claude',
    href: `${SITE_CONFIG.github}/blob/53c76aff373f704555919b78d1dcb3fdfb37b2b3/docs/HOW_WE_TESTED_WITH_CLAUDE.md`,
  },
  {
    label: 'Raw results',
    href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`,
  },
  {
    label: 'Harness engineering deep-dive',
    href: `${SITE_CONFIG.github}/blob/64143ef61143fc88baca7efb3b53374ef42568c8/docs/CLIENT_BAKEOFF_HARNESS.md`,
  },
]

export default function EthereumClientBakeoffPage() {
  return (
    <div className="min-h-screen py-12 sm:py-16 md:py-24">
      <div className="mx-auto max-w-5xl px-4 sm:px-6">
        <header>
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Blog
          </p>
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            Ethereum client bake-off
          </h1>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            A 23-day field campaign comparing seven execution-client syncs and five consensus clients.
          </p>
          <div className="mt-4 flex flex-wrap gap-3 sm:mt-6">
            <Button
              href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_BLOG.md`}
              external
              variant="secondary"
              size="sm"
            >
              Read the full writeup
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
            <Button
              href={`${SITE_CONFIG.github}/blob/53c76aff373f704555919b78d1dcb3fdfb37b2b3/docs/HOW_WE_TESTED_WITH_CLAUDE.md`}
              external
              variant="ghost"
              size="sm"
            >
              How we tested this
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
          </div>
        </header>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            TL;DR
          </h2>
          <div className="mt-4 grid gap-3 sm:gap-4 md:grid-cols-2">
            <Card padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">Disk winner — Nethermind, ~251 GiB</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                Pruned Nethermind was ~4.5x smaller than geth, the smallest of any client that finished a pruned, apples-to-apples sync.
              </p>
            </Card>
            <Card padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">Speed winner — ethrex, ~2h16m</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                The fastest cold sync in the field by a wide margin; the next fastest was geth at ~8h28m.
              </p>
            </Card>
            <Card padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">The twist — ethrex&apos;s restart-resync cliff</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                ethrex throws away synced state and re-syncs from scratch (~2h) after downtime past a hard edge of ~128 blocks, roughly 24–25 minutes. This operability tax is the likely reason the fastest-syncing client in the field has close to zero real-world mainnet adoption.
              </p>
            </Card>
            <Card padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">The CL layer is effectively solved</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                All five consensus clients checkpoint-synced to a validating head in about 22–23 minutes with zero failures; footprint is the only real differentiator.
              </p>
            </Card>
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            Restart resilience is a real, under-reported axis—separate from raw sync speed and disk footprint.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            EL scorecard
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Each execution-client run used a fixed Prysm consensus client and a 72-hour cap.
          </p>
          <div className="mt-4 sm:mt-6 hidden sm:block overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">EL</th>
                  <th className="pb-3 font-medium text-muted-foreground">Result</th>
                  <th className="pb-3 font-medium text-muted-foreground">Sync time</th>
                  <th className="pb-3 font-medium text-muted-foreground">Footprint</th>
                  <th className="pb-3 font-medium text-muted-foreground">Sync mode</th>
                  <th className="pb-3 font-medium text-muted-foreground">Mainnet share</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {executionClients.map((client) => (
                  <tr key={client.name}>
                    <td className="py-3 font-medium text-foreground">{client.name}</td>
                    <td className="py-3"><Badge variant={client.resultVariant}>{client.result}</Badge></td>
                    <td className="py-3 text-muted-foreground">{client.syncTime}</td>
                    <td className="py-3 text-muted-foreground">{client.footprint}</td>
                    <td className="py-3 text-muted-foreground">{client.syncMode}</td>
                    <td className="py-3 text-muted-foreground">{client.mainnetShare}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {executionClients.map((client) => (
              <div key={client.name} className="rounded-lg border border-border p-3">
                <div className="flex items-center justify-between gap-3">
                  <span className="font-medium text-foreground">{client.name}</span>
                  <Badge variant={client.resultVariant}>{client.result}</Badge>
                </div>
                <dl className="mt-3 space-y-2 text-sm">
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Sync time</dt>
                    <dd className="text-right text-foreground">{client.syncTime}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Footprint</dt>
                    <dd className="text-right text-foreground">{client.footprint}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Sync mode</dt>
                    <dd className="text-right text-foreground">{client.syncMode}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Mainnet share</dt>
                    <dd className="text-right text-foreground">{client.mainnetShare}</dd>
                  </div>
                </dl>
              </div>
            ))}
          </div>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            CL scorecard
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Each consensus client ran against a fixed EL anchor; all five synced.
          </p>
          <div className="mt-4 sm:mt-6 hidden sm:block overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">CL</th>
                  <th className="pb-3 font-medium text-muted-foreground">Footprint (geth anchor)</th>
                  <th className="pb-3 font-medium text-muted-foreground">History-prune lever</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {consensusClients.map((client) => (
                  <tr key={client.name}>
                    <td className="py-3 font-medium text-foreground">{client.name}</td>
                    <td className="py-3 text-muted-foreground">{client.footprint}</td>
                    <td className="py-3"><Badge variant={client.variant}>{client.pruneLever}</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {consensusClients.map((client) => (
              <div key={client.name} className="rounded-lg border border-border p-3">
                <div className="flex items-center justify-between gap-3">
                  <span className="font-medium text-foreground">{client.name}</span>
                  <span className="text-sm text-foreground">{client.footprint}</span>
                </div>
                <div className="mt-3 flex items-center justify-between gap-4">
                  <span className="text-sm text-muted-foreground">History-prune lever</span>
                  <Badge variant={client.variant}>{client.pruneLever}</Badge>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            How we tested
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            The campaign ran from 2026-06-22 to 2026-07-14 on a shared non-production host with MEV disabled and no validator keys. Every footprint came from the final near-cap <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">du</code> sample, never a mid-sync peak. Before a result counted, an automated config-optimality gate verified that the client was using its most disk-efficient mode; otherwise the harness rejected it rather than treating a configuration mistake as a client result. See <a href={`${SITE_CONFIG.github}/blob/53c76aff373f704555919b78d1dcb3fdfb37b2b3/docs/HOW_WE_TESTED_WITH_CLAUDE.md`} target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">the methodology and harness overview</a> for the full process.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Explore the campaign
          </h2>
          <div className="mt-4 flex flex-wrap gap-3">
            {outboundLinks.map((link) => (
              <Button key={link.href} href={link.href} external variant="secondary" size="sm">
                {link.label}
              </Button>
            ))}
          </div>
        </section>
      </div>
    </div>
  )
}
