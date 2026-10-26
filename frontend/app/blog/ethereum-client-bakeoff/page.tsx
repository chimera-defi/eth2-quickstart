import type { Metadata } from 'next'
import Link from 'next/link'
import { AnchorHeading } from '@/components/ui/AnchorHeading'
import { ArticleJsonLd } from '@/components/ui/ArticleJsonLd'
import { ArticleToc } from '@/components/ui/ArticleToc'
import { BackToTop } from '@/components/ui/BackToTop'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Details } from '@/components/ui/Details'
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
  { label: 'Consensus layer', href: '#consensus-layer-solved' },
  { label: 'Recommendations', href: '#recommendations' },
  { label: 'Bottom line', href: '#bottom-line' },
]

// The when/where/scope/how of the campaign, as one scannable card so the
// numbers below have context without the lede or "What we measured" repeating it.
const campaignFacts = [
  {
    title: 'When',
    body: '23-day measurement phase, 2026-06-22 → 2026-07-14; steady-state and restart-resume follow-ups through 2026-08-03.',
  },
  {
    title: 'Where',
    body: 'One shared semi-production host — not a live validator. MEV disabled, no validator keys.',
  },
  {
    title: 'Scope',
    body: 'Seven execution clients and five consensus clients, through the same mainnet sync — one client at a time, a 72-hour cap on each.',
  },
  {
    title: 'What we recorded',
    body: 'Two numbers: final disk footprint and cold-sync duration (syncing from scratch). Footprint is the end-of-run data directory, not the mid-sync peak. Capped runs use the last du disk-usage sample before the cap.',
  },
]

// The scannable answer to "which EL is worth running": one row per execution
// client, its known issue from this campaign, and a verdict. Every claim here
// is already established in more detail elsewhere on this page (EL scorecard,
// "The disk story," "Restart resilience," "The full-sync-only clients") — this
// table exists so a reader doesn't have to read the whole article to get it.
const clientIssues = [
  {
    name: 'Geth',
    verdict: 'Recommended' as const,
    issue: 'None found. Cleanest snap sync (~8.5h) and the only EL measured resuming a multi-day (~52h) gap without a re-snap.',
  },
  {
    name: 'Nethermind',
    verdict: 'Recommended' as const,
    issue: 'One installer bug, fixed: P2P defaulted to the loopback address, so the first run peered with 0 nodes for 13.3h before anyone noticed. Every gap tested after the fix resumed cleanly, up to ~35h.',
  },
  {
    name: 'Besu',
    verdict: 'Caution' as const,
    issue: "Synced cleanly once, but a pruned re-run deadlocked twice: if the CL stalls long enough mid-sync, besu's snap pivot ages out and the sync engine dies silently (the process keeps answering RPC).",
  },
  {
    name: 'Ethrex',
    verdict: 'Caution' as const,
    issue: 'Fastest cold sync in the field (~2h16m), but a restart gap past ~25 minutes stalls, and a gap of ~1.5–2h triggers a full re-snap from scratch. Serves no history before its sync pivot — not a drop-in public RPC.',
  },
  {
    name: 'Reth',
    verdict: 'Full-sync-only' as const,
    issue: 'No snap-sync path. Never reached tip inside the 72h cap on this host (47% by block count when capped) — a slow bootstrap, not a broken client.',
  },
  {
    name: 'Nimbus-eth1',
    verdict: 'Full-sync-only' as const,
    issue: 'Same limitation as reth: no snap-sync path. Ran a full 72 hours with zero restarts but reached only ~21.6% of tip.',
  },
  {
    name: 'Erigon',
    verdict: 'Avoid for now' as const,
    issue: "OtterSync deadlocked against a checkpoint-synced consensus client — each side waited on the other and neither issued the forkchoiceUpdated call that would break the tie. Never produced a synced datadir in this campaign, even after the consensus client's CPU cap was raised 3x.",
  },
]

const verdictStyle: Record<(typeof clientIssues)[number]['verdict'], { fg: string; bg: string; border: string }> = {
  Recommended: { fg: '#a855f7', bg: 'rgba(168,85,247,0.1)', border: 'rgba(168,85,247,0.4)' },
  Caution: { fg: '#f5b46b', bg: 'rgba(245,180,107,0.1)', border: 'rgba(245,180,107,0.4)' },
  'Full-sync-only': { fg: '#f5b46b', bg: 'rgba(245,180,107,0.1)', border: 'rgba(245,180,107,0.4)' },
  'Avoid for now': { fg: '#e5726e', bg: 'rgba(229,114,110,0.1)', border: 'rgba(229,114,110,0.4)' },
}

function VerdictBadge({ verdict }: { verdict: (typeof clientIssues)[number]['verdict'] }) {
  const s = verdictStyle[verdict]
  return (
    <span
      className="inline-flex items-center whitespace-nowrap rounded-md border px-2.5 py-0.5 font-mono text-xs font-medium"
      style={{ color: s.fg, backgroundColor: s.bg, borderColor: s.border }}
    >
      {verdict}
    </span>
  )
}

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
// instead shows ~25% variance against itself across two runs (~667 MiB vs ~835 MiB), crossing
// grandine's ~730 MiB and back — grandine < teku holds on all three anchors — but each pair stays
// within its own tier (lightweight / mid), where the gap is small and measurement-window-sensitive
// (RESULTS.md).
const consensusClients = [
  {
    name: 'Lighthouse',
    ethrexAnchorFootprint: '~739 MiB — smallest',
    gethAnchorFootprint: '~518 MiB',
    nethermindAnchorFootprint: '~470 MiB',
    pruneLever: 'checkpoint-sync-url',
    variant: 'primary' as const,
  },
  {
    name: 'Lodestar',
    ethrexAnchorFootprint: '~827 MiB',
    gethAnchorFootprint: '~177 MiB — smallest',
    nethermindAnchorFootprint: '~178 MiB — smallest',
    pruneLever: 'pruneHistory=true',
    variant: 'default' as const,
  },
  {
    name: 'Grandine',
    ethrexAnchorFootprint: '~946 MiB actual (sparse file)',
    gethAnchorFootprint: '~725 MiB actual (sparse file)',
    nethermindAnchorFootprint: '~730 MiB actual (sparse file)',
    pruneLever: '--prune-storage',
    variant: 'default' as const,
  },
  {
    name: 'Teku',
    ethrexAnchorFootprint: '~2.1 GiB',
    gethAnchorFootprint: '~936 MiB',
    nethermindAnchorFootprint: '~835 MiB',
    pruneLever: 'data-storage-mode=minimal',
    variant: 'default' as const,
  },
  {
    name: 'Nimbus',
    ethrexAnchorFootprint: '~5.0 GiB — largest',
    gethAnchorFootprint: '~1.2 GiB — largest',
    nethermindAnchorFootprint: '~1.3 GiB — largest',
    pruneLever: 'history=prune',
    variant: 'default' as const,
  },
]

// No verdict table for CLs: unlike the EL side, all five are "Recommended" —
// none failed to sync, none deadlocked. The only real signal is these three
// harness-side caveats, which read as instability if skimmed past in the
// prose paragraph above — worth a compact "was this the client's fault?" panel.
const consensusCaveats = [
  { cl: 'Teku', anchor: 'ethrex anchor', what: 'First attempt JVM-OOM-starved the shared host (64 min sync, briefly blipped the anchor); re-run with a larger JVM heap synced clean in 22 min.' },
  { cl: 'Grandine', anchor: 'ethrex anchor', what: 'First attempt crashed when du hit a datadir file that vanished mid-snapshot (a harness pipefail bug, since fixed); the re-run synced clean.' },
  { cl: 'Lodestar', anchor: 'nethermind anchor', what: 'First run took ~76 min — not a lodestar property; the anchor EL was still importing an unrelated 2-day gap at the time. Clean re-read: ~7m36s.' },
  { cl: 'Teku', anchor: 'nethermind anchor', what: "Watchdog reported a false anchor-health miss on both runs, latched during teku's JVM warm-up; the anchor was healthy when each measurement was actually taken." },
]

// Every other metric CLIENT_BAKEOFF_RESULTS.md records that isn't in the scorecards above —
// peer counts, resource caps, re-run counts, config_optimal, and other candidate-level detail.
const fullMetrics = [
  { candidate: 'geth × prysm', peers: '—', configOptimal: 'yes', reRuns: 0, notable: 'Baseline; no large optimistic gap to close' },
  { candidate: 'nethermind × prysm', peers: '49', configOptimal: 'yes', reRuns: 1, notable: 'First attempt: 13.3h 0-peer loopback stall; re-run after ExternalIp fix synced clean. Restart-resume measured and bisected (2026-08-01→03): every gap from 12 min to ~35h resumed by plain block import, no re-snap, no cliff' },
  { candidate: 'ethrex × prysm', peers: '50', configOptimal: 'yes', reRuns: 0, notable: 'Datadir plateaus at ~470–476 GiB (confirmed by a follow-up steady-state measurement run on v22.0.0, 4h09m56s snap, drifting 470.2→475.5 GiB over ~42h after); 1 auto-healed stale-pivot event; serves no history beyond its snap pivot' },
  { candidate: 'besu × prysm', peers: '~50', configOptimal: 'n/a from the harness gate; sync-flag audit: SNAP + Bonsai ✅', reRuns: 2, notable: 'Un-pruned run synced clean and is the ranked footprint; the pruned re-run deadlocked twice and was abandoned (no verdict)' },
  { candidate: 'reth × prysm', peers: '—', configOptimal: 'yes', reRuns: 1, notable: '578 samples; relaunched after --full fix; 47% by block / ~21% gas-weighted at cap' },
  { candidate: 'nimbus-eth1 × prysm', peers: '20–25', configOptimal: 'yes', reRuns: 1, notable: '72h continuous, 0 restarts; supersedes an earlier ~21 GB aborted run' },
  { candidate: 'erigon × prysm', peers: '—', configOptimal: 'n/a (no-sync)', reRuns: 0, notable: 'CL CPU cap raised 200%→600% mid-run; advanced ~5k blocks then re-froze' },
  { candidate: 'CL sweep × ethrex anchor (5 CLs)', peers: '—', configOptimal: 'yes (all 5)', reRuns: 2, notable: "teku: JVM-OOM on first attempt (TEKU_CACHE fix); grandine's first attempt failed on a harness du bug" },
  { candidate: 'CL sweep × geth anchor (5 CLs)', peers: '—', configOptimal: 'yes (all 5)', reRuns: 0, notable: 'Cross-anchor confirmation re-run; the lightweight/mid/heavy tiers reproduced (lodestar↔lighthouse swapped within the lightweight pair, vs. the ethrex primary)' },
  { candidate: 'CL sweep × nethermind anchor (5 CLs)', peers: '—', configOptimal: 'yes (all 5)', reRuns: 2, notable: "Second cross-anchor confirmation; teku re-measured (~667→~835 MiB across two runs on the same anchor, showing how window-sensitive the mid tier is); lodestar was re-measured after the anchor returned to head (~7m36s / ~178 MiB); its first attempt (~76m14s) was an anchor-gap artifact, not a lodestar property" },
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

function ConsensusSyncFigure() {
  const anchors = [
    { name: 'Geth', low: 6, high: 9, label: '~6–9 min' },
    { name: 'Nethermind', low: 7, high: 10, label: '~7–10 min' },
    { name: 'Ethrex', low: 22, high: 23, label: '~22–23 min' },
  ]

  return (
    <figure
      className="mt-4 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
      aria-label="All five consensus clients synced in minutes on each execution anchor, with the longest times on ethrex."
    >
      <div className="space-y-4">
        {anchors.map((anchor) => (
          <div key={anchor.name}>
            <div className="flex items-baseline justify-between gap-3 text-sm">
              <span className="font-medium text-foreground">{anchor.name} anchor</span>
              <span className="text-muted-foreground">{anchor.label}</span>
            </div>
            <div className="relative mt-2 h-3 rounded-full bg-muted" aria-hidden="true">
              <div className="h-full rounded-full bg-[#e9d5ff]" style={{ width: `${(anchor.low / 23) * 100}%` }} />
              <div
                className="absolute inset-y-0 rounded-r-full bg-[#a855f7]"
                style={{ left: `${(anchor.low / 23) * 100}%`, width: `${((anchor.high - anchor.low) / 23) * 100}%` }}
              />
            </div>
          </div>
        ))}
      </div>
      <figcaption className="mt-3 text-xs text-muted-foreground">
        Shared 0–23 minute scale; darker segments mark each range. Uses lodestar&apos;s clean nethermind re-read.
      </figcaption>
    </figure>
  )
}

function ErigonDeadlockFigure() {
  return (
    <figure
      className="mt-4 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
      aria-label="Erigon and checkpoint-synced Prysm each waited for the other, leaving the sync deadlocked."
    >
      <div className="grid items-center gap-3 text-center sm:grid-cols-[1fr_auto_1fr]">
        <div className="rounded-lg border border-[#e5726e]/40 bg-[#e5726e]/10 p-3">
          <p className="text-sm font-medium text-foreground">Erigon3 · OtterSync</p>
          <p className="mt-1 text-xs text-muted-foreground">Waits for CL finalization</p>
        </div>
        <span className="text-xl text-[#e5726e]" aria-hidden="true">
          <span className="sm:hidden">↕</span>
          <span className="hidden sm:inline">↔</span>
        </span>
        <div className="rounded-lg border border-[#e5726e]/40 bg-[#e5726e]/10 p-3">
          <p className="text-sm font-medium text-foreground">Checkpoint-synced Prysm</p>
          <p className="mt-1 text-xs text-muted-foreground">Waits for EL execution</p>
        </div>
      </div>
      <figcaption className="mt-3 text-xs text-muted-foreground">
        Neither side issued the forkchoiceUpdated call needed to break the wait.
      </figcaption>
    </figure>
  )
}

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
            Restart behavior mattered more than sync speed or disk size. We tested every execution
            and consensus client this project supports, one mainnet sync at a time, recording both
            numbers. The fastest client has almost no real-world adoption.
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
            <span className="font-medium">Companion post:</span> for agent orchestration, the test
            harness, and methodology, see{' '}
            <Link href="/blog/how-we-tested-with-claude" className="text-primary underline underline-offset-2">
              How We Ran a Six-Week Ethereum Client Bake-Off With Claude
            </Link>
            .
          </p>
        </Card>

        <section className="mt-8" aria-label="Campaign at a glance: when, where, scope, and method">
          <h2 className="text-sm font-medium uppercase tracking-wide text-muted-foreground">
            At a glance: when &amp; how
          </h2>
          <div className="mt-3 grid gap-3 sm:gap-4 md:grid-cols-2">
            {campaignFacts.map((fact) => (
              <Card key={fact.title} padding="sm" className="bg-muted/30">
                <h3 className="font-medium text-foreground">{fact.title}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{fact.body}</p>
              </Card>
            ))}
          </div>
        </section>

        <ArticleToc links={tocLinks} />

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="tldr" className="text-lg sm:text-xl font-semibold text-foreground">
            TL;DR
          </AnchorHeading>
          <div className="mt-4 grid gap-3 sm:gap-4 md:grid-cols-2">
            <Card padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">Disk: the field converges, ~1.0–1.2 TiB</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                Execution-layer (EL) clients with full post-merge history use similar disk space:
                geth 1.13 TiB, nethermind ~1.06 TiB, besu 1.08 TiB. Retention settings, not client efficiency,
                determine disk size, so it is a poor way to pick a winner.
              </p>
            </Card>
            <Card padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">Speed winner — ethrex, ~2h16m</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                Ethrex finished first; geth followed at ~8h28m.
              </p>
            </Card>
            <Card padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">The twist — ethrex&apos;s restart-resync cliff</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                Ethrex resumed through 23 minutes / 124 blocks but stalled at 26 minutes / 132 blocks.
                Measured 1.5–2-hour gaps forced a fresh snap sync (downloading state again, ~2h).
                This restart cost is a strong candidate explanation for its near-zero mainnet adoption.
              </p>
            </Card>
            <Card padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">The CL layer looks solved — on the axes we measured</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                All five consensus-layer (CL) clients checkpoint-synced to a validating head in minutes on all three
                EL anchors: geth ~6–9 min, nethermind ~7–10 min, ethrex ~22–23 min.
                Four runs needed fixes or re-reads, detailed below; none exposed a client fault.
                Disk footprint separates them.
              </p>
            </Card>
          </div>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6" aria-labelledby="sync-time-heading">
          <AnchorHeading id="sync-time-heading" className="text-lg sm:text-xl font-semibold text-foreground">
            Cold-sync time, at a glance
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Ethrex synced fastest. Only completed execution-client syncs are comparable;
            reth and nimbus_eth1 hit the 72-hour cap, and erigon deadlocked.
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

        <section className="mt-10 sm:mt-16 border-t border-border pt-6" aria-labelledby="disk-heading">
          <AnchorHeading id="disk-heading" className="text-lg sm:text-xl font-semibold text-foreground">
            Disk footprint, at a glance
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Full-history clients converge at ~1.0–1.2 TiB; retention settings determine size.
            Solid bars show nethermind, besu, and geth. Hatched bars show different outcomes:
          </p>
          <ul className="mt-3 list-disc space-y-2 pl-5 text-sm text-muted-foreground">
            <li>Nimbus-eth1: ~40 GB at only ~21% synced; reth: ~0.98 TiB at the 72h cap,
              projected to finish in the solid bars&apos; band.</li>
            <li>Erigon: frozen partial data from its no-sync deadlock.</li>
            <li>Ethrex: settled at ~470–476 GiB, serving no history. Its smaller size reflects
              retention, not greater efficiency; it cannot be ranked against pruned full-history nodes.</li>
          </ul>
          <p className="mt-3 text-sm text-muted-foreground">
            A short hatched bar is not a disk win.
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
              Bar length is final datadir size, EL + CL. Hatched = not a finished, comparable footprint.
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

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="el-scorecard" className="text-lg sm:text-xl font-semibold text-foreground">
            EL scorecard
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Four execution clients synced. Every run used a fixed Prysm consensus client and a 72-hour cap.
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
          <p className="mt-3 text-xs text-muted-foreground">
            Mainnet execution-client share, sampled once during the campaign; not re-checked.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="cl-scorecard" className="text-lg sm:text-xl font-semibold text-foreground">
            CL scorecard
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            All five consensus clients synced on all three fixed EL anchors: ethrex, then geth,
            then nethermind. Repeating the sweep tested whether CL results depend on the paired EL.
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
            Footprint tracks time following the chain, rather than the paired EL.
            We sampled the geth and nethermind runs minutes after checkpoint-sync, on fresher data directories (datadirs).
          </p>
          <p className="mt-4 text-sm text-muted-foreground">
            Three footprint tiers held across anchors: lightweight (lodestar, lighthouse),
            middle (grandine, teku), and heavy (nimbus). Sampling time affects order within tiers;
            the consensus-layer section explains two instabilities.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="additional-run-details" className="text-lg sm:text-xl font-semibold text-foreground">
            Additional run details
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            These collapsed details add peer counts, configuration checks, re-runs, and per-candidate notes to the scorecards.
          </p>
          <Details
            summary={`Show all ${fullMetrics.length} per-candidate rows — peers, config-optimality, re-runs, notes`}
            className="mt-4"
          >
          <div
            className="hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
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
          <div className="space-y-3 sm:hidden">
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
          <p className="mt-4 text-xs text-muted-foreground">
            Sourced from <a href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`} target="_blank" rel="noopener noreferrer" className="text-primary underline underline-offset-2">CLIENT_BAKEOFF_RESULTS.md</a>, the campaign&apos;s source-of-truth data — see the full{' '}
            <Link href="/blog/bakeoff-results" className="text-primary underline underline-offset-2">results on-site</Link>{' '}
            or the raw doc on GitHub.
          </p>
          </Details>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="what-we-measured" className="text-lg sm:text-xl font-semibold text-foreground">
            What we measured, and how we kept it honest
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Comparable results need controlled pairing and verified settings. Each client ran alone;
            the campaign card defines the 72-hour cap and end-of-run disk measurement.
            We held the consensus client constant and checked the running configuration.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Prysm stayed constant for the EL scorecard. The Engine API connects EL and CL;
            EL footprint and sync time are independent of the CL. The CL matrix confirmed this.
            Prysm used ~0.65–1.68 GB in bounded runs, reaching ~12.5 GB during reth&apos;s full 72h cap.
            That remains negligible beside an EL&apos;s hundreds of gigabytes.
          </p>
          <Card padding="sm" className="mt-4 bg-muted/30">
            <AnchorHeading id="honesty-mechanism" as="h3" className="font-medium text-foreground">
              The honesty mechanism
            </AnchorHeading>
            <p className="mt-1 text-sm text-muted-foreground">
              Early in the campaign we corrupted our own results by recording footprints before checking disk settings.
              A benchmark of our misconfiguration is worse than no benchmark.
              The harness now checks generated, running settings and stamps every row{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=yes|no</code>.
              It rejects misconfigured footprints. We needed six gate fixes across three review rounds before trusting it.
            </p>
            <p className="mt-3 text-sm text-muted-foreground">
              Every comparable footprint on this page comes from a synced run with verified disk settings.
              The harness{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal</code>{' '}
              gate verifies most; besu needed a manual sync-flag audit.
              Its harness token targets a prune lever the ranked run deliberately omitted.
              Capped, no-sync, and pruned-only runs are labelled and excluded.
            </p>
          </Card>
          <p className="mt-3 text-sm text-muted-foreground">
            Live checks also settled configuration disputes, including nimbus_eth1&apos;s history-pruning flag below.
            The binary&apos;s{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--help</code> and
            the online docs contradicted each other. See{' '}
            <Link href="/blog/how-we-tested-with-claude" className="text-primary underline underline-offset-2">
              how we tested this with Claude
            </Link>{' '}
            for the full harness engineering process.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="the-disk-story" className="text-lg sm:text-xl font-semibold text-foreground">
            The disk story
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Matched history settings put nethermind and geth on par. Nethermind&apos;s synced-tip snapshot was{' '}
            <strong className="text-foreground">~251 GiB</strong>, below geth&apos;s ~1.13 TiB.
            FastBlocks had yet to backfill older post-merge block bodies and receipts.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Re-measured 2026-08-01, its steady-state datadir is{' '}
            <strong className="text-foreground">~1.06 TiB</strong> (~1,088 GiB):
            ~226–230 GiB of state in compact Halite/Paprika flat storage,
            ~843 GiB of post-merge bodies and receipts, and ~19 GiB of headers and code.
            Geth keeps the same history under{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--history.chain postmerge</code>.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Since 2026-08-03, the shipped default drops that history:
          </p>
          <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">Default is minimal-history</span>{' '}
              (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">NETHERMIND_FULL_HISTORY=false</code>) —
              a fresh sync drops the post-merge bodies and receipts and holds at{' '}
              <strong className="text-foreground">~250–280 GiB</strong> (state only), with no backfill.
            </li>
            <li>
              <span className="font-medium text-foreground">The cost is served history:</span>{' '}
              pre-sync blocks return{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">null</code>, like ethrex.
              It is the same retention lever turned down — not a client that is &ldquo;smaller.&rdquo;
            </li>
            <li>
              <span className="font-medium text-foreground">To serve a public RPC,</span> set{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">NETHERMIND_FULL_HISTORY=true</code>{' '}
              on a fresh or rebuilt datadir; converting an existing minimal datadir needs a rebuild.
            </li>
          </ul>
          <p className="mt-3 text-sm text-muted-foreground">
            The ~1.06 TiB figure and the chart below are that full-history opt-in.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Nethermind is the smallest measured no-history staking node:
            <strong className="text-foreground">~250–280 GiB against ethrex&apos;s ~470 GiB</strong>.
            Geth has no clean setting to drop post-merge history and cannot reach that floor.
            This is the one place its compact state engine is a genuine disk win, at the cost of serving no history.
            Calling it 4× leaner than geth would compare different retention settings.
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
            Besu uses ~1.08 TiB. Reth already used ~87% of geth&apos;s size at its 72h cap
            (47% by block / ~21% gas-weighted), projecting to ~1.1–1.2 TiB finished.
            Those two join geth (1.13) and nethermind (~1.06) in the band retaining full post-merge history.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <strong className="text-foreground">Snap-sync speed</strong> and{' '}
            <strong className="text-foreground">restart-resume stability</strong> separate the clients, as detailed below.
            Nethermind remains a good choice for its compact flat-storage state and minority-client diversity,
            just not because it is smaller on disk than geth.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            The remaining footprints are not comparable finished results:
          </p>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">ethrex</span> — synced, ~2h16m,
              fastest in the field. Its datadir <strong className="text-foreground">plateaus at
              ~470–476 GiB</strong>. Post-sync growth toward ~465 GiB (+43 GiB/hr) slowed ~300× to +0.13 GiB/hr.
              It drifted 470.2 → 475.5 GiB over ~42 hours (confirmed 2026-07-28→31).
              The earlier ~467 GiB sample caught the climb, not unbounded growth.
              It lands smaller only because it serves no history at all. On a state-only basis it is not even the smallest:
              nethermind&apos;s ~226–230 GiB state is roughly half ethrex&apos;s total.
              This comparison is imperfect: ethrex&apos;s total includes headers and recent blocks, and state encodings differ.
            </li>
            <li>
              <span className="font-medium text-foreground">reth</span> — 72h cap at ~21%
              gas-weighted (47% by block count), ~0.98 TiB partial. Full-sync-only (no snap) —
              can&apos;t reach tip in a practical window,
              though its trajectory already projects into the converged band above.
            </li>
            <li>
              <span className="font-medium text-foreground">nimbus_eth1</span> — 72h cap at
              ~21.6%, ~40 GB partial. Full-sync-only (no snap). Online pruning is logged (below), but it
              can&apos;t finish in 72h.
            </li>
            <li>
              <span className="font-medium text-foreground">erigon</span> — deadlocked, no result.
              Optimistic-sync deadlock against a checkpoint-synced CL (below).
            </li>
          </ul>
          <p className="mt-3 text-sm text-muted-foreground">
            Ethrex is not a drop-in replacement for a public DeFi-facing RPC, including this repo&apos;s nginx/Caddy endpoint feature.
            A live probe (2026-07-29) placed its history cutoff exactly at the snap-sync pivot,
            the block chosen to start syncing:{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_getBlockByNumber</code>{' '}
            returns <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">null</code>{' '}
            one block before it and resolves at and after it. Ethrex never backfills older history.
          </p>
          <ul className="mt-3 list-disc space-y-2 pl-5 text-sm text-muted-foreground">
            <li>Current balances, quotes, and allowances work.</li>
            <li>Blocks, logs, and receipts before the pivot fail: effectively all Ethereum history.
              Indexer/subgraph backfill, portfolio history, and tax/accounting exports cannot work.</li>
            <li>Geth with <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--history.chain postmerge</code>{' '}
              serves that history.</li>
          </ul>
          <figure
            className="mt-5 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
            aria-label="Ethrex's servable RPC window: it returns null for all of Ethereum history from genesis through the snap-sync pivot, and serves only from the pivot forward to head"
          >
            <div className="flex items-stretch overflow-hidden rounded-lg border border-border">
              <div
                className="flex min-h-[2.75rem] flex-1 items-center justify-center border-r-2 border-dashed border-[#e5726e]/40 px-3 py-3 text-center text-[11px] font-medium leading-snug text-[#e5726e] sm:text-xs"
                style={{
                  backgroundImage:
                    'repeating-linear-gradient(45deg, rgba(229,114,110,0.10), rgba(229,114,110,0.10) 6px, transparent 6px, transparent 12px)',
                }}
              >
                <span className="hidden sm:inline">
                  returns <code className="mx-1 font-mono text-inherit">null</code> — all of
                  Ethereum history (genesis → pivot)
                </span>
              </div>
              <div className="relative flex w-16 flex-shrink-0 items-center justify-center bg-[#a855f7]/[0.14] px-2 py-3 text-center text-[11px] font-medium text-[#a855f7] sm:w-24 sm:text-xs">
                <span className="hidden sm:inline">served</span>
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

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="the-speed-story" className="text-lg sm:text-xl font-semibold text-foreground">
            The speed story
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            ethrex snap-synced to a fully-validating head in{' '}
            <strong className="text-foreground">~2h16m</strong>, the fastest in the field by
            nearly 4×. It kept fifty peers throughout, automatically healed one stale pivot in ~4 min,
            and never crashed.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">Two things keep it off the recommended list:</p>
          <ol className="mt-3 list-inside list-decimal space-y-2 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">Disk size reflects missing history.</span>{' '}
              Ethrex prunes nothing. Even at tip with{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_syncing=false</code>,
              its datadir grew 286 → 403 → 416 → ~467 GiB on 2026-07-06 before settling at ~470–476 GiB.
              It serves almost no history: the pivot cutoff above prevents comparison with full-history clients.
              It is neither compact nor a full-history archive.
            </li>
            <li>
              <span className="font-medium text-foreground">The restart cliff</span> — the next
              section.
            </li>
          </ol>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="restart-resilience" className="text-lg sm:text-xl font-semibold text-foreground">
            Restart resilience
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Geth and nethermind resumed cleanly; ethrex stalled or restarted; besu deadlocked mid-sync.
            Upgrades, config changes, crashes, and host maintenance make restart behavior an everyday concern.
            Cold-sync numbers describe only day one.
          </p>
          <figure
            className="mt-5 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
            aria-label="Three fates for an interrupted node: it catches back up (geth, nethermind), freezes past a roughly 25-minute gap and starts over on longer gaps (ethrex), or wedges alive but frozen if the interruption happens mid-sync (besu)"
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
                    <strong className="text-[#f5b46b]">Starts over</strong> — ethrex, head freezes past a ~25-min gap
                  </p>
                  <p className="mt-1 text-muted-foreground">
                    longer (~1.5–2h) gaps discard state, re-snap from scratch — ~2 h
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
              never synced far enough to see one. Consensus layer: prysm resumed from its own DB
              with no re-checkpoint in all four restart tests; the one deliberately timed stop
              (30 min) was back at sync_distance=0 in ~2m44s.
            </figcaption>
          </figure>
          <ol className="mt-4 list-inside list-decimal space-y-3 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">Graceful resume.</span> The client
              imports missed blocks and keeps its on-disk state, catching up in minutes without re-downloading.
              Geth bridged a ~52-hour gap by sequential block import (applying trie differences),
              kept its full datadir, and reached the validating tip without re-snapping.
              Nethermind also resumed gracefully; its bisection follows below.
              Reth never reached a synced datadir, so we could not measure resume.
            </li>
            <li>
              <span className="font-medium text-foreground">Re-snap cliff.</span> Past a downtime
              threshold, ethrex stalls with a disconnected head. Longer measured gaps caused it to
              discard synced state and start again. Only ethrex showed this behavior; the bisection pins its onset.
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
            Both failures involve a limited serving window. Full nodes serve only recent world-state
            (roughly ~128 blocks). When a head or pivot falls behind it, peers cannot supply the state needed to heal.
            The client must choose a new pivot. Graceful-resume clients import gap blocks, which remain available.
          </p>
          <figure className="mt-5 hidden sm:block" aria-labelledby="resume-chart-title" aria-describedby="resume-chart-description">
            <svg className="h-auto w-full" viewBox="0 0 680 250" role="img">
              <title id="resume-chart-title">Largest restart gap each client bridged, in blocks (log scale)</title>
              <desc id="resume-chart-description">
                Ethrex resumed gaps of 68, 108, and 124 blocks but stalled with a frozen head at 132 blocks — its cliff sits at roughly 128 blocks, about 25 minutes; longer gaps escalated to a full re-snap. Nethermind resumed every tested gap from 69 to 10,607 blocks (12 minutes to about 35 hours) with no cliff anywhere, and geth resumed a roughly 15,400-block, 52-hour gap.
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
              <text x="232" y="74" className="fill-muted-foreground text-[12px]">132 blk — stalled, head frozen (state discard only at ~1.5–2h gaps)</text>
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
              <dd className="text-right text-xs text-muted-foreground">resumed ≤124 blk; stalled at 132 blk (~25 min); ~1.5–2h gaps → full re-snap</dd>
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
            Nethermind resumed every tested gap without re-snapping (2026-08-01→03).
            In an opportunistic catch-up, a CL restart at 13:24:55Z left it{' '}
            <strong className="text-foreground">10,607 blocks (~35h of chain) behind</strong> the
            external tip, and it closed the entire gap by ordinary block import in{' '}
            <strong className="text-foreground">35m09s (~302 blocks/min)</strong> with the datadir
            intact (1.165 → 1.178 TB, +1.1%: exactly the imported bodies/receipts).
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Controlled stop→wait→start tests at{' '}
            <strong className="text-foreground">12 min / 30 min / 1 h / 4 h gaps</strong> (2026-08-02→03):
            every gap resumed geth-style — ordinary Engine-API block import, no re-pivot, no
            snap/state-sync, zero crashes. The tell is the state-dir delta:{' '}
            <strong className="text-foreground">~1.0–1.3 MiB per imported block, constant across
            rungs</strong> — linear import, the opposite of a re-snap, which would rewrite the whole
            ~238 GiB state. Resume time scales gently (121s at 12 min → 483s at 4 h → 35m09s at
            ~35 h), dominated by the CL re-syncing its missed slots rather than by EL import.{' '}
            <strong className="text-foreground">nethermind has no servable-window cliff</strong> — the
            direct contrast to ethrex&apos;s ~128-block cliff below.
          </p>
          <Details summary="Separate fresh-sync measurement: 2026-07-31" className="mt-4">
            <p className="text-sm text-muted-foreground">
              A separate establish run (2026-07-31) snap-synced nethermind fresh in{' '}
              <strong className="text-foreground">1h52m51s</strong> (~280 GiB at snap, pivot
              25,649,064, zero restarts). This was far faster than the ~14.5h Stage-B figure because
              the pivot was minutes-old and near-tip, and network conditions differed. It is a second data point,
              not a replacement for the Stage-B number.
            </p>
          </Details>

          <AnchorHeading id="ethrex-cliff-bisected" as="h3" className="mt-6 font-medium text-foreground">
            ethrex&apos;s cliff, bisected
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            A ~1.5–2h restart gap forced fully-synced ethrex to start again.
            At mainnet head with 286 GiB, it abandoned state for a fresh snap sync from the current head.
            The datadir collapsed 286 GiB → ~9 GiB, then climbed. The journal showed{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">SNAP SYNC STARTED</code>{' '}
            from near-genesis,{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_blockNumber</code>{' '}
            at <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">0x0</code>{' '}
            throughout. Re-running the entire ~2h cold-sync pipeline took{' '}
            <strong className="text-foreground">2h11m</strong>.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Controlled stop → wait → start cycles narrowed the threshold, with live Prysm driving forkchoice (selecting the chain head):
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
            Bisection identified header-fetch failure beyond the ~128-block serving window as the trigger, rather than
            &ldquo;state expiry&rdquo; itself. Just past the edge, ethrex first stalls with a disconnected head:
            peers will not serve the gap headers. The stuck head is the onset;
            larger gaps (~1.5–2h) end in a full datadir-collapse re-snap.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <strong className="text-foreground">Why it matters:</strong> a ~25-minute restart cliff
            and ~2h re-snaps after longer gaps make operation costly. This is a strong candidate explanation for ethrex&apos;s ~0% adoption
            despite its fastest cold sync.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <strong className="text-foreground">Fairness caveats:</strong>{' '}
            we observed this on ethrex v19.0.0, a young client that may improve.
            Restart resilience is separate from the recorded cold-sync result; the cliff does not change that time.
          </p>

          <AnchorHeading id="besu-mid-sync-deadlock" as="h3" className="mt-6 font-medium text-foreground">
            besu&apos;s mid-sync deadlock
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            besu&apos;s pruned re-run deadlocked twice and was abandoned. The chain:
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
              cancelled its snap-sync download (SnapSyncChainDownloader.consumePivotUpdate), and the downloader thread died without restarting.
              The process stayed alive and still answered{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_blockNumber</code>{' '}
              — but the sync engine was dead and the datadir frozen.
            </li>
            <li>Restarting resumed on the same stale pivot and re-deadlocked identically.</li>
          </ol>
          <p className="mt-3 text-sm text-muted-foreground">Three takeaways:</p>
          <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">An in-progress besu snap sync is
              fragile to a prolonged CL outage</span> — a stale CL binary can poison the EL&apos;s
              pivot irrecoverably.
            </li>
            <li>
              <span className="font-medium text-foreground">besu answering RPC ≠ besu syncing</span>{' '}
              — judge by disk growth and DB writes, not RPC liveness.
            </li>
            <li>
              <span className="font-medium text-foreground">Same root cause as ethrex&apos;s
              cliff</span> — the ~128-block servable-state window, one client hitting it mid-sync,
              the other post-sync on restart.
            </li>
          </ul>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="full-sync-only-clients" className="text-lg sm:text-xl font-semibold text-foreground">
            Full-sync-only clients
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Reth and nimbus_eth1 full-sync from genesis; neither offers snap sync.
            Both hit 72h far from tip: reth ~21% gas-weighted (47% by block), ~0.98 TiB;
            nimbus_eth1 ~21.6% by block, ~40 GB.
            Their design misses our snap-to-tip bar, not a correctness test.
            Ranking them against snap sync on time or disk would be unfair; reth runs successfully and widely elsewhere.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Nimbus_eth1&apos;s pruning flag was disputed. Its config sets{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">prune = true</code>.
            The binary&apos;s{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--help</code>{' '}
            says it prunes expired bodies and receipts. Online docs require a separate era1 export
            for pre-merge history, implying the flag is inert; we had marked it &ldquo;unverified.&rdquo;
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Throughout the 72-hour import, the journal logged continuous online pruning:{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">Pruning history … pruned=N</code>.
            The flag is not inert. Full pre-merge completeness versus era1 import remains untestable here:
            the node never reached tip. It ran 72 hours with zero restarts: stable, but slow by design.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Erigon was the EL sweep&apos;s only no-sync result. Erigon3&apos;s OtterSync and checkpoint-synced
            Prysm deadlocked in a mutual wait. Raising CL CPU from 200%→600% advanced ~5k blocks
            before it re-froze, leaving ~1.21 TiB of frozen partial data, not a synced datadir.
          </p>
          <ErigonDeadlockFigure />
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="distribution-as-predictor" className="text-lg sm:text-xl font-semibold text-foreground">
            Distribution as predictor
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Snap-sync availability and resilience predict syncability better than mainnet share.
            The data only partly supports our initial &ldquo;mainnet share predicts syncability&rdquo; hypothesis.
            Erigon deadlocked; reth and nimbus_eth1 were slow by design.
            But minimalist ethrex, at ~0% share, synced fastest. Its snap sync and clock-based
            stale-pivot self-healing excelled at cold sync. Its adoption gap is far better explained
            by the restart cliff than by any sync deficiency.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="consensus-layer-solved" className="text-lg sm:text-xl font-semibold text-foreground">
            Consensus layer
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            All five CLs reached a fully-validating head in minutes on every anchor.
            We swept lighthouse, lodestar, grandine, teku, and nimbus against one fixed EL,
            then repeated on two more to test EL/CL independence:
          </p>
          <ConsensusSyncFigure />
          <p className="mt-3 text-sm text-muted-foreground">
            Ethrex was slowest, still well under an hour. Footprints are in the CL scorecard above;
            lodestar&apos;s slow first nethermind attempt was an anchor artifact, detailed below.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Every run logged{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=yes</code>{' '}
            with zero crashes. Four runs needed caveats, detailed below; none exposed a client fault.
            Sync times are effectively tied within each anchor, leaving footprint as the differentiator.
          </p>
          <div className="mt-4 space-y-2">
            {consensusCaveats.map((row, i) => (
              <div key={i} className="flex items-start gap-3 rounded-lg border border-border p-3 text-sm">
                <span className="mt-0.5 shrink-0 whitespace-nowrap rounded-md border px-2 py-0.5 font-mono text-xs" style={{ color: '#a855f7', backgroundColor: 'rgba(168,85,247,0.1)', borderColor: 'rgba(168,85,247,0.4)' }}>
                  not a client fault
                </span>
                <p className="text-muted-foreground">
                  <span className="font-medium text-foreground">{row.cl}</span>{' '}
                  <span className="text-xs text-muted-foreground">({row.anchor})</span> — {row.what}
                </p>
              </div>
            ))}
          </div>
          <p className="mt-3 text-sm text-muted-foreground">
            Three tiers held, with two order instabilities. Lodestar↔lighthouse swapped within the lightweight pair
            between ethrex and geth. Teku&apos;s re-read (~667 vs ~835 MiB) crossed grandine and back on one anchor.
            Grandine &lt; teku held on all three anchors: the second instability is measurement noise, not a real swap.
            Stable tiers without an identical total order support EL/CL independence and holding CL=prysm constant for the EL scorecard.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            All five CLs worked on the measured axes. Choose by footprint and preference;
            lighthouse is the lean, safe default. Operational risk in an Ethereum node lives in the EL layer, not the CL layer.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Scope matters: we swept the five CLs for checkpoint-sync and footprint, not restart-resume.
            Only the constant Prysm anchor had restart tests. Its clean resume from its own DB
            supports &ldquo;prysm resumes cleanly,&rdquo; not &ldquo;the CL layer survives anything.&rdquo;
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="recommendations" className="text-lg sm:text-xl font-semibold text-foreground">
            Recommendations
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Choose geth by default or nethermind for diversity. Every EL&apos;s campaign issues and verdict follow:
          </p>
          <div
            className="mt-4 hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
            role="region"
            aria-label="Execution client known issues and verdict"
            tabIndex={0}
          >
            <table className="w-full min-w-[42rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">EL</th>
                  <th className="pb-3 font-medium text-muted-foreground">Verdict</th>
                  <th className="pb-3 font-medium text-muted-foreground">Known issue</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {clientIssues.map((row) => (
                  <tr key={row.name}>
                    <td className="py-3 align-top font-medium text-foreground whitespace-nowrap">{row.name}</td>
                    <td className="py-3 align-top"><VerdictBadge verdict={row.verdict} /></td>
                    <td className="py-3 align-top text-muted-foreground min-w-[24rem]">{row.issue}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {clientIssues.map((row) => (
              <div key={row.name} className="rounded-lg border border-border p-3">
                <div className="flex items-center justify-between gap-3">
                  <span className="font-medium text-foreground">{row.name}</span>
                  <VerdictBadge verdict={row.verdict} />
                </div>
                <p className="mt-2 text-sm text-muted-foreground">{row.issue}</p>
              </div>
            ))}
          </div>
          <p className="mt-4 text-sm text-muted-foreground">The detail behind each verdict:</p>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">Default: geth.</span> Largest
              ecosystem, most documentation, cleanest snap sync (~8.5h), and graceful restarts.
              Its ~1.13 TiB footprint matches other ELs retaining full post-merge history, so it is not a downside unique to geth.
              Run it unless you have a specific reason to choose another client.
            </li>
            <li>
              <span className="font-medium text-foreground">Diversity pick: nethermind.</span>{' '}
              Compact flat-storage state and minority-client diversity, with measured restart resilience:
              every 12 min–~35h gap resumed by block import (2026-08-01→03), with no re-snap or cliff.
              Full-history disk is comparable to geth (~1.06 vs ~1.13 TiB);
              the ~251 GiB snap-tip snapshot omitted backfill. Sync takes longer (~14.5h vs ~8.5h).
            </li>
            <li>
              <span className="font-medium text-foreground">Consensus client: lighthouse</span> as
              the lean default; any of the five is operationally fine — pick on footprint and
              familiarity.
            </li>
            <li>
              <span className="font-medium text-foreground">Watch, don&apos;t yet deploy: ethrex.</span>{' '}
              Fastest cold sync, but its ~25-minute restart cliff makes it operationally costly today.
              Its settled ~470–476 GiB plateau serves no history; using it in place of a full-history nginx/Caddy RPC
              will silently fail on anything historical. Revisit this fast-moving client:
              v19.0.0 at first sync, v22.0.0 at the steady-state measurement.
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
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="bottom-line" className="text-lg sm:text-xl font-semibold text-foreground">
            Bottom line
          </AnchorHeading>
          <p className="mt-3 text-sm text-muted-foreground">
            Run <strong className="text-foreground">geth</strong> by default or{' '}
            <strong className="text-foreground">nethermind</strong> for diversity.
            Both synced and resumed cleanly, with similar full-history disk footprints.
            <strong className="text-foreground">Ethrex</strong>&apos;s ~25-minute restart cliff and{' '}
            <strong className="text-foreground">besu</strong>&apos;s vulnerability to a stalled consensus client need caution.
            Restart behavior reveals risks a cold-sync chart misses. It is the strongest candidate explanation
            for why almost nobody runs the fastest client.
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
      <BackToTop />
    </div>
  )
}
