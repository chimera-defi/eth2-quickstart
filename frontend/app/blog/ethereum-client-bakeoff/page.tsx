import type { Metadata } from 'next'
import Link from 'next/link'
import { AnchorHeading } from '@/components/ui/AnchorHeading'
import { ArticleJsonLd } from '@/components/ui/ArticleJsonLd'
import { ArticleToc } from '@/components/ui/ArticleToc'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { ReadNext } from '@/components/ui/ReadNext'
import { ArticleByline } from '@/components/ui/ArticleByline'
import { buildArticleMetadata } from '@/lib/articles'
import { SITE_CONFIG } from '@/lib/constants'
import { ArrowRight } from 'lucide-react'

export const metadata: Metadata = buildArticleMetadata('ethereum-client-bakeoff')

const tocLinks = [
  { label: 'TL;DR', href: '#tldr' },
  { label: 'Cold-sync time', href: '#sync-time-heading' },
  { label: 'Disk footprint', href: '#disk-heading' },
  { label: 'EL scorecard', href: '#el-scorecard' },
  { label: 'CL scorecard', href: '#cl-scorecard' },
  { label: 'Additional run details', href: '#additional-run-details' },
  { label: 'What we measured', href: '#what-we-measured' },
  { label: 'The disk story', href: '#the-disk-story' },
  { label: 'The speed story', href: '#the-speed-story' },
  { label: 'Restart resilience', href: '#restart-resilience' },
  { label: 'Full-sync-only clients', href: '#full-sync-only-clients' },
  { label: 'Distribution as predictor', href: '#distribution-as-predictor' },
  { label: 'Consensus layer solved', href: '#consensus-layer-solved' },
  { label: 'Recommendations', href: '#recommendations' },
]

const executionClients = [
  {
    name: 'Nethermind',
    result: 'synced',
    syncTime: '~14.5h',
    footprint: '~1.06 TiB steady-state (~251 GiB pre-backfill)',
    syncMode: 'snap + Halite',
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
    footprint: '~470 GiB steady-state plateau (no-history)',
    syncMode: 'snap (v19.0.0 at sync; v22.0.0 steady-state)',
    mainnetShare: '~0%',
    resultVariant: 'primary' as const,
  },
  {
    name: 'Besu',
    result: 'synced',
    syncTime: '~19h18m',
    footprint: '~1.08 TiB',
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

// All three anchors were independently measured (docs/CLIENT_BAKEOFF_RESULTS.md: ethrex anchor is
// the primary/complete sweep; geth anchor is the first cross-anchor confirmation re-run; nethermind
// anchor is the second). Sorted by the ethrex-anchor footprint, the primary run. One pair swaps
// order between anchors — lodestar/lighthouse (ethrex vs geth); on the nethermind anchor, teku
// instead shows ~27% variance against itself across two runs (~667 MiB vs ~848 MiB), crossing
// grandine's ~730 MiB and back — grandine < teku holds on all three anchors — but each pair stays
// within its own tier (lightweight / mid), where the gap is small and measurement-window-sensitive
// (RESULTS.md).
const consensusClients = [
  {
    name: 'Lighthouse',
    ethrexAnchorFootprint: '~737 MiB — smallest',
    gethAnchorFootprint: '~518 MiB',
    nethermindAnchorFootprint: '~470 MiB',
    pruneLever: 'checkpoint-sync-url',
    variant: 'primary' as const,
  },
  {
    name: 'Lodestar',
    ethrexAnchorFootprint: '~828 MiB',
    gethAnchorFootprint: '~177 MiB — smallest',
    nethermindAnchorFootprint: '~178 MiB — smallest',
    pruneLever: 'pruneHistory=true',
    variant: 'default' as const,
  },
  {
    name: 'Grandine',
    ethrexAnchorFootprint: '~946 MB actual (sparse file)',
    gethAnchorFootprint: '~725 MiB actual (sparse file)',
    nethermindAnchorFootprint: '~730 MiB actual (sparse file)',
    pruneLever: '--prune-storage',
    variant: 'default' as const,
  },
  {
    name: 'Teku',
    ethrexAnchorFootprint: '~2.01 GiB',
    gethAnchorFootprint: '~936 MiB',
    nethermindAnchorFootprint: '~848 MiB',
    pruneLever: 'data-storage-mode=minimal',
    variant: 'default' as const,
  },
  {
    name: 'Nimbus',
    ethrexAnchorFootprint: '~4.94 GiB — largest',
    gethAnchorFootprint: '~1.2 GiB — largest',
    nethermindAnchorFootprint: '~1.3 GiB — largest',
    pruneLever: 'history=prune',
    variant: 'default' as const,
  },
]

// Every other metric CLIENT_BAKEOFF_RESULTS.md records that isn't in the scorecards above —
// peer counts, resource caps, re-run counts, config_optimal, and other candidate-level detail.
const fullMetrics = [
  { candidate: 'geth × prysm', peers: '—', configOptimal: 'yes', reRuns: 0, notable: 'Baseline; no large optimistic gap to close' },
  { candidate: 'nethermind × prysm', peers: '49', configOptimal: 'yes', reRuns: 1, notable: 'First attempt: 13.3h 0-peer loopback stall; re-run after ExternalIp fix synced clean. Restart-resume measured and bisected (2026-08-01→03): every gap from 12 min to ~35h resumed by plain block import, no re-snap, no cliff' },
  { candidate: 'ethrex × prysm', peers: '50', configOptimal: 'yes', reRuns: 0, notable: 'Datadir plateaus at ~470–476 GiB (confirmed by a follow-up steady-state measurement run on v22.0.0, 4h09m56s snap, drifting 470.2→475.5 GiB over ~42h after); 1 auto-healed stale-pivot event; serves no history beyond its snap pivot' },
  { candidate: 'besu × prysm', peers: '~50', configOptimal: 'n/a (pruned re-run only)', reRuns: 2, notable: 'Un-pruned run synced clean; pruned re-run deadlocked twice, abandoned' },
  { candidate: 'reth × prysm', peers: '—', configOptimal: 'yes', reRuns: 1, notable: '578 samples; relaunched after --full fix; 47% by block / ~21% gas-weighted at cap' },
  { candidate: 'nimbus-eth1 × prysm', peers: '20–25', configOptimal: 'yes', reRuns: 1, notable: '72h continuous, 0 restarts; supersedes an earlier ~21 GB aborted run' },
  { candidate: 'erigon × prysm', peers: '—', configOptimal: 'n/a (no-sync)', reRuns: 0, notable: 'CPU cap raised 200%→600% mid-run; advanced ~5k blocks then re-froze' },
  { candidate: 'CL sweep × ethrex anchor (5 CLs)', peers: '—', configOptimal: 'yes (all 5)', reRuns: 2, notable: 'teku: JVM-OOM on first attempt (TEKU_CACHE fix); grandine: harness du-pipeline bug, not a client fault' },
  { candidate: 'CL sweep × geth anchor (5 CLs)', peers: '—', configOptimal: 'yes (all 5)', reRuns: 0, notable: 'Cross-anchor confirmation re-run; the lightweight/mid/heavy tiers reproduced (lodestar↔lighthouse swapped within the lightweight pair, vs. the ethrex primary)' },
  { candidate: 'CL sweep × nethermind anchor (5 CLs)', peers: '—', configOptimal: 'yes (all 5)', reRuns: 1, notable: "Second cross-anchor confirmation; teku re-measured (~667→~848 MiB across two runs on the same anchor, showing how window-sensitive the mid tier is); lodestar was re-measured after the anchor returned to head (~7m36s / ~178 MiB); its first attempt (~76m14s) was an anchor-gap artifact, not a lodestar property" },
]

const completedExecutionSyncs = [
  { name: 'Ethrex', hours: 2.27, duration: '2h 16m' },
  { name: 'Geth', hours: 8.47, duration: '8h 28m' },
  { name: 'Nethermind', hours: 14.5, duration: '~14h 30m' },
  { name: 'Besu', hours: 19.3, duration: '19h 18m' },
]

const syncChartMaxHours = 20

// GiB, verified against docs/CLIENT_BAKEOFF_RESULTS.md exact byte counts (Stage B footprint table + client-limitations table).
// Nethermind's synced-tip snapshot (~251 GiB) predates FastBlocks backfilling post-merge block
// bodies/receipts; steady-state (re-measured 2026-08-01) is ~1.06 TiB (~1,088 GiB: state ~226–230
// GiB + ~843 GiB post-merge bodies/receipts + ~19 GiB headers/code) — on par with the other ELs
// that retain full post-merge history. Ethrex's steady state is now measured too: it plateaus at
// ~470–476 GiB (confirmed 2026-07-28→31, drifting 470.2→475.5 GiB over ~42 flat-ish hours). Its
// bar stays hatched as "no-history," not because it's unsettled, but because a no-history node's
// total isn't comparable to the full-history bars below it.
const elFootprints = [
  { name: 'Nimbus-eth1', gib: 37.3, label: '~40 GB', status: 'partial' as const },
  { name: 'Ethrex', gib: 475.5, label: '~475 GiB', status: 'no-history' as const },
  { name: 'Reth', gib: 1003.2, label: '~0.98 TiB', status: 'partial' as const },
  { name: 'Nethermind', gib: 1088.1, label: '~1.06 TiB', status: 'synced' as const },
  { name: 'Besu', gib: 1109.7, label: '~1.08 TiB', status: 'synced' as const },
  { name: 'Geth', gib: 1160.3, label: '~1.13 TiB', status: 'synced' as const },
  { name: 'Erigon', gib: 1242.6, label: '~1.21 TiB', status: 'frozen' as const },
]

const diskChartMaxGib = 1300

const restartBisection = [
  { gap: '12 min', blocks: '68', outcome: 'resumed cleanly', variant: 'primary' as const },
  { gap: '20 min', blocks: '108', outcome: 'resumed cleanly', variant: 'primary' as const },
  { gap: '23 min', blocks: '124', outcome: 'resumed cleanly', variant: 'primary' as const },
  { gap: '26 min', blocks: '132', outcome: 'stuck — Failed to fetch headers for sync head', variant: 'default' as const },
]

// Steady-state composition (GiB) from the 2026-08-01 live re-measure (du per column family):
// blocks ~595 + receipts ~249 = ~843 GiB post-merge history; state ~228; headers+code ~19.
// Fills are a light→dark ramp of the site accent (sequential: parts of one whole, not identities).
const nethermindComposition = [
  { label: 'State (flat storage)', gib: 228, valueLabel: '~228 GiB', fill: '#e9d5ff' },
  { label: 'Block bodies', gib: 595, valueLabel: '~595 GiB', fill: '#c084fc' },
  { label: 'Receipts', gib: 249, valueLabel: '~249 GiB', fill: '#a855f7' },
  { label: 'Headers + code', gib: 19, valueLabel: '~19 GiB', fill: '#9333ea' },
]
const compositionScaleMaxGib = 1200
const ethrexNoHistoryGib = 475.5
const compositionSegments = (() => {
  let cum = 0
  return nethermindComposition.map((seg) => {
    const start = cum
    cum += seg.gib
    return { ...seg, start }
  })
})()
const compositionTotalGib = nethermindComposition.reduce((sum, seg) => sum + seg.gib, 0)
const compositionX = (gib: number) => 150 + (gib / compositionScaleMaxGib) * 420

// Restart gaps bridged, in blocks (log scale). ethrex rows are its 2026-07-10 bisection;
// nethermind's span the 2026-08-02→03 controlled bisection (69/151/301/1196 blk = 12m/30m/1h/4h)
// plus the 2026-08-01 opportunistic ~35h catch-up; geth is the 2026-07-10 ~52h resume.
// Position on a log axis is honest where bar length would not be.
const gapLogMin = 50
const gapLogMax = 25000
const gapX = (blocks: number) =>
  150 + ((Math.log10(blocks) - Math.log10(gapLogMin)) / (Math.log10(gapLogMax) - Math.log10(gapLogMin))) * 420

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
        <ArticleJsonLd slug="ethereum-client-bakeoff" />
        <header id="article-top" tabIndex={-1} className="focus:outline-none">
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Blog
          </p>
          <ArticleByline slug="ethereum-client-bakeoff" />
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            Ethereum client bake-off
          </h1>
          <p className="mt-3 text-base font-medium italic text-foreground sm:text-lg">
            &ldquo;The Fastest Ethereum Client Is One Almost Nobody Runs&rdquo;
          </p>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            A field campaign that began with a 23-day measurement phase (2026-06-22 → 2026-07-14)
            and continued with steady-state and restart-resume measurements through 2026-08-03,
            comparing seven execution-client syncs and five consensus clients — the same mainnet
            sync, on the same host, one client at a time, recording two numbers for each: final
            synced disk footprint and sync duration. The interesting part is what fell out of it:
            an operability axis that turns out to matter more than either headline number, and a
            genuine paradox — the client that synced fastest in the whole field has essentially
            zero real-world adoption.
          </p>
          <div className="mt-4 flex flex-wrap gap-3 sm:mt-6">
            <Button href="/deck/bakeoff.html" external variant="secondary" size="sm">
              View as slides
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
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
            <Link href="/blog/how-we-tested-with-claude" className="text-primary underline underline-offset-2">
              How We Ran a Six-Week Ethereum Client Bake-Off With Claude
            </Link>
            .
          </p>
        </Card>

        <ArticleToc links={tocLinks} />

        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="tldr" className="text-lg sm:text-xl font-semibold text-foreground">
            TL;DR
          </AnchorHeading>
          <div className="mt-4 grid gap-3 sm:gap-4 md:grid-cols-2">
            <Card padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">Disk: the field converges, ~1.0–1.2 TiB</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                Every EL that carries full post-merge history lands in the same band (geth 1.13 TiB, nethermind ~1.06 TiB, besu 1.08 TiB) — disk size is set by history-retention config, not client efficiency, so it isn&apos;t a good axis for picking a winner.
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
                Gaps through 23 minutes / 124 blocks resumed, while a 26-minute / 132-block gap stalled. Measured 1.5–2-hour gaps discarded synced state and triggered a full re-snap (~2h). This operability tax is the likely reason the fastest-syncing client in the field has close to zero real-world mainnet adoption.
              </p>
            </Card>
            <Card padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">The CL layer is effectively solved</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                All five consensus clients checkpoint-synced to a validating head in minutes — about 6–9 minutes on the geth anchor whose footprints are shown below, ~10 minutes on a third, nethermind anchor, and ~22–23 minutes on the ethrex anchor. All five reached a validating head on all three anchors (teku and grandine each needed a caveat along the way — a JVM heap-sizing issue, a harness artifact, and a watchdog false positive, not client faults). Footprint is the main differentiator.
              </p>
            </Card>
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            Restart resilience is a real, under-reported axis—separate from raw sync speed and disk footprint.
          </p>
        </section>

        <section className="mt-10 sm:mt-16" aria-labelledby="sync-time-heading">
          <AnchorHeading id="sync-time-heading" className="text-lg sm:text-xl font-semibold text-foreground">
            Cold-sync time, at a glance
          </AnchorHeading>
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

        <section className="mt-10 sm:mt-16" aria-labelledby="disk-heading">
          <AnchorHeading id="disk-heading" className="text-lg sm:text-xl font-semibold text-foreground">
            Disk footprint, at a glance
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            All seven execution clients. Hatched bars aren&apos;t a comparable finished
            footprint — partial (72h-capped), frozen (erigon&apos;s no-sync deadlock), or
            no-history (ethrex, which plateaus at ~470–476 GiB but serves no history) — so a short
            hatched bar isn&apos;t a win: Nimbus-eth1&apos;s ~40 GB is only ~21% of a sync,
            reth&apos;s ~0.98 TiB is a 72h-capped partial (projected to land in the same band as
            the solid bars once finished), and ethrex&apos;s ~470–476 GiB is a settled plateau, not a
            pruned-comparable footprint — it&apos;s smaller only because it retains no history at
            all, not because it&apos;s more efficient. The three solid bars (nethermind, besu,
            geth) converge in the same ~1.0–1.2 TiB band once full post-merge history is retained
            — disk size is set by that retention config, not client efficiency.
          </p>
          <figure className="mt-4 hidden sm:block" aria-labelledby="disk-chart-title" aria-describedby="disk-chart-description">
            <svg className="h-auto w-full" viewBox="0 0 680 300" role="img">
              <title id="disk-chart-title">Ethereum execution-client disk footprint</title>
              <desc id="disk-chart-description">
                Nimbus-eth1 partial about 40 GB, Ethrex no-history plateau about 470 to 476 GiB, Reth partial about 0.98 TiB, Nethermind synced about 1.06 TiB steady-state, Besu synced about 1.08 TiB, Geth synced about 1.13 TiB, Erigon frozen partial about 1.21 TiB.
              </desc>
              <defs>
                <pattern id="unfinished-bar" patternUnits="userSpaceOnUse" width="7" height="7" patternTransform="rotate(45)">
                  <rect width="7" height="7" className="fill-muted" />
                  <rect width="3.5" height="7" className="fill-border" />
                </pattern>
              </defs>
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
                    <rect x="150" y={y} width={width} height="20" rx="4" className={client.status === 'synced' ? 'fill-primary' : undefined} fill={client.status === 'synced' ? undefined : 'url(#unfinished-bar)'} />
                    <text x={Math.min(578, 160 + width)} y={y + 14} className="fill-foreground text-[12px]">
                      {client.label}{client.status !== 'synced' ? ` (${client.status})` : ''}
                    </text>
                  </g>
                )
              })}
              <text x="150" y="298" className="fill-muted-foreground text-[11px]">GiB</text>
            </svg>
            <figcaption className="mt-2 text-xs text-muted-foreground">
              geth, nethermind, and besu converge in the same ~1.0–1.2 TiB band — see &ldquo;The disk story&rdquo; below for why disk size isn&apos;t the axis that separates this field.
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
          <AnchorHeading id="el-scorecard" className="text-lg sm:text-xl font-semibold text-foreground">
            EL scorecard
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Each execution-client run used a fixed Prysm consensus client and a 72-hour cap.
          </p>
          <div
            className="mt-4 sm:mt-6 hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
            role="region"
            aria-label="Execution client scorecard"
            tabIndex={0}
          >
            <table className="w-full min-w-[48rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
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
          <AnchorHeading id="cl-scorecard" className="text-lg sm:text-xl font-semibold text-foreground">
            CL scorecard
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Each consensus client ran against a fixed EL anchor, and the full sweep was repeated
            against two more anchors (ethrex, then geth, then nethermind) to test EL/CL decoupling
            directly; all five synced on all three.
          </p>
          <div
            className="mt-4 sm:mt-6 hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
            role="region"
            aria-label="Consensus client scorecard"
            tabIndex={0}
          >
            <table className="w-full min-w-[48rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">CL</th>
                  <th className="pb-3 font-medium text-muted-foreground">Footprint (ethrex anchor)</th>
                  <th className="pb-3 font-medium text-muted-foreground">Footprint (geth anchor)</th>
                  <th className="pb-3 font-medium text-muted-foreground">Footprint (nethermind anchor)</th>
                  <th className="pb-3 font-medium text-muted-foreground">History-prune lever</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {consensusClients.map((client) => (
                  <tr key={client.name}>
                    <td className="py-3 font-medium text-foreground">{client.name}</td>
                    <td className="py-3 text-muted-foreground">{client.ethrexAnchorFootprint}</td>
                    <td className="py-3 text-muted-foreground">{client.gethAnchorFootprint}</td>
                    <td className="py-3 text-muted-foreground">{client.nethermindAnchorFootprint}</td>
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
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Nethermind anchor</dt>
                    <dd className="text-right text-foreground">{client.nethermindAnchorFootprint}</dd>
                  </div>
                </dl>
                <div className="mt-3 flex items-center justify-between gap-4">
                  <span className="text-sm text-muted-foreground">History-prune lever</span>
                  <Badge variant={client.variant}>{client.pruneLever}</Badge>
                </div>
              </div>
            ))}
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            The same client&apos;s three columns differ because absolute footprint tracks how long
            the CL had been following the chain when it was sampled — the geth- and
            nethermind-anchor runs were measured minutes after checkpoint-sync, on a fresher datadir
            — not which EL it paired with. It is the broad tiers (lightweight, mid, heavy), not the
            absolute size or exact within-tier order, that reproduce across anchors.
          </p>
          <p className="mt-4 text-sm text-muted-foreground">
            Disk: geth (~1.13 TiB), nethermind (~1.06 TiB steady-state), and besu (~1.08 TiB) all
            converge in the same band once full post-merge history is retained — there&apos;s no
            meaningful ranking to draw there. Speed, among those that finished: ethrex (~2h16m)
            &lt; Geth (~8h28m) &lt; Nethermind (~14.5h) &lt; Besu (~19h18m) — that&apos;s the axis
            that actually separates the field, along with restart-resume behavior. The other three
            EL candidates fall out for a specific, documented reason each (below), not a blanket
            failure. The CL tiers also reproduced across three different EL anchors (ethrex, geth,
            and nethermind): a lightweight pair (lodestar, lighthouse), a mid pair (grandine, teku),
            and nimbus alone at the heavy end — with lodestar and lighthouse swapping order between
            the ethrex and geth anchors. Within-tier order is measurement-window-sensitive: teku
            itself moved ~667 &rarr; ~848 MiB across two runs on the <em>same</em> nethermind anchor,
            crossing grandine (~730 MiB) and back. The rest of this post is the{' '}
            <em>why</em> behind these numbers.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="additional-run-details" className="text-lg sm:text-xl font-semibold text-foreground">
            Additional run details
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            The scorecards above are the curated view. This table adds peer counts,
            config-optimality verification, re-run history, and other notable per-candidate detail.
          </p>
          <div
            className="mt-4 sm:mt-6 hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
            role="region"
            aria-label="Additional per-candidate run details"
            tabIndex={0}
          >
            <table className="w-full min-w-[48rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
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
            Sourced from <a href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`} target="_blank" rel="noopener noreferrer" className="text-primary underline underline-offset-2">CLIENT_BAKEOFF_RESULTS.md</a>, the campaign&apos;s source-of-truth data — see the full{' '}
            <Link href="/blog/bakeoff-results" className="text-primary underline underline-offset-2">results on-site</Link>{' '}
            or the raw doc on GitHub.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="what-we-measured" className="text-lg sm:text-xl font-semibold text-foreground">
            What we measured, and how we kept it honest
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            The campaign began with a 23-day measurement phase (2026-06-22 → 2026-07-14) and
            continued with steady-state and restart-resume measurements through 2026-08-03, all on
            a shared semi-production host (not a live validator), with MEV disabled and no
            validator keys. The bake-off measures, for
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
            <AnchorHeading id="honesty-mechanism" as="h3" className="font-medium text-foreground">
              The honesty mechanism
            </AnchorHeading>
            <p className="mt-1 text-sm text-muted-foreground">
              Early in the campaign we corrupted our own results by recording footprints before
              verifying each client was running in its most disk-efficient mode. A benchmark that
              measures your misconfiguration instead of the client is worse than no benchmark. So
              we built a config-optimality gate into the harness: it inspects the
              actually-generated, actually-running config and refuses to trust a footprint from a
              mis-configured client, stamping every row{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=yes|no</code>.
              The gate itself needed six bug-fixes across three review rounds before we trusted
              it — which is the point. Every comparable footprint on this page comes from a synced
              run stamped <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=yes</code> (capped, no-sync, or pruned-only runs are marked as such and excluded from the ranking).
            </p>
          </Card>
          <p className="mt-3 text-sm text-muted-foreground">
            A knock-on benefit of that gate: it forced us to empirically settle config questions
            we&apos;d otherwise have guessed at. The clearest example is nimbus_eth1&apos;s
            history-pruning flag (below), where the binary&apos;s{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--help</code> and
            the online docs flatly contradicted each other — and only a live run resolved it. See{' '}
            <Link href="/blog/how-we-tested-with-claude" className="text-primary underline underline-offset-2">
              how we tested this with Claude
            </Link>{' '}
            for the full harness engineering process.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="the-disk-story" className="text-lg sm:text-xl font-semibold text-foreground">
            The disk story: there is no winner — the field converges
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Nethermind&apos;s synced-tip snapshot read <strong className="text-foreground">~251 GiB</strong>,
            well below geth&apos;s ~1.13 TiB — but that number was taken before nethermind&apos;s
            FastBlocks finished backfilling post-merge block bodies and receipts. Its steady-state
            datadir (re-measured 2026-08-01) is <strong className="text-foreground">~1.06 TiB</strong>{' '}
            (~1,088 GiB): state ~226–230 GiB (its compact Halite/Paprika flat storage) plus ~843 GiB
            of post-merge bodies and receipts plus ~19 GiB of headers and code, the same history
            geth keeps under{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--history.chain postmerge</code>.
            Under matched history-retention configs, nethermind and geth are on par.
            That history is a config choice, though: as of 2026-08-03 the shipped default turns it
            off (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">NETHERMIND_FULL_HISTORY=false</code>) —
            a fresh minimal-history sync drops the post-merge bodies and receipts and holds at{' '}
            <strong className="text-foreground">~250–280 GiB</strong> (state only) with no backfill, in
            exchange for serving no history (pre-sync blocks return <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">null</code>,
            like ethrex). It is the same retention lever turned down — not a client that is
            &ldquo;smaller&rdquo; — and you turn it back on with{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">NETHERMIND_FULL_HISTORY=true</code>{' '}
            on a fresh/rebuilt datadir for a public RPC; changing an existing minimal datadir
            requires a rebuild. The ~1.06 TiB figure and the chart below are that full-history opt-in.
            Among the measured no-history configurations in this campaign, nethermind is the smallest
            staking node — <strong className="text-foreground">~250–280 GiB against ethrex&apos;s ~470 GiB</strong>,
            and a floor geth cannot reach (it has no clean lever to drop post-merge history) — the one
            place its compact state engine is a genuine disk win, paid for by serving no history. It is
            not a claim that nethermind is 4× leaner than geth: that would score a no-history node
            against a with-history one.
          </p>
          <figure className="mt-4 hidden sm:block" aria-labelledby="composition-chart-title" aria-describedby="composition-chart-description">
            <svg className="h-auto w-full" viewBox="0 0 680 288" role="img">
              <title id="composition-chart-title">Nethermind full-history vs minimal-history default vs ethrex no-history datadir</title>
              <desc id="composition-chart-description">
                Nethermind&apos;s ~1.06 TiB full-history datadir is about 228 GiB of state, 595 GiB of block bodies, 249 GiB of receipts, and 19 GiB of headers and code. The minimal-history default (now shipped) drops the bodies and receipts, leaving about 250 GiB of state plus headers with no multi-day backfill. Ethrex&apos;s entire no-history datadir plateaus at about 475 GiB, so minimal nethermind is the smaller of the two no-history nodes; geth cannot drop below its ~1.1 TiB post-merge floor.
              </desc>
              <defs>
                <pattern id="composition-hatch" patternUnits="userSpaceOnUse" width="7" height="7" patternTransform="rotate(45)">
                  <rect width="7" height="7" className="fill-muted" />
                  <rect width="3.5" height="7" className="fill-border" />
                </pattern>
              </defs>
              {[0, 250, 500, 750, 1000].map((gib) => (
                <g key={gib}>
                  <line x1={compositionX(gib)} x2={compositionX(gib)} y1="28" y2="176" className="stroke-border" />
                  <text x={compositionX(gib)} y="192" textAnchor="middle" className="fill-muted-foreground text-[12px]">
                    {gib}
                  </text>
                </g>
              ))}
              <text x="600" y="192" className="fill-muted-foreground text-[11px]">GiB</text>

              <text x="136" y="52" textAnchor="end" className="fill-foreground text-[13px]">Nethermind</text>
              <text x="136" y="67" textAnchor="end" className="fill-muted-foreground text-[11px]">full history</text>
              {compositionSegments.map((seg) => (
                <rect
                  key={seg.label}
                  x={compositionX(seg.start)}
                  y="40"
                  width={Math.max(2, (seg.gib / compositionScaleMaxGib) * 420 - 2)}
                  height="24"
                  rx="2"
                  fill={seg.fill}
                />
              ))}
              <text x={compositionX(compositionTotalGib) + 8} y="56" className="fill-foreground text-[12px]">
                ~1.06 TiB · history
              </text>

              <text x="136" y="104" textAnchor="end" className="fill-foreground text-[13px]">Nethermind</text>
              <text x="136" y="119" textAnchor="end" className="fill-muted-foreground text-[11px]">minimal · default</text>
              {[{ label: 'min-state', gib: 228, start: 0, fill: '#e9d5ff' }, { label: 'min-headers', gib: 19, start: 228, fill: '#9333ea' }].map((seg) => (
                <rect
                  key={seg.label}
                  x={compositionX(seg.start)}
                  y="92"
                  width={Math.max(2, (seg.gib / compositionScaleMaxGib) * 420 - 2)}
                  height="24"
                  rx="2"
                  fill={seg.fill}
                />
              ))}
              <text x={compositionX(247) + 8} y="108" className="fill-foreground text-[12px]">
                ~250 GiB · no history
              </text>

              <text x="136" y="156" textAnchor="end" className="fill-foreground text-[13px]">Ethrex</text>
              <text x="136" y="171" textAnchor="end" className="fill-muted-foreground text-[11px]">no-history</text>
              <rect x="150" y="144" width={(ethrexNoHistoryGib / compositionScaleMaxGib) * 420} height="24" rx="4" fill="url(#composition-hatch)" />
              <text x={compositionX(ethrexNoHistoryGib) + 8} y="160" className="fill-foreground text-[12px]">
                ~475 GiB · no history
              </text>

              <text x="150" y="212" className="fill-muted-foreground text-[12px]">
                Minimal drops bodies + receipts → ~250 GiB — a no-history tier geth can&apos;t reach.
              </text>
              {compositionSegments.map((seg, index) => {
                const legendX = [60, 192, 334, 478][index]
                const legendLabel = ['State ~228 GiB', 'Bodies ~595 GiB', 'Receipts ~249 GiB', 'Headers+code ~19 GiB'][index]
                return (
                  <g key={seg.label}>
                    <rect x={legendX} y="234" width="10" height="10" rx="2" fill={seg.fill} />
                    <text x={legendX + 16} y="243" className="fill-muted-foreground text-[12px]">
                      {legendLabel}
                    </text>
                  </g>
                )
              })}
            </svg>
            <figcaption className="mt-2 text-xs text-muted-foreground">
              The full-history terabyte is mostly history: ~843 GiB of post-merge bodies and receipts on top of
              ~228 GiB of state. The minimal-history default (shipped 2026-08-03) keeps the state and drops that
              history — ~250 GiB, held with no backfill — at the cost of serving no historical RPC. Re-measured
              live 2026-08-01→03.
            </figcaption>
          </figure>
          <dl className="mt-4 space-y-3 sm:hidden">
            {nethermindComposition.map((seg) => (
              <div key={seg.label}>
                <div className="flex items-baseline justify-between gap-3 text-xs">
                  <dt className="font-medium text-foreground">{seg.label}</dt>
                  <dd className="text-muted-foreground">{seg.valueLabel}</dd>
                </div>
                <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-muted" aria-hidden="true">
                  <div className="h-full rounded-full" style={{ width: `${(seg.gib / compositionTotalGib) * 100}%`, backgroundColor: seg.fill }} />
                </div>
              </div>
            ))}
            <p className="text-xs text-muted-foreground">
              Full-history nethermind ~1.06 TiB. The minimal-history default drops bodies + receipts →
              ~250 GiB (state + headers), the smaller of the two no-history nodes (ethrex ~475 GiB) — and a
              tier geth can&apos;t reach.
            </p>
          </dl>
          <p className="mt-3 text-sm text-muted-foreground">
            besu lands in the same band too, at ~1.08 TiB — the same order of magnitude, not an
            outlier. reth (window-capped at 72h, 47% by block / ~21% gas-weighted) already tracked ~87% of geth&apos;s
            size at that point and projects to ~1.1–1.2 TiB finished. So the four ELs with full
            post-merge history — geth (1.13), nethermind (~1.06), besu (1.08), reth (~1.1–1.2
            projected) — converge on roughly the same footprint. Disk size here is set by a
            client-agnostic knob (how much post-merge history you retain), not by client
            efficiency, so it isn&apos;t a good axis for picking a winner.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            That leaves the axes that actually differ: <strong className="text-foreground">snap-sync
            speed</strong> and <strong className="text-foreground">restart-resume stability</strong>{' '}
            (both covered below). nethermind is still a good pick — its flat-storage state is
            genuinely compact, and it&apos;s a minority client, so running it improves mainnet
            client diversity — just not because it&apos;s smaller on disk than geth.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            The rest of the field didn&apos;t produce a comparable finished footprint, each for a
            specific, documented reason — not a blanket failure:
          </p>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">ethrex</span> — synced, ~2h16m,
              fastest in the field. Its datadir <strong className="text-foreground">plateaus at
              ~470–476 GiB</strong>: it climbed toward ~465 GiB during post-sync settling (+43 GiB/hr),
              then growth collapsed ~300× to +0.13 GiB/hr and drifted 470.2 → 475.5 GiB over ~42
              hours (confirmed 2026-07-28→31). The earlier ~467 GiB reading was this same plateau
              caught mid-climb, not evidence of unbounded growth. That doesn&apos;t make it a disk
              winner, though: it lands smaller only because it serves no history at all — a
              no-history node, not a pruned-comparable one. On a state-only basis it isn&apos;t even
              the smallest: nethermind&apos;s state alone is ~226–230 GiB, roughly half
              ethrex&apos;s entire total (not a perfectly controlled comparison — ethrex&apos;s
              total also includes headers and recent blocks, and the two clients use different
              state encodings).
            </li>
            <li>
              <span className="font-medium text-foreground">reth</span> — 72h cap at ~21%, ~0.98
              TiB partial. Full-sync-only (no snap) — can&apos;t reach tip in a practical window,
              though its trajectory already projects into the converged band above.
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
            besu, reth, and nimbus_eth1 all synced or made forward progress here — &ldquo;not a
            finished, comparable footprint&rdquo; does not mean &ldquo;failed.&rdquo; Only erigon
            produced no synced datadir at all.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            ethrex&apos;s no-history design has a concrete cost worth spelling out, since this repo
            ships an nginx/Caddy RPC-endpoint feature for exposing a node&apos;s RPC publicly.
            Probed live against the running node (2026-07-29), the servable window&apos;s back
            edge is <em>exactly</em> the snap-sync pivot block —{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_getBlockByNumber</code>{' '}
            returns <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">null</code>{' '}
            one block before it and resolves cleanly at and after it, and it never backfills.
            Current-state calls (balances, current quotes, allowances) work fine, but any block,
            log, or receipt before the pivot fails outright — effectively all of Ethereum history
            — which rules out indexer/subgraph backfill, portfolio history, and tax/accounting
            exports. A geth endpoint with <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--history.chain postmerge</code>{' '}
            serves that same history; an ethrex endpoint does not, so it isn&apos;t a drop-in
            replacement for a public DeFi-facing RPC.
          </p>
          <figure
            className="mt-5 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
            aria-label="Ethrex's servable RPC window: it returns null for all of Ethereum history from genesis through the snap-sync pivot, and serves only from the pivot forward to head"
          >
            <div className="flex items-stretch overflow-hidden rounded-lg border border-border">
              <div
                className="flex flex-1 items-center justify-center border-r-2 border-dashed border-[#e5726e]/40 px-3 py-3 text-center text-[11px] font-medium leading-snug text-[#e5726e] sm:text-xs"
                style={{
                  backgroundImage:
                    'repeating-linear-gradient(45deg, rgba(229,114,110,0.10), rgba(229,114,110,0.10) 6px, transparent 6px, transparent 12px)',
                }}
              >
                returns <code className="font-mono text-inherit">null</code> — all of Ethereum
                history (genesis → pivot)
              </div>
              <div className="relative flex w-16 flex-shrink-0 items-center justify-center bg-[#a855f7]/[0.14] px-2 py-3 text-center text-[11px] font-medium text-[#a855f7] sm:w-24 sm:text-xs">
                served
                <span className="absolute inset-y-0 right-0 w-[3px] bg-[#a855f7]" aria-hidden="true" />
              </div>
            </div>
            <div className="mt-2.5 flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1 px-0.5 text-[11px] text-muted-foreground">
              <span>genesis · block 0</span>
              <span>merge · 15,537,394</span>
              <span className="font-medium text-[#a855f7]">snap pivot · 25,634,445</span>
              <span>head</span>
            </div>
            <div className="mt-3.5 flex flex-wrap gap-x-4 gap-y-2 text-[11px] text-muted-foreground">
              <span className="inline-flex items-start gap-1.5">
                <span
                  className="mt-0.5 inline-block h-3 w-3 flex-shrink-0 rounded-sm border border-[#e5726e]/40 bg-[#e5726e]/10"
                  aria-hidden="true"
                />
                <span>
                  returns <code className="rounded bg-muted px-1 py-0.5 font-mono text-[10px]">null</code>{' '}
                  — pre-pivot blocks/logs/receipts (indexers, portfolio history, tax exports break)
                </span>
              </span>
              <span className="inline-flex items-start gap-1.5">
                <span
                  className="mt-0.5 inline-block h-3 w-3 flex-shrink-0 rounded-sm border border-[#a855f7]/50 bg-[#a855f7]/[0.14]"
                  aria-hidden="true"
                />
                <span>served — pivot → head (~4,783 blk at measurement; grows forward, never backfills)</span>
              </span>
              <span className="inline-flex items-start gap-1.5">
                <span className="mt-0.5 inline-block h-3 w-3 flex-shrink-0 rounded-sm bg-[#a855f7]" aria-hidden="true" />
                <span>state only — last ~128 blk (~25 min)</span>
              </span>
            </div>
            <p className="mt-2.5 text-center text-[11px] italic text-muted-foreground">
              not to scale — the served window is ~0.02% of the chain (4,783 of 25.6M blocks)
            </p>
            <figcaption className="mt-3 text-xs text-muted-foreground">
              ethrex answers from the block it snapped at, forward — the cutoff is <em>exactly</em>{' '}
              the pivot (probed to single-block precision). Wallet reads at head work fine; anything
              historical returns{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">null</code>. That&apos;s
              why its ~470 GiB isn&apos;t a disk win — it keeps almost no chain.
            </figcaption>
          </figure>
        </section>

        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="the-speed-story" className="text-lg sm:text-xl font-semibold text-foreground">
            The speed story: ethrex wins, by a lot — and then loses it on restart
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            ethrex snap-synced to a fully-validating head in{' '}
            <strong className="text-foreground">~2h16m</strong>, the fastest in the field by
            nearly 4×. Fifty peers throughout, one automatic stale-pivot self-heal (~4 min, no
            intervention), no crash. On paper it&apos;s the star.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">Two things keep it out of the winners&apos; circle:</p>
          <ol className="mt-3 list-inside list-decimal space-y-2 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">The footprint is settled now, and
              it&apos;s not comparable.</span>{' '}
              ethrex prunes nothing, and we watched the datadir climb even at the chain tip with{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_syncing=false</code>{' '}
              (286 → 403 → 416 → ~467 GiB across a single day, ~10 GiB/hr, 2026-07-06) — but a
              follow-up run confirmed that climb was settling, not unbounded: it plateaus at
              ~470–476 GiB (drifting 470.2 → 475.5 GiB over ~42 hours, 2026-07-28→31). That still doesn&apos;t make it a disk
              winner, because it simultaneously serves almost no history (
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_getBlockByNumber</code>{' '}
              returns <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">null</code>{' '}
              below its snap pivot). So it is neither compact nor a full-history archive — its
              settled size just isn&apos;t rankable against the full-history clients above.
            </li>
            <li>
              <span className="font-medium text-foreground">The restart cliff</span> — which is
              the marquee finding of the whole campaign, so it gets its own section, next.
            </li>
          </ol>
        </section>

        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="restart-resilience" className="text-lg sm:text-xl font-semibold text-foreground">
            The novel axis: restart resilience
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Cold-sync numbers tell you how a node behaves once, on day one. But operators restart
            nodes constantly — upgrades, config changes, crashes, host maintenance. &ldquo;What
            happens after a restart with a gap?&rdquo; is a first-class operational question, and
            it cleanly separates the field into three behaviors:
          </p>
          <figure
            className="mt-5 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
            aria-label="Three fates for an interrupted node: it catches back up (geth, nethermind), starts over past a roughly 25-minute gap (ethrex), or wedges alive but frozen if the interruption happens mid-sync (besu)"
          >
            <p className="text-center text-sm font-medium text-foreground">
              A running node gets interrupted
            </p>
            <p className="mt-1 text-center text-xs text-muted-foreground">
              what happens next depends on one thing: was it already synced, or still syncing?
            </p>
            <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="rounded-lg border border-border bg-background/40 p-3">
                <p className="text-center text-xs text-muted-foreground">Gap after it synced</p>
                <div className="mt-2 rounded-md border border-[#a855f7]/40 bg-[#a855f7]/10 p-2.5 text-xs">
                  <p className="text-foreground">
                    <strong className="text-[#a855f7]">Catches back up</strong> — geth, nethermind
                  </p>
                  <p className="mt-1 text-muted-foreground">
                    imports missed blocks, keeps datadir — minutes
                  </p>
                </div>
                <div className="mt-2 rounded-md border border-[#f5b46b]/40 bg-[#f5b46b]/10 p-2.5 text-xs">
                  <p className="text-foreground">
                    <strong className="text-[#f5b46b]">Starts over</strong> — ethrex, past a ~25-min gap
                  </p>
                  <p className="mt-1 text-muted-foreground">
                    discards state, re-snaps from scratch — ~2 h
                  </p>
                </div>
              </div>
              <div className="rounded-lg border border-border bg-background/40 p-3">
                <p className="text-center text-xs text-muted-foreground">Interrupted during sync</p>
                <div className="mt-2 rounded-md border border-[#e5726e]/40 bg-[#e5726e]/10 p-2.5 text-xs">
                  <p className="text-foreground">
                    <strong className="text-[#e5726e]">Wedges — alive but frozen</strong> — besu
                  </p>
                  <p className="mt-1 text-muted-foreground">
                    pivot ages out; answers RPC, writes 0 data — manual rebuild
                  </p>
                </div>
              </div>
            </div>
            <p className="mt-4 rounded-md border border-border bg-background/40 px-3 py-2 text-center text-xs text-muted-foreground">
              <strong className="text-foreground">Why:</strong> a full node serves only ~128 recent
              blocks of state (~25 min); cross that and you can&apos;t resume by state.
            </p>
            <figcaption className="mt-3 text-xs text-muted-foreground">
              Scope: the four clients with an observed restart or interruption outcome — geth,
              nethermind, and ethrex after syncing; besu mid-sync. reth, nimbus-eth1, and erigon
              never synced far enough to see one. Consensus layer: prysm resumed cleanly from its
              own DB in all four restart tests (~2m44s), no re-checkpoint.
            </figcaption>
          </figure>
          <ol className="mt-4 list-inside list-decimal space-y-3 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">Graceful resume.</span> The client
              comes back, imports the blocks it missed during the gap, and keeps its on-disk
              state. Minutes to catch up, no re-download. This is what makes a client
              operationally boring, in the good way. We measured this directly for geth: restarted
              after a ~52-hour gap, it kept its full datadir and caught up purely by sequential
              block-import (trie-diff application) — never re-snapping — and converged back to the
              validating tip. That&apos;s the exact positive contrast to ethrex&apos;s cliff.
              nethermind&apos;s resume is graceful too — see nethermind&apos;s resume, bisected,
              below — reth remains expected-by-design but unmeasured.
            </li>
            <li>
              <span className="font-medium text-foreground">Re-snap cliff.</span> Past a downtime
              threshold ethrex first stalls with a disconnected head; in the longer measured gaps
              it discarded its fully-synced state and re-synced from scratch. Only ethrex lands
              here — and we pinned the onset precisely.
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
          <figure className="mt-5 hidden sm:block" aria-labelledby="resume-chart-title" aria-describedby="resume-chart-description">
            <svg className="h-auto w-full" viewBox="0 0 680 250" role="img">
              <title id="resume-chart-title">Largest restart gap each client bridged, in blocks (log scale)</title>
              <desc id="resume-chart-description">
                Ethrex resumed gaps of 68, 108, and 124 blocks but stalled and re-snapped at 132 blocks — its cliff sits at roughly 128 blocks, about 25 minutes. Nethermind resumed every tested gap from 69 to 10,607 blocks (12 minutes to about 35 hours) with no cliff anywhere, and geth resumed a roughly 15,400-block, 52-hour gap.
              </desc>
              {[
                { blocks: 100, label: '100' },
                { blocks: 1000, label: '1,000' },
                { blocks: 10000, label: '10,000' },
              ].map((tick) => (
                <g key={tick.blocks}>
                  <line x1={gapX(tick.blocks)} x2={gapX(tick.blocks)} y1="28" y2="186" className="stroke-border" />
                  <text x={gapX(tick.blocks)} y="204" textAnchor="middle" className="fill-muted-foreground text-[12px]">
                    {tick.label}
                  </text>
                </g>
              ))}
              <text x="560" y="204" className="fill-muted-foreground text-[11px]">blocks (log scale)</text>
              <line x1={gapX(128)} x2={gapX(128)} y1="28" y2="186" strokeDasharray="4 4" className="stroke-muted-foreground" />
              <text x={gapX(128) + 8} y="20" className="fill-muted-foreground text-[12px]">
                ethrex re-snap cliff · ~128 blk ≈ 25 min
              </text>
              <text x="136" y="68" textAnchor="end" className="fill-foreground text-[13px]">Ethrex</text>
              {[68, 108, 124].map((blocks) => (
                <circle key={blocks} cx={gapX(blocks)} cy="64" r="5" fill="#a855f7" stroke="#09090b" strokeWidth="2" />
              ))}
              <circle cx={gapX(132)} cy="64" r="5" fill="#09090b" stroke="#fafafa" strokeWidth="2" />
              <text x="232" y="56" className="fill-muted-foreground text-[12px]">68 / 108 / 124 blk — resumed cleanly</text>
              <text x="232" y="74" className="fill-muted-foreground text-[12px]">132 blk — stalled, discarded state, ~2h re-snap</text>
              <text x="136" y="116" textAnchor="end" className="fill-foreground text-[13px]">Nethermind</text>
              {[69, 151, 301, 1196, 10607].map((blocks) => (
                <circle key={blocks} cx={gapX(blocks)} cy="112" r="5" fill="#a855f7" stroke="#09090b" strokeWidth="2" />
              ))}
              <text x="232" y="136" className="fill-muted-foreground text-[12px]">
                69 / 151 / 301 / 1,196 / 10,607 blk (12 min → ~35h) — every gap resumed
              </text>
              <text x="136" y="164" textAnchor="end" className="fill-foreground text-[13px]">Geth</text>
              <circle cx={gapX(15400)} cy="160" r="5" fill="#a855f7" stroke="#09090b" strokeWidth="2" />
              <text x={gapX(15400) - 12} y="164" textAnchor="end" className="fill-muted-foreground text-[12px]">
                ~15,400 blk (~52h) — resumed, no re-snap
              </text>
              <g>
                <circle cx="156" cy="232" r="5" fill="#a855f7" stroke="#09090b" strokeWidth="2" />
                <text x="168" y="236" className="fill-muted-foreground text-[12px]">resumed by block import</text>
                <circle cx="356" cy="232" r="5" fill="#09090b" stroke="#fafafa" strokeWidth="2" />
                <text x="368" y="236" className="fill-muted-foreground text-[12px]">stalled → re-snap</text>
              </g>
            </svg>
            <figcaption className="mt-2 text-xs text-muted-foreground">
              The axis is logarithmic: ethrex&apos;s resumed-vs-stalled dots sit 8 blocks apart, while
              nethermind resumed on both sides of that cliff and out to ~80× past it — no cliff at any
              tested gap. ethrex points are its bisection (2026-07-10); nethermind&apos;s span its
              controlled bisection (2026-08-02→03) plus the opportunistic ~35h catch-up (2026-08-01);
              geth is the ~52h resume (2026-07-10).
            </figcaption>
          </figure>
          <dl className="mt-4 space-y-2 text-sm sm:hidden">
            <div className="flex items-baseline justify-between gap-3">
              <dt className="font-medium text-foreground">Ethrex</dt>
              <dd className="text-right text-xs text-muted-foreground">resumed ≤124 blk; stalled → re-snap at 132 blk (~25 min)</dd>
            </div>
            <div className="flex items-baseline justify-between gap-3">
              <dt className="font-medium text-foreground">Nethermind</dt>
              <dd className="text-right text-xs text-muted-foreground">resumed every tested gap, 69 → 10,607 blk (12 min → ~35h); largest in 35m09s</dd>
            </div>
            <div className="flex items-baseline justify-between gap-3">
              <dt className="font-medium text-foreground">Geth</dt>
              <dd className="text-right text-xs text-muted-foreground">resumed ~15,400 blk (~52h), no re-snap</dd>
            </div>
          </dl>

          <AnchorHeading id="nethermind-resume-bisected" as="h3" className="mt-6 font-medium text-foreground">
            nethermind&apos;s resume, bisected
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Measured and then bisected (2026-08-01→03). First an opportunistic catch-up: a CL
            restart at 13:24:55Z left nethermind{' '}
            <strong className="text-foreground">10,607 blocks (~35h of chain) behind</strong> the
            external tip, and it closed the entire gap by ordinary block import in{' '}
            <strong className="text-foreground">35m09s (~302 blocks/min)</strong> with the datadir
            intact (1.165 → 1.178 TB, +1.1% — exactly the imported bodies/receipts). Then a
            controlled stop→wait→start bisection at{' '}
            <strong className="text-foreground">12 min / 30 min / 1 h / 4 h gaps</strong> (2026-08-02→03):
            every gap resumed geth-style — ordinary Engine-API block import, no re-pivot, no
            snap/state-sync, zero crashes. The tell is the state-dir delta:{' '}
            <strong className="text-foreground">~1.0–1.3 MiB per imported block, constant across
            rungs</strong> — linear import, the opposite of a re-snap, which would rewrite the whole
            ~238 GiB state. Resume time scales gently (121s at 12 min → 483s at 4 h → 35m09s at
            ~35 h), dominated by the CL re-syncing its missed slots, not the EL.{' '}
            <strong className="text-foreground">nethermind has no servable-window cliff</strong> — the
            direct contrast to ethrex&apos;s ~128-block cliff below. A separate
            establish run (2026-07-31) snap-synced nethermind fresh in{' '}
            <strong className="text-foreground">1h52m51s</strong> (~280 GiB at snap, pivot
            25,649,064, zero restarts) — far faster than the ~14.5h Stage-B figure because the
            pivot was minutes-old and near-tip, and network conditions differ; a second data
            point under different conditions, not a replacement for the Stage-B number. Artifacts:
            exp-lab runs <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">exp-a-nethermind-restart-resume-2026-07-31</code>{' '}
            and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">exp-a-bisection-2026-08-02</code>.
          </p>

          <AnchorHeading id="ethrex-cliff-bisected" as="h3" className="mt-6 font-medium text-foreground">
            ethrex&apos;s cliff, bisected
          </AnchorHeading>
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
          <div
            className="mt-4 hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
            role="region"
            aria-label="ethrex restart-gap bisection results"
            tabIndex={0}
          >
            <table className="w-full min-w-[42rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
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
            <strong className="text-foreground">Why it matters:</strong> a client that can stop
            resuming after ~25 minutes and, on longer measured gaps, fall into a ~2h re-snap is
            genuinely painful to operate. That&apos;s a strong candidate explanation for
            ethrex&apos;s ~0% adoption despite best-in-field cold-sync numbers: great benchmark,
            painful to actually run.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <strong className="text-foreground">Fairness caveats (we state these plainly):</strong>{' '}
            observed on ethrex v19.0.0, a young client — this may well improve. The cliff does not
            change the recorded sync-time result; it&apos;s a separate resilience finding presented
            alongside, not folded into, the cold-sync number.
          </p>

          <AnchorHeading id="besu-mid-sync-deadlock" as="h3" className="mt-6 font-medium text-foreground">
            besu&apos;s mid-sync deadlock
          </AnchorHeading>
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
          <AnchorHeading id="full-sync-only-clients" className="text-lg sm:text-xl font-semibold text-foreground">
            The full-sync-only clients — and a contested flag, settled
          </AnchorHeading>
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
          <AnchorHeading id="distribution-as-predictor" className="text-lg sm:text-xl font-semibold text-foreground">
            Distribution is a <em>nuanced</em> predictor, not a flat one
          </AnchorHeading>
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
          <AnchorHeading id="consensus-layer-solved" className="text-lg sm:text-xl font-semibold text-foreground">
            The consensus layer is solved
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            We ran the five CLs — lighthouse, lodestar, grandine, teku, nimbus — against a constant
            anchor EL, and then repeated it twice more against different anchor ELs to test the
            EL/CL decoupling claim directly. Every CL checkpoint-synced to a fully-validating head
            in minutes —{' '}
            <strong className="text-foreground">~22–23 minutes on the ethrex anchor</strong>,{' '}
            <strong className="text-foreground">~6–9 minutes on the geth anchor</strong> (whose
            footprints are in the CL scorecard above), and{' '}
            <strong className="text-foreground">~10 minutes on the nethermind anchor</strong>{' '}
            (lodestar&apos;s nethermind-anchor run took ~76 minutes, but that was an anchor-side
            block-gap artifact unrelated to lodestar itself — see the caveat in the raw results
            doc),{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=yes</code>,
            zero crashes (teku and grandine each needed a caveat across the sweeps — a JVM
            heap-sizing fix, a harness artifact, and, on the nethermind anchor, a watchdog false
            positive on teku&apos;s anchor-health verdict — not client faults). Sync time is
            effectively tied within each anchor, so footprint is the differentiator.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Crucially, the tiers reproduced across all three anchor ELs — a lightweight pair
            (lodestar, lighthouse), a mid pair (teku, grandine), and nimbus alone at the heavy end —
            with two swaps: lodestar↔lighthouse within the lightweight pair (ethrex vs geth), and
            teku itself across two runs on one anchor (~667 vs ~848 MiB). Three different EL anchors, the
            same three tiers, no identical total order: EL/CL decoupling, supported empirically —
            which retroactively validates holding CL=prysm constant for the whole EL scorecard.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            The punchline: on the CL side, all five are operationally effective — none failed, and
            the choice comes down to footprint and preference (lighthouse is the lean, safe
            default). Operational risk in an Ethereum node lives in the EL layer, not the CL layer.
          </p>
        </section>

        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="recommendations" className="text-lg sm:text-xl font-semibold text-foreground">
            Recommendations
          </AnchorHeading>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">Default: geth.</span> Largest
              ecosystem, most documentation, the cleanest snap sync (~8.5h), and it resumes
              gracefully across restarts. Its disk footprint (~1.13 TiB) is on par with the other
              ELs that carry full post-merge history — not a downside unique to geth. If you
              don&apos;t have a specific reason to run something else, run this.
            </li>
            <li>
              <span className="font-medium text-foreground">Diversity pick: nethermind.</span>{' '}
              Compact flat-storage state, a minority-client diversity bonus, and restart-resume
              that is now measured and bisected, not just assumed (2026-08-01→03: every gap from
              12 min to ~35h resumed by plain block import, no re-snap, no cliff — see
              &ldquo;Restart resilience&rdquo; above). On disk
              it&apos;s on par with geth (~1.06 vs ~1.13 TiB) once full post-merge history is
              counted — not the space-saver its snap-sync-tip snapshot (~251 GiB) suggested. Costs
              a bit more sync time (~14.5h vs geth&apos;s ~8.5h).
            </li>
            <li>
              <span className="font-medium text-foreground">Consensus client: lighthouse</span> as
              the lean default; any of the five is operationally fine — pick on footprint and
              familiarity.
            </li>
            <li>
              <span className="font-medium text-foreground">Watch, don&apos;t yet deploy: ethrex.</span>{' '}
              Fascinating and fastest, but the ~25-minute restart cliff makes it operationally
              costly today. Its footprint is now settled too — a ~470–476 GiB plateau — but that&apos;s
              not a disk win: it&apos;s a no-history node, and running its RPC in place of a
              full-history endpoint (this repo&apos;s nginx/Caddy feature) will silently fail on
              anything historical. Fast-moving client — v19.0.0 at first sync, v22.0.0 by
              this steady-state measurement — worth revisiting.
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

        <ReadNext currentSlug="ethereum-client-bakeoff" />

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <h2 className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
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
