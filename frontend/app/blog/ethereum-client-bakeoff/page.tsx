import type { Metadata } from 'next'
import Link from 'next/link'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { SITE_CONFIG } from '@/lib/constants'
import { ArrowRight } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Ethereum Client Bake-off - ETH2 Quick Start',
  description:
    'The full write-up: results from a 23-day Ethereum execution and consensus client sync campaign, including the restart-resilience findings the headline numbers hide.',
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

const completedExecutionSyncs = [
  { name: 'Ethrex', hours: 2.27, duration: '2h 16m' },
  { name: 'Geth', hours: 8.47, duration: '8h 28m' },
  { name: 'Nethermind', hours: 14.5, duration: '~14h 30m' },
  { name: 'Besu', hours: 19.3, duration: '19h 18m' },
]

const syncChartMaxHours = 20

const restartBisection = [
  { gap: '12 min', blocks: '68', outcome: 'resumed cleanly', variant: 'primary' as const },
  { gap: '20 min', blocks: '108', outcome: 'resumed cleanly', variant: 'primary' as const },
  { gap: '23 min', blocks: '124', outcome: 'resumed cleanly', variant: 'primary' as const },
  { gap: '26 min', blocks: '132', outcome: 'stuck — Failed to fetch headers for sync head', variant: 'default' as const },
]

const sourceLinks = [
  {
    label: 'Full write-up',
    file: 'CLIENT_BAKEOFF_BLOG.md',
    href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_BLOG.md`,
  },
  {
    label: 'Methodology',
    file: 'HOW_WE_TESTED_WITH_CLAUDE.md',
    href: `${SITE_CONFIG.github}/blob/master/docs/HOW_WE_TESTED_WITH_CLAUDE.md`,
  },
  {
    label: 'Raw results',
    file: 'CLIENT_BAKEOFF_RESULTS.md',
    href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`,
  },
  {
    label: 'Harness deep-dive',
    file: 'CLIENT_BAKEOFF_HARNESS.md',
    href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_HARNESS.md`,
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
          <p className="mt-3 text-base font-medium italic text-foreground sm:text-lg">
            &ldquo;The Fastest Ethereum Client Is One Almost Nobody Runs&rdquo;
          </p>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            A 23-day field campaign comparing seven execution-client syncs and five consensus
            clients — the same mainnet sync, on the same host, one client at a time, recording two
            numbers for each: final synced disk footprint and sync duration. The interesting part
            is what fell out of it: an operability axis that turns out to matter more than either
            headline number, and a genuine paradox — the client that synced fastest in the whole
            field has essentially zero real-world adoption.
          </p>
          <div className="mt-4 flex flex-wrap gap-3 sm:mt-6">
            <Button
              href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_BLOG.md`}
              external
              variant="ghost"
              size="sm"
            >
              View source on GitHub
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
          </div>
        </header>

        <Card padding="sm" className="mt-8 border-primary/20 bg-primary/5">
          <p className="text-sm text-foreground">
            <span className="font-medium">Companion post:</span> this write-up covers the clients
            and the numbers. For the agent orchestration, the harness, and the methodology behind
            them, see{' '}
            <Link href="/blog/how-we-tested-with-claude" className="text-primary hover:underline">
              How We Ran a 23-Day Ethereum Client Bake-Off With Claude
            </Link>
            .
          </p>
        </Card>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            TL;DR
          </h2>
          <div className="mt-4 grid gap-3 sm:gap-4 md:grid-cols-2">
            <Card padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">Disk winner — Nethermind, ~251 GiB</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                Pruned Nethermind was ~4.6x smaller than geth, the smallest of any client that finished a pruned, apples-to-apples sync.
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
                All five consensus clients checkpoint-synced to a validating head in minutes — about 6–9 minutes on the geth anchor whose footprints are shown below, and ~22–23 minutes on the ethrex anchor. All five reached a validating head (teku and grandine after one re-run each — a JVM heap-sizing issue and a harness artifact, not client faults). Footprint is the main differentiator.
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
                Ethrex completed in 2 hours 16 minutes, Geth in 8 hours 28 minutes, Nethermind in about 14 hours 30 minutes, and Besu in 19 hours 18 minutes.
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
          <p className="mt-4 text-sm text-muted-foreground">
            Disk, pruned and apples-to-apples: Nethermind (~251 GiB) &lt; Geth (~1.13 TiB) — the
            only two with comparable numbers. Speed, among those that finished: ethrex (~2h16m)
            &lt; Geth (~8h28m) &lt; Nethermind (~14.5h) &lt; Besu (~19h18m). The other three fall
            out for a specific, documented reason each (below), not a blanket failure. This
            ranking also reproduced across two different EL anchors (ethrex and geth) — EL/CL
            decoupling, confirmed empirically. The rest of this post is the <em>why</em> behind
            these numbers.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            What we measured, and how we kept it honest
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            The campaign ran from 2026-06-22 to 2026-07-14 on a shared semi-production host (not a
            live validator), with MEV disabled and no validator keys. The bake-off measures, for
            each client, the final synced disk footprint and the sync duration: one candidate at a
            time, a 72-hour cap per candidate, and the footprint taken from the last near-cap{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">du</code> sample —
            never the peak mid-sync.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            For the EL scorecard we hold the CL constant at Prysm. That&apos;s defensible because
            an EL&apos;s footprint and sync time are EL-only properties, decoupled from the CL
            across the Engine API — the Prysm datadir ran ~0.65–1.68 GB in the bounded runs (up to ~12.5 GB during
            reth&apos;s full 72h cap), still negligible against an EL&apos;s hundreds of gigabytes. We confirmed the decoupling empirically later (see
            the CL matrix above), so this isn&apos;t just an assumption.
          </p>
          <Card padding="sm" className="mt-4 bg-muted/30">
            <h3 className="font-medium text-foreground">The honesty mechanism</h3>
            <p className="mt-1 text-sm text-muted-foreground">
              Early in the campaign we corrupted our own results by recording footprints before
              verifying each client was running in its most disk-efficient mode. A benchmark that
              measures your misconfiguration instead of the client is worse than no benchmark. So
              we built a config-optimality gate into the harness: it inspects the
              actually-generated, actually-running config and refuses to trust a footprint from a
              mis-configured client, stamping every row{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=yes|no</code>.
              The gate itself needed six bug-fixes across three review rounds before we trusted
              it — which is the point. Every number on this page is stamped optimal.
            </p>
          </Card>
          <p className="mt-3 text-sm text-muted-foreground">
            A knock-on benefit of that gate: it forced us to empirically settle config questions
            we&apos;d otherwise have guessed at. The clearest example is nimbus_eth1&apos;s
            history-pruning flag (below), where the binary&apos;s{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--help</code> and
            the online docs flatly contradicted each other — and only a live run resolved it. See{' '}
            <Link href="/blog/how-we-tested-with-claude" className="text-primary hover:underline">
              how we tested this with Claude
            </Link>{' '}
            for the full harness engineering process.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            The disk story: Nethermind wins, by a lot
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Only two clients produced a pruned, apples-to-apples footprint — geth and nethermind
            (see the EL scorecard above) — so the honest head-to-head disk ranking is exactly
            those two: Nethermind at <strong className="text-foreground">~251 GiB</strong> in
            ~14.5h, versus geth&apos;s ~1.13 TiB in ~8h28m.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Nethermind&apos;s Bonsai flat-DB plus snap sync lands it at roughly a quarter of
            geth&apos;s size. It&apos;s also a minority client, so choosing it modestly improves
            mainnet client diversity — a nice-to-have on top of the disk win. The cost is sync
            time: ~14.5h vs geth&apos;s ~8.5h. If disk is your binding constraint, this is the
            pick.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Everything else is <em>not</em> pruned-comparable, for a specific reason each, and we
            refuse to rank those on disk against a pruned node — that would be measuring different
            things. They&apos;re recorded transparently as client limitations:
          </p>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">besu</span> — synced, ~1.08 TiB
              (un-pruned), ~19h18m. Synced cleanly, but the pruned re-run for a comparable number
              deadlocked twice (below). Un-pruned → history-inflated.
            </li>
            <li>
              <span className="font-medium text-foreground">ethrex</span> — synced, ~286 GiB →
              ~467 GiB (growing), ~2h16m. Un-pruned and serves almost no history; datadir grows
              even at tip. Neither compact nor a full archive. Speed is its claim, not size.
            </li>
            <li>
              <span className="font-medium text-foreground">reth</span> — 72h cap at ~21%, ~0.98
              TiB partial. Full-sync-only (no snap) — can&apos;t reach tip in a practical window.
            </li>
            <li>
              <span className="font-medium text-foreground">nimbus_eth1</span> — 72h cap at
              ~21.6%, ~40 GB partial. Full-sync-only (no snap). Pruning works (below), but it
              can&apos;t finish in 72h.
            </li>
            <li>
              <span className="font-medium text-foreground">erigon</span> — deadlocked, no result.
              Optimistic-sync deadlock against a checkpoint-synced CL (below).
            </li>
          </ul>
          <p className="mt-3 text-sm text-muted-foreground">
            &ldquo;Outside the disk ranking&rdquo; does not mean &ldquo;failed to sync.&rdquo;
            besu in particular synced to a fully-validating head — it&apos;s here only because we
            don&apos;t have a pruned-comparable number for it.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            The speed story: ethrex wins, by a lot — and then loses it on restart
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            ethrex snap-synced to a fully-validating head in{' '}
            <strong className="text-foreground">~2h16m</strong>, the fastest in the field by
            nearly 4×. Fifty peers throughout, one automatic stale-pivot self-heal (~4 min, no
            intervention), no crash. On paper it&apos;s the star.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">Two things keep it out of the winners&apos; circle:</p>
          <ol className="mt-3 list-inside list-decimal space-y-2 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">The footprint isn&apos;t a fixed number.</span>{' '}
              ethrex prunes nothing and the datadir keeps growing even at the chain tip with{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_syncing=false</code>{' '}
              — we watched it climb 286 → 403 → 416 → ~467 GiB across a single day (~10 GiB/hr) —
              while simultaneously serving almost no history (
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_getBlockByNumber</code>{' '}
              returns <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">null</code>{' '}
              below head). So it is neither compact nor a full-history archive, and there&apos;s no
              steady-state size to rank.
            </li>
            <li>
              <span className="font-medium text-foreground">The restart cliff</span> — which is
              the marquee finding of the whole campaign, so it gets its own section, next.
            </li>
          </ol>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            The novel axis: restart resilience
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Cold-sync numbers tell you how a node behaves once, on day one. But operators restart
            nodes constantly — upgrades, config changes, crashes, host maintenance. &ldquo;What
            happens after a restart with a gap?&rdquo; is a first-class operational question, and
            it cleanly separates the field into three behaviors:
          </p>
          <ol className="mt-4 list-inside list-decimal space-y-3 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">Graceful resume.</span> The client
              comes back, imports the blocks it missed during the gap, and keeps its on-disk
              state. Minutes to catch up, no re-download. This is what makes a client
              operationally boring, in the good way. We measured this directly for geth: restarted
              after a ~52-hour gap, it kept its full datadir and caught up purely by sequential
              block-import (trie-diff application) — never re-snapping — and converged back to the
              validating tip. That&apos;s the exact positive contrast to ethrex&apos;s cliff.
              nethermind and reth are expected here by design too, though of the three only
              geth&apos;s resume was measured directly (as only ethrex&apos;s cliff was bisected).
            </li>
            <li>
              <span className="font-medium text-foreground">Re-snap cliff.</span> Past a downtime
              threshold the client discards its fully-synced state and re-syncs from scratch. Only
              ethrex lands here — and we pinned the edge precisely.
            </li>
            <li>
              <span className="font-medium text-foreground">Mid-sync deadlock.</span> If the CL
              stops driving the engine during an in-progress snap sync, the EL&apos;s pivot ages
              out of the network&apos;s servable-state window and the sync wedges irrecoverably —
              the process stays alive and answers RPC but makes zero progress. besu is the
              cautionary tale here.
            </li>
          </ol>
          <p className="mt-4 text-sm text-muted-foreground">
            Behaviors 2 and 3 share one root cause: a full node only serves recent world-state
            (roughly a ~128-block window). Once your head or pivot ages past it, peers can no
            longer serve the state you need to heal, so you can&apos;t resume by state — you&apos;re
            forced to re-pivot. Graceful-resume clients dodge this by importing gap blocks (always
            available) instead of re-fetching state.
          </p>

          <h3 className="mt-6 font-medium text-foreground">ethrex&apos;s cliff, bisected</h3>
          <p className="mt-2 text-sm text-muted-foreground">
            After a routine ~1.5–2h restart gap, a fully-synced ethrex (286 GiB, at mainnet head)
            abandoned its state and began a fresh full snap sync from the current head — datadir
            collapsing 286 GiB → ~9 GiB → climbing, journal showing{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">SNAP SYNC STARTED</code>{' '}
            from near-genesis,{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_blockNumber</code>{' '}
            at <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">0x0</code>{' '}
            throughout. It re-ran the entire ~2h pipeline. We reproduced it independently: a second
            restart triggered another full re-snap, timed at{' '}
            <strong className="text-foreground">2h11m</strong> — a clean second data point.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            The obvious follow-up: how big a gap actually trips it? We bisected it with controlled
            stop → wait → start cycles, a live prysm driving forkchoice:
          </p>
          <div className="mt-4 hidden sm:block overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">Downtime gap</th>
                  <th className="pb-3 font-medium text-muted-foreground">Blocks missed</th>
                  <th className="pb-3 font-medium text-muted-foreground">Outcome</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {restartBisection.map((row) => (
                  <tr key={row.gap}>
                    <td className="py-3 font-medium text-foreground">{row.gap}</td>
                    <td className="py-3 text-muted-foreground">{row.blocks}</td>
                    <td className="py-3"><Badge variant={row.variant}>{row.outcome}</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {restartBisection.map((row) => (
              <div key={row.gap} className="rounded-lg border border-border p-3">
                <div className="flex items-center justify-between gap-3">
                  <span className="font-medium text-foreground">{row.gap} gap</span>
                  <Badge variant={row.variant}>{row.outcome}</Badge>
                </div>
                <p className="mt-2 text-sm text-muted-foreground">{row.blocks} blocks missed</p>
              </div>
            ))}
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            <strong className="text-foreground">The cliff edge is ~128 blocks ≈ 24–25 minutes.</strong>{' '}
            And the bisection corrected our understanding of the mechanism: the true trigger is
            header-fetch failure once the gap exceeds the ~128-block servable window — not
            &ldquo;state expiry&rdquo; per se. Just past the edge, ethrex first stalls with a
            disconnected head (peers won&apos;t serve the gap headers); at larger gaps (~1.5–2h)
            that escalates to the full datadir-collapse re-snap. The stuck head is the onset; the
            re-snap is where it ends up.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <strong className="text-foreground">Why it matters:</strong> a client that re-syncs
            from scratch after any downtime beyond ~25 minutes is genuinely painful to operate —
            every upgrade or maintenance window longer than that costs a ~2h re-sync. That&apos;s a
            strong candidate explanation for ethrex&apos;s ~0% adoption despite best-in-field
            cold-sync numbers: great benchmark, painful to actually run.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <strong className="text-foreground">Fairness caveats (we state these plainly):</strong>{' '}
            observed on ethrex v19.0.0, a young client — this may well improve. The cliff does not
            change the recorded sync-time result; it&apos;s a separate resilience finding presented
            alongside, not folded into, the cold-sync number.
          </p>

          <h3 className="mt-6 font-medium text-foreground">besu&apos;s mid-sync deadlock</h3>
          <p className="mt-2 text-sm text-muted-foreground">
            besu&apos;s pruned re-run deadlocked twice and was abandoned — and the causal chain is
            a tidy production cautionary tale:
          </p>
          <ol className="mt-3 list-inside list-decimal space-y-2 text-sm text-muted-foreground">
            <li>
              A stale prysm v7.1.5 (a PeerDAS/data-column-sidecar bug) stalled the CL for ~28h;
              besu logged{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">Execution engine not called in 120 seconds</code>{' '}
              continuously.
            </li>
            <li>
              With no{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">forkchoiceUpdated</code>{' '}
              driving it, besu&apos;s snap-sync pivot aged out of the servable window — the
              world-state heal became un-completable.
            </li>
            <li>
              besu threw{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">IllegalStateException: The pivot block number has not increased</code>,
              cancelled its fast-sync download, and the downloader thread died without restarting.
              The process stayed alive and still answered{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_blockNumber</code>{' '}
              — but the sync engine was dead and the datadir frozen.
            </li>
            <li>Restarting resumed on the same stale pivot and re-deadlocked identically.</li>
          </ol>
          <p className="mt-3 text-sm text-muted-foreground">
            Takeaways: an in-progress besu snap sync is fragile to a prolonged CL outage — a stale
            CL binary can poison the EL&apos;s pivot irrecoverably; and besu answering RPC ≠ besu
            syncing (judge by disk growth and DB writes, not RPC liveness). Note the shared root
            with ethrex&apos;s cliff: same ~128-block servable-state window, one hitting mid-sync,
            the other post-sync-on-restart.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            The full-sync-only clients — and a contested flag, settled
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            reth and nimbus_eth1 have no snap-sync path; they full-sync from genesis. Both hit the
            72h cap far from tip (reth ~21%, ~0.98 TiB; nimbus_eth1 ~21.6%, ~40 GB). This is a
            client-design limitation for our snap-to-tip bar, not a failure — it would be unfair to
            rank a from-genesis full sync against a snap sync on either time or disk. reth in
            particular is widely and successfully run elsewhere.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            nimbus_eth1 did settle one open question for us. Its config carries{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">prune = true</code>,
            and whether that flag actually does anything was genuinely contested: the binary&apos;s{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--help</code> claims
            it prunes expired bodies and receipts, while the online docs say pre-merge history
            needs a separate era1 export — i.e. that the flag is effectively inert. We&apos;d
            flagged it &ldquo;unverified.&rdquo; The 72-hour run answered it directly: the journal
            logged continuous online pruning (
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">Pruning history … pruned=N</code>
            ) throughout block import. So the flag is <strong className="text-foreground">not</strong>{' '}
            inert — nimbus_eth1 prunes history online as it syncs. (Whether it reaches full
            pre-merge completeness versus an era1 import stays untestable here, since the node
            never reached tip — but the &ldquo;does it do anything?&rdquo; question is now a clean
            yes.) As a bonus data point, that run stayed up 72 hours with zero restarts: stable,
            just slow by design.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            erigon was the one hard deadlock: erigon3&apos;s OtterSync plus a checkpoint-synced
            prysm wedged in a mutual wait — erigon waiting for the CL to finalize, the CL waiting
            for erigon to execute — zero progress, no footprint. The single no-sync of the EL
            sweep.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Distribution is a <em>nuanced</em> predictor, not a flat one
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            A tempting story going in was &ldquo;mainnet share predicts syncability&rdquo; — the
            low/zero-share clients are exactly the ones that struggle. The data only half-supports
            it, and ethrex breaks it outright: a ~0%-share minimalist client synced fastest in the
            entire field. Several minority clients did struggle (erigon&apos;s deadlock; reth and
            nimbus_eth1 too slow by design), but the real predictor is snap-sync availability plus
            client robustness, not market share per se. ethrex has snap sync and clock-based
            stale-pivot self-healing during the initial sync — and it excelled at cold sync. Its
            adoption gap is far better explained by the restart cliff than by any sync deficiency.
            Don&apos;t write the flat version.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            The consensus layer is solved
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            We ran the five CLs — lighthouse, lodestar, grandine, teku, nimbus — against a constant
            anchor EL, and then repeated it against a second anchor EL to test the EL/CL decoupling
            claim directly. Every CL checkpoint-synced to a fully-validating head in minutes —{' '}
            <strong className="text-foreground">~22–23 minutes on the ethrex anchor</strong> and{' '}
            <strong className="text-foreground">~6–9 minutes on the geth anchor</strong> (whose
            footprints are in the CL scorecard above),{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=yes</code>,
            zero crashes (teku and grandine each needed one re-run — a JVM heap-sizing fix and a
            harness artifact, not client faults). Sync time is effectively tied within each anchor,
            so footprint is the differentiator.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Crucially, the ranking reproduced across both anchor ELs — the heavyweight tier
            (nimbus, teku) and the lightweight tier (lodestar, lighthouse, grandine) held on both,
            with only a lodestar↔lighthouse flip within the smallest tier. Two different EL
            anchors, the same CL ranking: EL/CL decoupling, confirmed empirically — which
            retroactively validates holding CL=prysm constant for the whole EL scorecard.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            The punchline: on the CL side, all five are operationally effective — none failed, and
            the choice comes down to footprint and preference (lighthouse is the lean, safe
            default). Operational risk in an Ethereum node lives in the EL layer, not the CL layer.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Recommendations
          </h2>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">Default: geth.</span> Largest
              ecosystem, most documentation, the cleanest snap sync (~8.5h), and it resumes
              gracefully across restarts. You pay for it in disk (~1.13 TiB). If you don&apos;t
              have a specific reason to run something else, run this.
            </li>
            <li>
              <span className="font-medium text-foreground">Disk-constrained: nethermind.</span>{' '}
              ~251 GiB — 4.6× leaner than geth — with clean restart behavior and a
              client-diversity bonus. Costs you sync time (~14.5h).
            </li>
            <li>
              <span className="font-medium text-foreground">Consensus client: lighthouse</span> as
              the lean default; any of the five is operationally fine — pick on footprint and
              familiarity.
            </li>
            <li>
              <span className="font-medium text-foreground">Watch, don&apos;t yet deploy: ethrex.</span>{' '}
              Fascinating and fastest, but the un-pruned/growing footprint and the ~25-minute
              restart cliff make it operationally costly today. Young (v19.0.0) — worth
              revisiting.
            </li>
            <li>
              <span className="font-medium text-foreground">Enterprise with care: besu.</span> It
              syncs, but its snap sync is fragile to CL outages; handle upgrades and CL health
              deliberately.
            </li>
            <li>
              <span className="font-medium text-foreground">Know the design limits:</span> reth
              and nimbus_eth1 are full-sync-only — excellent clients, but plan for a long initial
              sync rather than snap-to-tip. Avoid erigon3 + a checkpoint-synced CL until the
              optimistic-sync deadlock is resolved.
            </li>
          </ul>
          <p className="mt-4 text-sm text-muted-foreground">
            The most useful thing this bake-off surfaced isn&apos;t a single winner — it&apos;s
            that the number that matters to a running operator is often not the one on the
            benchmark chart. Cold-sync time and disk footprint are easy to measure and easy to
            publish. Restart resilience is neither, and it&apos;s the axis that most cleanly
            explains which clients people actually keep running.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <h2 className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Read next
          </h2>
          <ul className="mt-3 flex flex-wrap gap-x-6 gap-y-2 text-sm">
            <li>
              <Link href="/blog/how-we-tested-with-claude" className="text-primary hover:underline">
                How we tested with Claude
              </Link>
            </li>
            <li>
              <Link href="/blog/bakeoff-harness" className="text-primary hover:underline">
                The bake-off harness
              </Link>
            </li>
            <li>
              <Link href="/blog/bakeoff-results" className="text-primary hover:underline">
                Bake-off results (raw data)
              </Link>
            </li>
          </ul>
          <h2 className="mt-6 font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Source docs on GitHub
          </h2>
          <ul className="mt-3 flex flex-wrap gap-x-6 gap-y-2 text-sm">
            {sourceLinks.map((link) => (
              <li key={link.href}>
                <a
                  href={link.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-primary hover:underline"
                >
                  {link.label} <span className="text-muted-foreground">({link.file})</span>
                </a>
              </li>
            ))}
          </ul>
        </section>
      </div>
    </div>
  )
}
