import type { Metadata } from 'next'
import Link from 'next/link'
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
    result: 'hit 72h cap (47% by block, ~21% gas-weighted)',
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
    footprint: '~1.21 TiB (frozen partial, not a synced datadir)',
    syncMode: 'OtterSync',
    mainnetShare: '~0%',
    resultVariant: 'default' as const,
  },
]

// Both anchors were independently measured (docs/CLIENT_BAKEOFF_RESULTS.md: ethrex anchor is the
// primary/complete sweep; geth anchor is the cross-anchor confirmation re-run). Sorted by the
// ethrex-anchor footprint, the primary run. lodestar/lighthouse order flips between anchors — both
// sit in the smallest tier where the gap is small and measurement-window-sensitive (RESULTS.md).
const consensusClients = [
  {
    name: 'Lighthouse',
    ethrexAnchorFootprint: '~737 MiB — smallest',
    gethAnchorFootprint: '~518 MiB',
    pruneLever: 'checkpoint-sync-url',
    variant: 'primary' as const,
  },
  {
    name: 'Lodestar',
    ethrexAnchorFootprint: '~828 MiB',
    gethAnchorFootprint: '~177 MiB — smallest',
    pruneLever: 'pruneHistory=true',
    variant: 'default' as const,
  },
  {
    name: 'Grandine',
    ethrexAnchorFootprint: '~946 MB actual (sparse file)',
    gethAnchorFootprint: '~725 MiB actual (sparse file)',
    pruneLever: '--prune-storage',
    variant: 'default' as const,
  },
  {
    name: 'Teku',
    ethrexAnchorFootprint: '~2.01 GiB',
    gethAnchorFootprint: '~936 MiB',
    pruneLever: 'data-storage-mode=minimal',
    variant: 'default' as const,
  },
  {
    name: 'Nimbus',
    ethrexAnchorFootprint: '~4.94 GiB — largest',
    gethAnchorFootprint: '~1.2 GiB — largest',
    pruneLever: 'history=prune',
    variant: 'default' as const,
  },
]

// Every other metric CLIENT_BAKEOFF_RESULTS.md records that isn't in the scorecards above —
// peer counts, resource caps, re-run counts, config_optimal, and other candidate-level detail.
const fullMetrics = [
  { candidate: 'geth × prysm', peers: '—', configOptimal: 'yes', reRuns: 0, notable: 'Baseline; no large optimistic gap to close' },
  { candidate: 'nethermind × prysm', peers: '49', configOptimal: 'yes', reRuns: 1, notable: 'First attempt: 13.3h 0-peer loopback stall; re-run after ExternalIp fix synced clean' },
  { candidate: 'ethrex × prysm', peers: '50', configOptimal: 'yes', reRuns: 0, notable: '~10 GiB/hr disk growth even at tip; 1 auto-healed stale-pivot event' },
  { candidate: 'besu × prysm', peers: '~50', configOptimal: 'n/a (pruned re-run only)', reRuns: 2, notable: 'Un-pruned run synced clean; pruned re-run deadlocked twice, abandoned' },
  { candidate: 'reth × prysm', peers: '—', configOptimal: 'yes', reRuns: 1, notable: '578 samples; relaunched after --full fix; 47% by block / ~21% gas-weighted at cap' },
  { candidate: 'nimbus-eth1 × prysm', peers: '20–25', configOptimal: 'yes', reRuns: 1, notable: '72h continuous, 0 restarts; supersedes an earlier ~21 GB aborted run' },
  { candidate: 'erigon × prysm', peers: '—', configOptimal: 'n/a (no-sync)', reRuns: 0, notable: 'CPU cap raised 200%→600% mid-run; advanced ~5k blocks then re-froze' },
  { candidate: 'CL sweep × ethrex anchor (5 CLs)', peers: '—', configOptimal: 'yes (all 5)', reRuns: 2, notable: 'teku: JVM-OOM on first attempt (TEKU_CACHE fix); grandine: harness du-pipeline bug, not a client fault' },
  { candidate: 'CL sweep × geth anchor (5 CLs)', peers: '—', configOptimal: 'yes (all 5)', reRuns: 0, notable: 'Cross-anchor confirmation re-run; ranking reproduced' },
]

const completedExecutionSyncs = [
  { name: 'Ethrex', hours: 2.27, duration: '2h 16m' },
  { name: 'Geth', hours: 8.47, duration: '8h 28m' },
  { name: 'Nethermind', hours: 14.5, duration: '~14.5h' },
  { name: 'Besu', hours: 19.3, duration: '19h 18m' },
]

const syncChartMaxHours = 20

// GiB, verified against docs/CLIENT_BAKEOFF_RESULTS.md exact byte counts (Stage B footprint table + client-limitations table).
const elFootprints = [
  { name: 'Nimbus-eth1', gib: 37.3, label: '~40 GB', status: 'partial' as const },
  { name: 'Nethermind', gib: 251.1, label: '~251 GiB', status: 'synced' as const },
  { name: 'Ethrex', gib: 466.6, label: '~467 GiB', status: 'synced' as const },
  { name: 'Reth', gib: 1003.2, label: '~0.98 TiB', status: 'partial' as const },
  { name: 'Besu', gib: 1109.7, label: '~1.08 TiB', status: 'synced' as const },
  { name: 'Geth', gib: 1160.3, label: '~1.13 TiB', status: 'synced' as const },
  { name: 'Erigon', gib: 1242.6, label: '~1.21 TiB', status: 'frozen' as const },
]

const diskChartMaxGib = 1300

const outboundLinks = [
  {
    label: 'Read the full writeup',
    href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_BLOG.md`,
    external: true,
  },
  {
    label: 'How we tested this with Claude',
    href: '/blog/how-we-tested-with-claude',
    external: false,
  },
  {
    label: 'Raw results',
    href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`,
    external: true,
  },
  {
    label: 'Harness engineering deep-dive',
    href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_HARNESS.md`,
    external: true,
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
              href="/blog/how-we-tested-with-claude"
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
                All five consensus clients checkpoint-synced to a validating head in minutes — about 6–9 minutes on the geth anchor whose footprints are shown below, and ~22 minutes on the ethrex anchor. All five reached a validating head (teku and grandine after one re-run each — a JVM heap-sizing issue and a harness artifact, not client faults). Footprint is the main differentiator.
              </p>
            </Card>
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            Restart resilience is a real, under-reported axis—separate from raw sync speed and disk footprint.
          </p>
        </section>

        <section className="mt-10 sm:mt-16" aria-labelledby="sync-time-heading">
          <h2 id="sync-time-heading" className="text-lg sm:text-xl font-semibold text-foreground">
            Cold-sync time, at a glance
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Completed execution-client syncs only. The 72-hour-capped clients are intentionally excluded.
          </p>
          <figure className="mt-4 hidden sm:block" aria-labelledby="sync-time-chart-title" aria-describedby="sync-time-chart-description">
            <svg className="h-auto w-full" viewBox="0 0 680 210" role="img">
              <title id="sync-time-chart-title">Completed Ethereum execution-client cold-sync times</title>
              <desc id="sync-time-chart-description">
                Ethrex completed in 2 hours 16 minutes, Geth in 8 hours 28 minutes, Nethermind in approximately 14.5 hours, and Besu in 19 hours 18 minutes.
              </desc>
              {[0, 5, 10, 15, 20].map((hour) => {
                const x = 150 + (hour / syncChartMaxHours) * 420
                return (
                  <g key={hour}>
                    <line x1={x} x2={x} y1="24" y2="180" className="stroke-border" />
                    <text x={x} y="202" textAnchor="middle" className="fill-muted-foreground text-[12px]">
                      {hour}h
                    </text>
                  </g>
                )
              })}
              {completedExecutionSyncs.map((client, index) => {
                const y = 38 + index * 36
                const width = (client.hours / syncChartMaxHours) * 420
                return (
                  <g key={client.name}>
                    <text x="136" y={y + 15} textAnchor="end" className="fill-foreground text-[14px]">
                      {client.name}
                    </text>
                    <rect x="150" y={y} width={width} height="22" rx="4" className="fill-primary" />
                    <text x={Math.min(578, 160 + width)} y={y + 15} className="fill-foreground text-[13px]">
                      {client.duration}
                    </text>
                  </g>
                )
              })}
            </svg>
            <figcaption className="mt-2 text-xs text-muted-foreground">
              Time to a validating head on the same shared host. See the scorecard below for sync mode and footprint context.
            </figcaption>
          </figure>
          <dl className="mt-4 space-y-3 sm:hidden">
            {completedExecutionSyncs.map((client) => (
              <div key={client.name}>
                <div className="flex items-baseline justify-between gap-3 text-xs">
                  <dt className="font-medium text-foreground">{client.name}</dt>
                  <dd className="text-muted-foreground">{client.duration}</dd>
                </div>
                <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-muted" aria-hidden="true">
                  <div className="h-full rounded-full bg-primary" style={{ width: `${(client.hours / syncChartMaxHours) * 100}%` }} />
                </div>
              </div>
            ))}
          </dl>
          <p className="mt-3 text-xs text-muted-foreground sm:hidden">Bars use a shared 0–20 hour scale.</p>
        </section>

        <section className="mt-10 sm:mt-16" aria-labelledby="disk-heading">
          <h2 id="disk-heading" className="text-lg sm:text-xl font-semibold text-foreground">
            Disk footprint, at a glance
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            All seven execution clients. Muted bars didn&apos;t reach a clean synced state — partial (72h-capped) or frozen (erigon&apos;s no-sync deadlock) — so their footprint isn&apos;t comparable to the synced clients.
          </p>
          <figure className="mt-4 hidden sm:block" aria-labelledby="disk-chart-title" aria-describedby="disk-chart-description">
            <svg className="h-auto w-full" viewBox="0 0 680 300" role="img">
              <title id="disk-chart-title">Ethereum execution-client disk footprint</title>
              <desc id="disk-chart-description">
                Nimbus-eth1 partial about 40 GB, Nethermind synced about 251 GiB, Ethrex synced about 467 GiB, Reth partial about 0.98 TiB, Besu synced about 1.08 TiB, Geth synced about 1.13 TiB, Erigon frozen partial about 1.21 TiB.
              </desc>
              {[0, 250, 500, 750, 1000, 1250].map((gib) => {
                const x = 150 + (gib / diskChartMaxGib) * 420
                return (
                  <g key={gib}>
                    <line x1={x} x2={x} y1="24" y2="264" className="stroke-border" />
                    <text x={x} y="284" textAnchor="middle" className="fill-muted-foreground text-[12px]">
                      {gib === 0 ? '0' : `${gib}`}
                    </text>
                  </g>
                )
              })}
              {elFootprints.map((client, index) => {
                const y = 38 + index * 32
                const width = (client.gib / diskChartMaxGib) * 420
                return (
                  <g key={client.name}>
                    <text x="136" y={y + 14} textAnchor="end" className="fill-foreground text-[13px]">
                      {client.name}
                    </text>
                    <rect x="150" y={y} width={width} height="20" rx="4" className={client.status === 'synced' ? 'fill-primary' : 'fill-border'} />
                    <text x={Math.min(578, 160 + width)} y={y + 14} className="fill-foreground text-[12px]">
                      {client.label}{client.status !== 'synced' ? ` (${client.status})` : ''}
                    </text>
                  </g>
                )
              })}
              <text x="150" y="298" className="fill-muted-foreground text-[11px]">GiB</text>
            </svg>
            <figcaption className="mt-2 text-xs text-muted-foreground">
              Only geth and nethermind are pruned, apples-to-apples comparable — see &ldquo;Client limitations&rdquo; below for why the rest sit outside that comparison.
            </figcaption>
          </figure>
          <dl className="mt-4 space-y-3 sm:hidden">
            {elFootprints.map((client) => (
              <div key={client.name}>
                <div className="flex items-baseline justify-between gap-3 text-xs">
                  <dt className="font-medium text-foreground">{client.name}</dt>
                  <dd className="text-muted-foreground">{client.label}{client.status !== 'synced' ? ` (${client.status})` : ''}</dd>
                </div>
                <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-muted" aria-hidden="true">
                  <div className={`h-full rounded-full ${client.status === 'synced' ? 'bg-primary' : 'bg-border'}`} style={{ width: `${(client.gib / diskChartMaxGib) * 100}%` }} />
                </div>
              </div>
            ))}
          </dl>
          <p className="mt-3 text-xs text-muted-foreground sm:hidden">Bars use a shared 0–1300 GiB scale.</p>
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
            Each consensus client ran against a fixed EL anchor; all five synced on both anchors. Measured twice — against an ethrex anchor (the primary sweep) and again against a geth anchor (the cross-anchor confirmation) — to prove EL/CL decoupling empirically. Absolute size scales with how long the CL ran post-sync, not the EL anchor; the ranking holds on both.
          </p>
          <div className="mt-4 sm:mt-6 hidden sm:block overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">CL</th>
                  <th className="pb-3 font-medium text-muted-foreground">Footprint (ethrex anchor)</th>
                  <th className="pb-3 font-medium text-muted-foreground">Footprint (geth anchor)</th>
                  <th className="pb-3 font-medium text-muted-foreground">History-prune lever</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {consensusClients.map((client) => (
                  <tr key={client.name}>
                    <td className="py-3 font-medium text-foreground">{client.name}</td>
                    <td className="py-3 text-muted-foreground">{client.ethrexAnchorFootprint}</td>
                    <td className="py-3 text-muted-foreground">{client.gethAnchorFootprint}</td>
                    <td className="py-3"><Badge variant={client.variant}>{client.pruneLever}</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {consensusClients.map((client) => (
              <div key={client.name} className="rounded-lg border border-border p-3">
                <span className="font-medium text-foreground">{client.name}</span>
                <dl className="mt-2 space-y-1.5 text-sm">
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Ethrex anchor</dt>
                    <dd className="text-right text-foreground">{client.ethrexAnchorFootprint}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Geth anchor</dt>
                    <dd className="text-right text-foreground">{client.gethAnchorFootprint}</dd>
                  </div>
                </dl>
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
            The campaign ran from 2026-06-22 to 2026-07-14 on a shared non-production host with MEV disabled and no validator keys. Every footprint came from the final near-cap <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">du</code> sample, never a mid-sync peak. Before a result counted, an automated config-optimality gate verified that the client was using its most disk-efficient mode; otherwise the harness rejected it rather than treating a configuration mistake as a client result. See <Link href="/blog/how-we-tested-with-claude" className="text-primary hover:underline">the methodology and harness overview</Link> for the full process.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Every metric we collected
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            The scorecards above are the curated view. Everything else recorded per candidate — peer
            counts, config-optimality verification, re-run history, and other notable detail — is here
            so nothing measured is left out.
          </p>
          <div className="mt-4 sm:mt-6 hidden sm:block overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">Candidate</th>
                  <th className="pb-3 font-medium text-muted-foreground">Peers</th>
                  <th className="pb-3 font-medium text-muted-foreground">Config optimal</th>
                  <th className="pb-3 font-medium text-muted-foreground">Re-runs</th>
                  <th className="pb-3 font-medium text-muted-foreground">Notable</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {fullMetrics.map((row) => (
                  <tr key={row.candidate}>
                    <td className="py-3 align-top font-medium text-foreground">{row.candidate}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.peers}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.configOptimal}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.reRuns}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.notable}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {fullMetrics.map((row) => (
              <div key={row.candidate} className="rounded-lg border border-border p-3">
                <span className="font-medium text-foreground">{row.candidate}</span>
                <dl className="mt-2 space-y-1.5 text-xs">
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Peers</dt>
                    <dd className="text-right text-foreground">{row.peers}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Config optimal</dt>
                    <dd className="text-right text-foreground">{row.configOptimal}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Re-runs</dt>
                    <dd className="text-right text-foreground">{row.reRuns}</dd>
                  </div>
                </dl>
                <p className="mt-2 text-xs text-muted-foreground">{row.notable}</p>
              </div>
            ))}
          </div>
          <p className="mt-3 text-xs text-muted-foreground">
            Sourced from <a href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`} target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">CLIENT_BAKEOFF_RESULTS.md</a>, the campaign&apos;s source-of-truth data.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Explore the campaign
          </h2>
          <div className="mt-4 flex flex-wrap gap-3">
            {outboundLinks.map((link) => (
              <Button key={link.href} href={link.href} external={link.external} variant="secondary" size="sm">
                {link.label}
              </Button>
            ))}
          </div>
        </section>
      </div>
    </div>
  )
}
