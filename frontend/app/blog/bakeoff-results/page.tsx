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

export const metadata: Metadata = buildArticleMetadata('bakeoff-results')

/**
 * Small dependency-free inline parser for the markdown-lite emphasis used
 * throughout the source doc: `backtick code spans`, **bold**, and *italic* —
 * composable, so `code` and *italic* can appear nested inside **bold**. Not a
 * markdown pipeline — no block-level parsing (tables/lists/headings are
 * hand-authored JSX below). Because content flows through {} expressions
 * rather than literal JSX text, apostrophes/quotes/angle-brackets in the
 * strings need no escaping.
 *
 * Two passes, deliberately in this order: **bold** spans are extracted first,
 * scanning the whole string for `**...**` pairs before anything else is
 * considered. Only *then* is each remaining plain segment (and, recursively,
 * each bold span's inner content) scanned for `code` spans and *italic*. This
 * ordering matters: a stray, unpaired single asterisk in the source (e.g. a
 * footnote marker like "TiB*") must never be mistaken for the opening of an
 * italic span that swallows a later, unrelated **bold** pair — which is what
 * a naive single left-to-right character scan (bold-or-italic-per-position)
 * would do.
 */
function parseInline(text: string, keyPrefix: string): React.ReactNode[] {
  const segments: Array<{ bold: boolean; content: string }> = []
  let i = 0
  let start = 0
  while (i < text.length) {
    if (text[i] === '*' && text[i + 1] === '*') {
      const end = text.indexOf('**', i + 2)
      if (end !== -1) {
        if (i > start) segments.push({ bold: false, content: text.slice(start, i) })
        segments.push({ bold: true, content: text.slice(i + 2, end) })
        i = end + 2
        start = i
        continue
      }
    }
    i++
  }
  if (start < text.length) segments.push({ bold: false, content: text.slice(start) })

  const nodes: React.ReactNode[] = []
  let key = 0

  for (const segment of segments) {
    const nodeKey = `${keyPrefix}-${segment.bold ? 'b' : 'p'}${key++}`
    if (segment.bold) {
      nodes.push(
        <strong key={nodeKey} className="text-foreground">
          {parseInline(segment.content, nodeKey)}
        </strong>
      )
    } else {
      nodes.push(...parsePlain(segment.content, nodeKey))
    }
  }

  return nodes
}

/** Handles `code` spans and *italic* within text known to contain no **bold** markers. */
function parsePlain(text: string, keyPrefix: string): React.ReactNode[] {
  const nodes: React.ReactNode[] = []
  let buffer = ''
  let key = 0
  let i = 0

  const flushBuffer = () => {
    if (buffer) {
      nodes.push(<span key={`${keyPrefix}-t${key++}`}>{buffer}</span>)
      buffer = ''
    }
  }

  while (i < text.length) {
    if (text[i] === '`') {
      const end = text.indexOf('`', i + 1)
      if (end !== -1) {
        flushBuffer()
        nodes.push(
          <code key={`${keyPrefix}-c${key++}`} className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">
            {text.slice(i + 1, end)}
          </code>
        )
        i = end + 1
        continue
      }
    }

    if (text[i] === '*') {
      const end = text.indexOf('*', i + 1)
      if (end !== -1) {
        flushBuffer()
        const nodeKey = `${keyPrefix}-i${key++}`
        nodes.push(
          <em key={nodeKey} className="italic">
            {parsePlain(text.slice(i + 1, end), nodeKey)}
          </em>
        )
        i = end + 1
        continue
      }
    }

    buffer += text[i]
    i++
  }

  flushBuffer()
  return nodes
}

function Rich({ text }: { text: string }) {
  return <>{parseInline(text, 'rich')}</>
}

const tocLinks = [
  { label: '1. Method', href: '#method' },
  { label: '2. Stage A results — 12/12 PASS', href: '#stage-a' },
  { label: '3. Client limitations', href: '#client-limitations' },
  { label: '4. Sync-mode & disk-flag audit', href: '#disk-flag-audit' },
  { label: '5. Stage B footprint + CL matrix', href: '#stage-b' },
  { label: '6. Q&A: does ethrex serve a usable RPC?', href: '#qa-ethrex-rpc' },
  { label: '7. Recommendation & operational viability', href: '#operational-viability' },
  { label: '8. Gotchas & lessons learned', href: '#gotchas' },
  { label: '9. Bottom line', href: '#bottom-line' },
]

// ---------------------------------------------------------------------------
// At-a-glance summary cards — the what / when / how / time of the whole
// campaign, rendered directly under the header. No new data: every figure
// here is stated again, with provenance, in the tables below.
// ---------------------------------------------------------------------------
const atAGlance = [
  {
    title: '12 / 12 passed triage',
    body: 'Stage A, June 2026: all 7 execution clients against Prysm and 5 consensus clients against a fixed anchor passed. Each installed, loaded a recent beacon checkpoint, and authenticated the Engine API, the execution/consensus connection.',
  },
  {
    title: 'Disk converges at ~1.0–1.2 TiB',
    body: "At steady state, with full post-merge history: geth 1.13 TiB, nethermind ~1.06, besu 1.08. reth’s ~1.1–1.2 is projected from its partial 72h-capped run. Footprint is a config knob, not a winner axis.",
  },
  {
    title: 'Pick on speed + restart-resume',
    body: "geth and nethermind clear the operational bar; besu is a qualified enterprise third. ethrex syncs fastest but has a restart cliff.",
  },
  {
    title: 'Six weeks, every figure phased',
    body: 'Six weeks: June triage → Stage B disk + consensus sweeps → steady-state and restart-resume follow-ups through August 2026. Every measurement states its lifecycle phase.',
  },
]

// ---------------------------------------------------------------------------
// Two-stage method summary — the what / when / how / time, at a glance.
// ---------------------------------------------------------------------------
const methodStages = [
  {
    stage: 'Stage A — triage',
    when: 'June 2026',
    window: '~5-min window per candidate (90-min default in the shipped harness)',
    asks: 'Does each candidate install, checkpoint-sync, and authenticate the Engine API?',
    result: '12 / 12 PASS',
  },
  {
    stage: 'Stage B — full sync',
    when: 'Jun–Aug 2026',
    window: 'up to 72 h per candidate, sequential',
    asks: 'Does each candidate reach a synced, capped, or no-sync verdict, and at what disk footprint?',
    result: 'footprints + verdicts below',
  },
]

// ---------------------------------------------------------------------------
// Stage A — 12/12 PASS
// ---------------------------------------------------------------------------
const stageAResults = [
  { candidate: 'geth__prysm', install: '0', crash: 'no', head: '14615771→14615856', elOffline: 'F×5', restErr: '0', n: '5', verdict: 'PASS (baseline)', fix: 'none' },
  { candidate: 'erigon__prysm', install: '0', crash: 'no', head: '14615808→14615808', elOffline: 'F×5', restErr: '0', n: '5', verdict: 'PASS — flagged', fix: 'none' },
  { candidate: 'reth__prysm', install: '0', crash: 'no', head: '14615808→14616097', elOffline: 'F×5 / T×4', restErr: '6', n: '9', verdict: 'PASS (after fix)', fix: 'JWT + HTTP-RPC' },
  { candidate: 'nethermind__prysm', install: '0', crash: 'no', head: '14614859→14615786', elOffline: 'F×9', restErr: '4', n: '9', verdict: 'PASS', fix: 'Engine module' },
  { candidate: 'besu__prysm', install: '0', crash: 'no', head: '14616094→14616183', elOffline: 'F×5', restErr: '0', n: '5', verdict: 'PASS (clean)', fix: 'none' },
  { candidate: 'nimbus_eth1__prysm', install: '0', crash: 'no', head: '14616151→14616235', elOffline: 'F×5', restErr: '0', n: '5', verdict: 'PASS (clean)', fix: 'none' },
  { candidate: 'ethrex__prysm', install: '0', crash: 'no', head: '14616192→14616287', elOffline: 'F×5', restErr: '0', n: '5', verdict: 'PASS (clean)', fix: 'none' },
  { candidate: 'geth__lighthouse', install: '0', crash: 'no', head: '14615232→14615349', elOffline: 'F×4', restErr: '1', n: '4', verdict: 'PASS', fix: 'none' },
  { candidate: 'geth__teku', install: '0', crash: 'no', head: '14615296→14615326', elOffline: 'F×4', restErr: '1', n: '4', verdict: 'PASS', fix: 'config keys' },
  { candidate: 'geth__nimbus', install: '0', crash: 'no', head: '14615455→14615506', elOffline: 'F×5', restErr: '0', n: '5', verdict: 'PASS', fix: 'trustedNodeSync' },
  { candidate: 'geth__lodestar', install: '0', crash: 'no', head: '14615638→14615708', elOffline: 'F×10', restErr: '10', n: '10', verdict: 'PASS', fix: 'rcConfig' },
  { candidate: 'geth__grandine', install: '0', crash: 'no', head: '14615040→14615203', elOffline: 'F×7', restErr: '1', n: '7', verdict: 'PASS', fix: 'none' },
]

const perCandidateNotes = [
  "**erigon — PASS; re-check in Stage B.** Head froze at checkpoint slot 14615808 while `sync_distance` grew 71→97 over 5 min. `el_offline=false` throughout confirms Engine API reachability and authentication. Beacon-P2P backfill explains this benign warmup, rather than an EL handshake defect. Verify advancing head over Stage B’s longer window.",
  "**reth alone needed EL installer fixes.** It omitted `--authrpc.jwtsecret` for the shared secret from `ensure_jwt_secret`. Prysm used a non-shared auto-JWT: 401 errors froze head, with early `el_offline=True`. Two commits wired the shared JWT; `el_offline` flipped True→False. HTTP-RPC was also enabled on 127.0.0.1 for monitoring/consumers, matching other ELs.",
  "**besu / nimbus_eth1 / ethrex passed cleanly without fixes.** JWT wiring worked out of the box. ethrex finalized (`finalizedEpoch=456756`). nimbus_eth1 also syncs historical EL blocks from genesis in the background, independently of its immediately working Engine API.",
]

// ---------------------------------------------------------------------------
// Sync-mode & disk-flag audit
// ---------------------------------------------------------------------------
const diskFlagAudit = [
  { el: 'geth', flags: '`--syncmode snap` + `--history.chain postmerge`', status: 'optimal', variant: 'primary' as const, notes: '**Verified ON in the actual 1.13 TiB baseline run** (service-status.txt). Snap-sync + post-merge history prune is the disk floor for geth.' },
  { el: 'besu', flags: '`sync-mode="SNAP"` + `data-storage-format="BONSAI"`', status: 'optimal', variant: 'primary' as const, notes: "Bonsai is Besu's space-efficient flat-DB layout; SNAP avoids full historical execution." },
  { el: 'nethermind', flags: '`SnapSync: true` + `FastBlocks: true`', status: 'optimal', variant: 'primary' as const, notes: 'Snap on; Halite/Paprika flat storage is the modern default.' },
  { el: 'ethrex', flags: '`--syncmode snap`', status: 'optimal', variant: 'primary' as const, notes: 'Snap is the only efficient mode it exposes.' },
  { el: 'erigon', flags: 'OtterSync (default) + `prune.mode: "full"`', status: 'disk-optimal', variant: 'primary' as const, notes: '`prune.mode: full` is the smallest erigon3 footprint. (Separately deadlocks → no-sync; see erigon row.)' },
  { el: 'nimbus_eth1', flags: 'fast-sync (default) + `prune = true`', status: 'online-prune confirmed', variant: 'primary' as const, notes: "`prune = true` **prunes online**: a 72h run logged continuous `Pruning history … pruned=N` during import. This resolves the earlier question about whether the flag works. At-tip completeness against a full era1 export remains untested: this full-sync-only node never reached tip within 72h." },
  { el: 'reth', flags: 'was archive (no flag) → now `--full`', status: 'fixed', variant: 'default' as const, notes: "**Only reth needed correction.** Archive is the default (~2.8 TiB). `--full` prunes to ~1.2 TiB: full block/receipt history, but state changesets and indices retain only ~10k recent blocks. reth__prysm was relaunched." },
]

// ---------------------------------------------------------------------------
// Final synced disk footprint (Stage B)
// ---------------------------------------------------------------------------
const stageBFootprint = [
  { candidate: 'geth__prysm', result: 'synced', variant: 'primary' as const, syncTime: '~8h28m', footprint: '**1.13 TiB** — geth 1,245 GB + prysm 655 MB', notes: "Baseline: clean, no crash. The snap-synced EL gives Prysm an already-validated head, avoiding a large optimistic gap." },
  { candidate: 'erigon__prysm', result: 'no-sync', variant: 'default' as const, syncTime: 'n/a', footprint: '~1.21 TiB* — erigon 1,333 GB + prysm 1,646 MB', notes: "*Partial at a near-tip **frozen** head; never a synced datadir. erigon3 OtterSync deadlocked against checkpoint-synced Prysm. EL head froze thousands of blocks behind tip; beacon stayed `is_optimistic=true`. Neither issued the gap-closing `forkchoiceUpdated`. Raising CL CPU 200%→600% advanced head ~5k blocks, then it froze again. This was a deadlock, not resource starvation. Terminated." },
  { candidate: 'reth__prysm', result: 'capped (72h)', variant: 'default' as const, syncTime: 'n/a', footprint: '~0.98 TiB* — reth 1,065 GB + prysm 12.5 GB', notes: "*Partial at block 11,970,965 of 25,395,872 after 72h: 47% by block count, ~21% gas-weighted. reth `--full` is the only no-snap EL here. Sequential execution is too slow to finish inside the cap. Clean stop, no crash. Size is reconstructed from the last sample before the cap, not a final disk scan. At ~21% gas-executed, size was already ~87% of geth’s 1.13 TiB, projecting ~1.1–1.2 TiB finished." },
  { candidate: 'nethermind__prysm', result: 'synced', variant: 'primary' as const, syncTime: '~14.5h', footprint: '**~1.06 TiB steady-state** (re-measured 2026-08-01: ~1,088 GiB — state ~226–230 GiB compact flat storage + ~843 GiB post-merge bodies/receipts + ~19 GiB headers/code) — **~251 GiB at snap-sync, before FastBlocks backfilled post-merge history** (268 GB at that point) + prysm 1,431 MB', notes: "Snap-synced to head 25,428,620 with 49 peers, no crash. State uses ~226–230 GiB of compact flat storage. Full post-merge history backfills to ~1.06 TiB, comparable to geth. **Update 2026-08-03:** shipped default is **minimal-history** (`NETHERMIND_FULL_HISTORY=false`): fresh sync stays at **~250–280 GiB**, state only, no bodies/receipts. ~1.06 TiB is the full-history opt-in for RPC providers. The first attempt stalled 13.3h with zero peers: P2P bound to 127.0.0.1, frozen execution head, apparently healthy beacon. This exposed triage’s blind spot. Advertising a routable external IP fixed it; the re-run synced cleanly." },
  { candidate: 'besu__prysm', result: 'synced; pruned re-run abandoned', variant: 'primary' as const, syncTime: '~19h18m', footprint: '**~1.08 TiB** — besu 1,190 GB + prysm 1,682 MB', notes: "**besu synced cleanly** to a fully validating head (~50 peers) in ~19h18m: a production-viable node. Its ~1.08 TiB is the same magnitude as geth (1.13 TiB) and nethermind (~1.06 TiB) with full post-merge history: comparable, not an outlier. A further-pruning re-run **deadlocked twice and was abandoned**. A stale CL stall caused it, **not** a besu fault. The operational caveat is snap sync’s fragility during prolonged CL outages, not disk size; see gotchas." },
  { candidate: 'ethrex__prysm', result: 'synced', variant: 'primary' as const, syncTime: '~2h16m–4h10m', footprint: '**~470–476 GiB steady-state plateau** (as of 2026-07-31: drifting 470.2 → 475.5 GiB over ~42 hours at +0.13 GiB/hr) — **~286 GiB at first sync** (307 GB, 2026-07-06); **~300 GiB at a later re-sync** (4h09m56s)', notes: "**Fastest EL sync:** ~2h16m to a fully validating head on v19.0.0. v22.0.0 re-sync took 4h09m56s on a different day/host load; this does not show regression. 50 peers throughout, no crash. One automatic stale-pivot update self-healed in ~4 min. This un-pruned node serves ~no history: live `eth_getBlockByNumber` returned `null` below head. After sync, growth fell ~300× from +43 GiB/hr to +0.13 GiB/hr: 470.2 → 475.5 GiB over ~42 hours, verified clean. The earlier ~467 GiB reading caught this plateau mid-climb; growth is not unbounded. **Smaller only because it retains no history, not because it’s leaner.** nethermind’s state alone is ~226–230 GiB, roughly half ethrex’s total. Encodings differ, and ethrex’s total includes headers/recent blocks, so this comparison is not perfectly controlled. See limitations and gotchas for the unchanged restart cliff and no-history RPC cost." },
]

// ---------------------------------------------------------------------------
// Fresh-sync vs. steady-state disk footprint — several ELs were captured at
// more than one point in their lifecycle. A single number can mislead: a
// fresh (at-sync) figure and a settled steady-state figure can differ by up
// to ~4x, so both are recorded where both exist.
// ---------------------------------------------------------------------------
const freshVsSteadyFootprint = [
  { el: 'nethermind', fresh: '~251 GiB (268 GB)', steady: '**~1.06 TiB** (re-measured 2026-08-01: ~1,088 GiB — state ~226–230 GiB + ~843 GiB post-merge bodies/receipts + ~19 GiB headers/code)', note: 'Grew after sync as FastBlocks backfilled post-merge history.' },
  { el: 'ethrex', fresh: '~286 GiB (307 GB, 2026-07-06, v19.0.0); ~300 GiB (2026-07-28, v22.0.0, at 4h09m56s)', steady: '**~470–476 GiB plateau** (drifts 470.2 → 475.5 GiB over ~42h)', note: '+43 GiB/hr during post-sync settling, then collapsed ~300× to +0.13 GiB/hr, drifting for ~42 hours. No-history node — not pruned-comparable to the rows below. The two runs used different ethrex versions (v19.0.0 → v22.0.0) as well as different days/host load.' },
  { el: 'geth', fresh: 'not separately captured', steady: '**1.13 TiB** (1,245 GB)', note: '`--history.chain postmerge`.' },
  { el: 'besu', fresh: 'not separately captured', steady: '**1.08 TiB** (1,190 GB)', note: '' },
  { el: 'reth', fresh: '—', steady: '~0.98 TiB partial @72h cap (projected ~1.1–1.2 TiB finished)', note: "Full-sync-only; never reaches a moment distinct from its capped steady state." },
]

// ---------------------------------------------------------------------------
// Consensus-client matrix — one table, three EL anchors (ethrex, geth,
// nethermind) as columns. Every anchor reproduces the same tier order, so
// this replaced three separate per-anchor tables that repeated the same 5
// clients.
// ---------------------------------------------------------------------------
const clCrossAnchorMatrix = [
  {
    cl: 'lighthouse',
    ethrex: { time: '~22m', size: '773 MB', tag: 'smallest' },
    geth: { time: '~8m54s', size: '542 MB' },
    nethermind: { time: '~10m07s', size: '492 MB' },
    lever: 'checkpoint-sync-url (blob pruning by default)',
  },
  {
    cl: 'lodestar',
    ethrex: { time: '~22m', size: '868 MB' },
    geth: { time: '~6m27s', size: '185 MB', tag: 'smallest' },
    nethermind: { time: '~7m36s', size: '186 MB', tag: 'smallest' },
    lever: 'pruneHistory=true',
  },
  {
    cl: 'grandine',
    ethrex: { time: '~22m', size: '~992 MB (actual)' },
    geth: { time: '~8m50s', size: '~760 MB (actual)' },
    nethermind: { time: '~9m58s', size: '~765 MB (actual)' },
    lever: '--prune-storage — required, or it stores every state',
  },
  {
    cl: 'teku',
    ethrex: { time: '~22m', size: '2,161 MB' },
    geth: { time: '~8m52s', size: '977 MB' },
    nethermind: { time: '~10m07s', size: '875 MB' },
    lever: 'data-storage-mode=minimal',
  },
  {
    cl: 'nimbus',
    ethrex: { time: '~23m', size: '5,302 MB', tag: 'largest (6.9×)' },
    geth: { time: '~7m58s', size: '1,198 MB', tag: 'largest' },
    nethermind: { time: '~10m13s', size: '1,338 MB', tag: 'largest' },
    lever: 'history=prune',
  },
]

const clRankingsByAnchor = [
  { anchor: 'Ethrex anchor', order: 'lighthouse (773 MB) < lodestar (868 MB) < grandine (~992 MB) < teku (2,161 MB) < nimbus (5,302 MB)' },
  { anchor: 'Geth anchor', order: 'lodestar (185 MB) < lighthouse (542 MB) < grandine (~760 MB) < teku (977 MB) < nimbus (1,198 MB)' },
  { anchor: 'Nethermind anchor', order: 'lodestar (186 MB) < lighthouse (492 MB) < grandine (~765 MB) < teku (875 MB) < nimbus (1,338 MB)' },
]

const clMatrixNotes = [
  "**teku needed an ethrex-anchor re-run.** An undersized JVM heap on the shared host caused 64-min sync; that reading was discarded. `TEKU_CACHE=8192m` fixed it: clean sync in 22 min. Size the heap generously to keep garbage-collection (GC) pressure off co-resident services.",
  "**lodestar’s first nethermind-anchor run (~76m) was a fluke, not a lodestar property.** The EL was importing an unrelated ~2-day gap from a separate crash-loop incident. After recovery: ~7m36s / 186 MB, matching the other four CLs and lodestar’s geth result.",
  "**teku’s two false “not synced” nethermind readings were watchdog bugs.** The watchdog latched onto early warmup and never re-checked the recovered anchor. Both footprints are valid: first ~700 MB, published clean re-read 875 MB.",
  "**grandine’s sparse DB files overstate usage.** Raw size is ~1,074 MB on geth/nethermind and ~1,344 MB on ethrex. Longer post-sync runtime increased sparse pre-allocation; this is not measurement error. Published actual disk usage: ~760–765 MB on geth/nethermind, ~992 MB on ethrex.",
]

const crossAnchorVerdict = [
  '**nimbus is the largest CL on all three anchors** — the one ranking that holds without exception.',
  "**{lodestar, lighthouse} are smallest on every anchor.** lighthouse wins on ethrex; lodestar wins on geth/nethermind. Within-tier order depends on measurement time.",
  "**{teku, grandine} form the middle tier.** teku’s ~700 → 875 MB nethermind readings cross grandine’s ~765 MB. Taking the clean re-read as authoritative, grandine < teku holds on all three anchors. That pair’s order is measurement-sensitive, not a stable client property.",
  "**Observation time affects absolute size.** geth/nethermind sweeps measured minutes after checkpoint-sync; ethrex ran longer. Hence nimbus ~1.2–1.3 GB vs ~5.3 GB. Tiers hold; exact within-tier order does not.",
  "**Three anchors reproduce three tiers:** lightweight {lodestar, lighthouse}, mid {teku, grandine}, heavy {nimbus}. This supports EL/CL decoupling without an identical total order.",
]

// Cross-anchor CL footprints (published values from the matrix above, decimal MB)
// for the dot plot. Log axis: the field spans ~185 MB to ~5.3 GB. Anchor identity
// is double-encoded (shape + tone) since the site palette is single-accent.
const clCrossAnchorPoints = [
  { name: 'Lodestar', ethrex: 868, geth: 185, nethermind: 186 },
  { name: 'Lighthouse', ethrex: 773, geth: 542, nethermind: 492 },
  { name: 'Grandine', ethrex: 992, geth: 760, nethermind: 765 },
  { name: 'Teku', ethrex: 2161, geth: 977, nethermind: 875 },
  { name: 'Nimbus', ethrex: 5302, geth: 1198, nethermind: 1338 },
]
const clLogMin = 150
const clLogMax = 6000
const clX = (mb: number) =>
  150 + ((Math.log10(mb) - Math.log10(clLogMin)) / (Math.log10(clLogMax) - Math.log10(clLogMin))) * 420

// ---------------------------------------------------------------------------
// Chart 1 — fresh-sync vs. steady-state footprint (approximate GiB; the exact
// byte figures live in the Fresh-vs-steady table below). Illustrates the
// corpus's headline rule: a bare footprint can move up to ~4x between the
// moment a client reports synced and the moment it stops growing, so every
// figure states its lifecycle phase.
// ---------------------------------------------------------------------------
const freshVsSteadyBars = [
  { name: 'nethermind', fresh: 251, steady: 1088, freshLabel: '~251 GiB', steadyLabel: '~1,088 GiB', steadyNote: 'full-history' },
  { name: 'ethrex', fresh: 286, steady: 475, freshLabel: '~286 GiB', steadyLabel: '~475 GiB', steadyNote: 'no-history plateau' },
]
const fvsMax = 1200
const fvsX0 = 110
const fvsW = 380
const fvsX = (g: number) => fvsX0 + (g / fvsMax) * fvsW

function FreshVsSteadyChart() {
  return (
    <figure className="mt-5 hidden sm:block" aria-labelledby="fvs-chart-title" aria-describedby="fvs-chart-description">
      <svg className="h-auto w-full" viewBox="0 0 680 210" role="img">
        <title id="fvs-chart-title">Fresh-sync versus steady-state disk footprint for the two ELs measured at both phases</title>
        <desc id="fvs-chart-description">
          nethermind climbs from ~251 GiB at snap-sync to ~1,088 GiB at steady state as FastBlocks backfills post-merge
          history. ethrex settles from ~286 GiB to a ~475 GiB no-history plateau. A footprint can move up to ~4x
          between synced and settled, so every figure states its lifecycle phase.
        </desc>
        {[0, 300, 600, 900, 1200].map((g) => (
          <g key={g}>
            <line x1={fvsX(g)} x2={fvsX(g)} y1="16" y2="168" className="stroke-border" />
            <text x={fvsX(g)} y="186" textAnchor="middle" className="fill-muted-foreground text-[12px]">
              {g.toLocaleString('en-US')}
            </text>
          </g>
        ))}
        <text x={fvsX0} y="204" className="fill-muted-foreground text-[11px]">GiB (approximate)</text>
        {freshVsSteadyBars.map((row, index) => {
          const top = 26 + index * 76
          return (
            <g key={row.name}>
              <text x={fvsX0 - 10} y={top + 22} textAnchor="end" className="fill-foreground text-[13px]">{row.name}</text>
              <rect x={fvsX0} y={top} width={fvsX(row.fresh) - fvsX0} height="18" rx="2" fill="#e9d5ff" stroke="#09090b" strokeWidth="1.5" />
              <text x={fvsX(row.fresh) + 8} y={top + 14} className="fill-muted-foreground text-[12px]">{row.freshLabel} (fresh)</text>
              <rect x={fvsX0} y={top + 26} width={fvsX(row.steady) - fvsX0} height="18" rx="2" fill="#a855f7" stroke="#09090b" strokeWidth="1.5" />
              <text x={fvsX(row.steady) + 8} y={top + 40} className="fill-muted-foreground text-[12px]">{row.steadyLabel} (steady, {row.steadyNote})</text>
            </g>
          )
        })}
      </svg>
      <figcaption className="mt-2 text-xs text-muted-foreground">
        The lifecycle-phase rule: a bare footprint can move up to ~4x between the moment a client reports
        synced and the moment it stops growing. nethermind&apos;s post-merge history backfills after snap; ethrex settles
        onto a no-history plateau. Exact byte figures are in the table below.
      </figcaption>
    </figure>
  )
}

// ---------------------------------------------------------------------------
// Chart 2 — EL disk "convergence band". Every EL that carries full post-merge
// history clusters at ~1.0–1.2 TiB; size is a config knob, not client
// efficiency. The two small footprints (ethrex, minimal-history nethermind)
// are LEFT of the band only because they retain no history — not because they
// are more efficient. Phase (synced / partial / no-sync) is encoded by marker
// shape; the short tag names the reason. Approximate GiB; exact figures are in
// the Stage B and Fresh-vs-steady tables.
// ---------------------------------------------------------------------------
const elDiskBand = [
  { name: 'nimbus_eth1', gib: 40, phase: 'partial', history: 'no-history', note: '~21.6%, full-sync-only' },
  { name: 'nethermind (minimal, default)', gib: 265, phase: 'synced', history: 'no-history', note: 'no history' },
  { name: 'ethrex', gib: 475, phase: 'synced', history: 'no-history', note: 'no history' },
  { name: 'reth', gib: 980, phase: 'partial', history: 'with-history', note: 'projected ~1.1–1.2 TiB' },
  { name: 'besu', gib: 1080, phase: 'synced', history: 'with-history', note: '' },
  { name: 'nethermind (full-history)', gib: 1088, phase: 'synced', history: 'with-history', note: '' },
  { name: 'geth', gib: 1130, phase: 'synced', history: 'with-history', note: 'baseline' },
  { name: 'erigon', gib: 1210, phase: 'no-sync', history: 'with-history', note: 'frozen partial' },
]
const edbMax = 1300
const edbX0 = 200
const edbW = 400
const edbX = (g: number) => edbX0 + (g / edbMax) * edbW
const edbFmt = (g: number) => (g >= 1000 ? g.toLocaleString('en-US') : String(g))

function ElDiskBandChart() {
  const rowStep = 32
  const top = 52
  const axisY = top + elDiskBand.length * rowStep
  return (
    <figure className="mt-5 hidden sm:block" aria-labelledby="edb-chart-title" aria-describedby="edb-chart-description">
      <svg className="h-auto w-full" viewBox="0 0 680 350" role="img">
        <title id="edb-chart-title">Execution-client disk footprint against the with-history convergence band</title>
        <desc id="edb-chart-description">
          Every execution client that carries full post-merge history clusters in a ~1.0–1.2 TiB band: geth, besu,
          nethermind (full-history), and reth (projected). The two small footprints, ethrex (~475 GiB) and minimal-history
          nethermind (~265 GiB), sit left of the band only because they retain no history, not because they are more
          efficient. erigon never reached a synced datadir.
        </desc>
        {/* convergence band */}
        <rect x={edbX(1000)} y="34" width={edbX(1200) - edbX(1000)} height={axisY - 34} fill="#a855f7" fillOpacity="0.10" />
        <text x={(edbX(1000) + edbX(1200)) / 2} y="28" textAnchor="middle" className="fill-muted-foreground text-[11px]">
          with-history band
        </text>
        {/* x gridlines */}
        {[0, 250, 500, 750, 1000, 1250].map((g) => (
          <g key={g}>
            <line x1={edbX(g)} x2={edbX(g)} y1="34" y2={axisY - 10} className="stroke-border" />
            <text x={edbX(g)} y={axisY + 6} textAnchor="middle" className="fill-muted-foreground text-[12px]">{g.toLocaleString('en-US')}</text>
          </g>
        ))}
        <text x={edbX0} y={axisY + 24} className="fill-muted-foreground text-[11px]">GiB (approximate)</text>
        {elDiskBand.map((row, index) => {
          const y = top + index * rowStep
          const cx = edbX(row.gib)
          const label = `~${edbFmt(row.gib)} GiB${row.note ? ` · ${row.note}` : ''}`
          const labelLeft = row.gib >= 700
          return (
            <g key={row.name}>
              <text x={edbX0 - 12} y={y + 4} textAnchor="end" className="fill-foreground text-[12px]">{row.name}</text>
              <line x1={edbX0} x2={cx} y1={y} y2={y} className="stroke-border" strokeWidth="1.5" />
              {row.phase === 'synced' && <circle cx={cx} cy={y} r="5.5" fill="#a855f7" stroke="#09090b" strokeWidth="2" />}
              {row.phase === 'partial' && <circle cx={cx} cy={y} r="5.5" fill="none" stroke="#c084fc" strokeWidth="2.5" />}
              {row.phase === 'no-sync' && (
                <g stroke="#c084fc" strokeWidth="2.5">
                  <line x1={cx - 5} y1={y - 5} x2={cx + 5} y2={y + 5} />
                  <line x1={cx - 5} y1={y + 5} x2={cx + 5} y2={y - 5} />
                </g>
              )}
              <text
                x={labelLeft ? cx - 12 : cx + 12}
                y={y + 4}
                textAnchor={labelLeft ? 'end' : 'start'}
                className="fill-muted-foreground text-[11px]"
              >
                {label}
              </text>
            </g>
          )
        })}
        {/* legend */}
        <g transform={`translate(0 ${axisY + 40})`}>
          <circle cx="204" cy="0" r="5.5" fill="#a855f7" stroke="#09090b" strokeWidth="2" />
          <text x="216" y="4" className="fill-muted-foreground text-[12px]">synced</text>
          <circle cx="288" cy="0" r="5.5" fill="none" stroke="#c084fc" strokeWidth="2.5" />
          <text x="300" y="4" className="fill-muted-foreground text-[12px]">partial / capped</text>
          <g stroke="#c084fc" strokeWidth="2.5" transform="translate(430 0)">
            <line x1="-5" y1="-5" x2="5" y2="5" />
            <line x1="-5" y1="5" x2="5" y2="-5" />
          </g>
          <text x="442" y="4" className="fill-muted-foreground text-[12px]">no-sync</text>
        </g>
      </svg>
      <figcaption className="mt-2 text-xs text-muted-foreground">
        Disk does not rank the field. Four with-history ELs cluster in the ~1.0–1.2 TiB band; the two small footprints
        retain no history rather than being leaner. Choose an EL on snap-sync speed and restart-resume, covered below —
        not on this axis.
      </figcaption>
    </figure>
  )
}

// ---------------------------------------------------------------------------
// Operational-viability picks — a scannable synthesis of the prose below. No
// new data: every claim here is stated, with evidence, in the section text.
// ---------------------------------------------------------------------------
const elPicks = [
  {
    tier: 'Run one of these',
    variant: 'primary' as const,
    items: [
      'geth — conservative default, largest ecosystem, cleanest ~8h28m snap; resumes downtime by importing missed blocks.',
      'nethermind — client diversity, compact flat-storage state; restart-resume bisected 12 min → ~35 h with no cliff.',
    ],
  },
  {
    tier: 'Qualified enterprise third',
    variant: 'primary' as const,
    items: [
      'besu — synced cleanly (~19h18m); snap sync is fragile to a prolonged CL outage, fine if you keep it current.',
    ],
  },
  {
    tier: 'Missed the operational bar',
    variant: 'default' as const,
    items: [
      'ethrex — fastest cold sync (~2h16m) but a ~25-min restart cliff; serves no history.',
      'reth, nimbus_eth1 — full-sync-only; cannot finish a mainnet sync inside 72h on this host.',
      'erigon — structural OtterSync + prysm deadlock; no synced datadir.',
    ],
  },
]

// ---------------------------------------------------------------------------
// Client limitations
// ---------------------------------------------------------------------------
const clientLimitations = [
  { el: 'besu', footprint: '~1.08 TiB', synced: 'yes', syncedDetail: '(~19h18m, fully validated)', why: "besu **synced fine**. Its caveat is prolonged CL outages during snap sync. A prune-lever re-run deadlocked twice after `SnapSyncChainDownloader` thread death, caused by a stale CL stall, **not** besu. See gotchas and Stage B." },
  { el: 'reth', footprint: '~0.98 TiB partial (72h-capped)', synced: 'partial', syncedDetail: '', why: '`--full`-only (no snap); sequential full block execution can\'t finish mainnet inside the 72h cap. Speed-bound, not config-bound.' },
  { el: 'nimbus_eth1', footprint: '**~40 GB partial @72h cap** (2026-07-13; supersedes an earlier ~21 GB aborted run)', synced: 'partial', syncedDetail: '(~21.6%)', why: "Full-sync-only, no snap: a stable **72h continuous run with zero restarts** (2026-07-11 to 07-13, 20–25 peers) reached only **~21.6%** of tip. Continuous pruning logs confirmed `prune = true` works online, resolving that earlier question. The limit is practical sync time on this host, not pruning." },
  { el: 'erigon', footprint: '~1.21 TiB frozen partial', synced: 'no', syncedDetail: '', why: 'Structural no-sync: erigon3 OtterSync + checkpoint-synced-prysm optimistic gap-close deadlock. Not a synced datadir.' },
  { el: 'ethrex', footprint: '~286–300 GiB at sync (fresh) → **~470–476 GiB steady-state plateau** (drifting 470.2 → 475.5 GiB over ~42h)', synced: 'yes', syncedDetail: '(~2h16m on v19.0.0, fully validated; a later re-sync on v22.0.0 took 4h09m56s — different day/host load too, not a regression)', why: "ethrex **synced cleanly, fastest in the field (~2h16m snap)**. Two operational caveats: no history (`eth_getBlockByNumber` returns `null` below head) and a restart cliff past ~25 minutes. It is smaller only because it retains no history, not because it’s leaner. See Stage B and gotchas." },
]

// ---------------------------------------------------------------------------
// Gotchas & lessons learned
// ---------------------------------------------------------------------------
const gotchaGroups = [
  {
    id: 'gotchas-sync-signals',
    title: 'Sync signals that lie',
    items: [
      "**Stage-A triage misses stalled ELs.** It checks CL tip and Engine-API JWT authentication. Optimistic checkpoint-sync passes even with 0 EL peers and frozen execution head: nethermind hid a 13.3h stall. Require peer-count>0 + advancing EL head + beacon `sync_distance`, never `sync_distance` alone.",
      "**`eth_syncing=false` does not prove sync.** It appears before snap starts (no pivot), after completion, and even mid-sync on besu. Use prysm `is_optimistic=false`: the EL validated the head payload.",
      "**Synced nethermind returns an `eth_syncing` OBJECT**, with `currentBlock==highestBlock`, rather than boolean false. The harness now accepts either condition.",
      "**besu sync has two tracks.** Block import reaches head first, giving a premature “done” signal. Bonsai world-state download/heal remains the bottleneck and expands disk usage.",
    ],
  },
  {
    id: 'gotchas-restart-resume',
    title: 'Restart & resume — the deciding axis',
    items: [
      "**besu snap-sync deadlocked twice after a long CL stall; the pruned re-run was abandoned.** Stale **prysm v7.1.5** hit a PeerDAS bug and stalled ~28h. Without `forkchoiceUpdated`, besu’s pivot aged beyond peers’ servable state: ~128 recent blocks, ≈25 min.\n\nWorld-state heal could not finish. besu threw `IllegalStateException: The pivot block number has not increased`; its sync thread died without restarting. The process still answered RPC, but the datadir stayed untouched with zero DB writes. Restarting reused the stale pivot and deadlocked again.\n\n**Keep the CL current; watch DB writes.** `eth_blockNumber` responses do not prove progress. The harness now offers an opt-in stall-watchdog: after bounded polls without progress, restart the unit a few times, then fail the row instead of reaching the cap.",
      "**ethrex stalls past ~25 min; ~1.5–2h gaps triggered a full re-snap (v19.0.0).** A routine restart with a ~1.5–2h gap made ethrex discard its fully synced 286 GiB state and restart near genesis: datadir 286 GiB → ~9 GiB → climbing. Journal: `SNAP SYNC STARTED` → `PHASE 1/8: BLOCK HEADERS` from ~198k/25.47M; `eth_blockNumber=0x0` throughout.\n\nIts old head exceeded peers’ ~128-block (~25 min) servable-state window. When prysm sent `forkchoiceUpdated`, ethrex re-pivoted instead of importing missed blocks. geth preserves state and imports the gap. Measured costs: **~2h16m cold + ~2h11m post-downtime re-snap**. The rebuilt datadir exceeded 286 GiB.\n\nThis operational pain is a strong candidate explanation for ethrex’s ~0% adoption despite its fastest cold sync.",
      "**ethrex’s cliff is bracketed at ~128 blocks / ~24–25 min (2026-07-10).** With live prysm driving forkchoice, controlled `systemctl stop eth1` → wait → `start` tests resumed at **12 min / 68 blk, 20 min / 108 blk, 23 min / 124 blk**. Missed blocks imported; datadir survived; canonical head returned to tip.\n\n**26 min / 132 blk stalled.** `eth_blockNumber` stayed at the pre-stop head for 12+ min; `eth_syncing.currentBlock=0x0`. Logs: `FCU head state not reachable from DB state … Starting sync toward head`; `Failed to fetch headers for sync head — peer(s) queried but did not serve headers`. The gap widened as tip advanced. No datadir collapse occurred within the 12-min watch; larger ~1.5–2h gaps escalated to full re-snap.\n\nThe edge matches the servable window: peers serve gap headers inside it, but not beyond it. This young v19.0.0 client may improve. The recorded 2h16m sync-time result remains unchanged.",
      "**geth resumed after ~52h (multi-day) downtime, measured 2026-07-10.** It was ~15,400 blocks behind, starting at `eth_syncing.startingBlock=25,487,154`, not genesis; no snap-pivot reset. It kept its multi-hundred-GB datadir and applied trie diffs during sequential block import. Every journal segment showed `Imported new chain segment … triediffs=… triedirty=…`.\n\nNo datadir collapse occurred, unlike ethrex’s 286 GiB → ~9 GiB. `eth_syncing` returned an import object, never `0x0`. State healing completed (`healingTrienodes=0x0`), then the node reached validating tip: `eth_syncing=false` at block 25,502,592. This preservation-and-import mechanism clears the operational bar for regular upgrades/restarts. Shared-host conditions prevent a clean wall-clock bound; only mechanism and datadir preservation are claimed.",
      "**nethermind showed no servable-window cliff in 2026-08-01 to 08-03 tests.** Unlike ethrex’s ~128-block cliff or besu’s pivot-aging deadlock, it resumed ordinary import. First, a CL restart left it **10,607 blocks (~35h) behind** external tip. It closed the gap in **35m09s (~302 blocks/min)**. Datadir grew **1.165 → 1.178 TB (+1.1%)**, matching imported bodies/receipts: **no state wipe or re-snap**.",
      "**Controlled stop→wait→start tests confirmed ordinary Engine-API import at every gap:** 12 min / 30 min / 1 h / 4 h, or 69 / 151 / 301 / 1,196 blocks. Every rung verified clean, without re-pivot or snap/state-sync.\n\nState-directory growth stayed **~1.0–1.3 MiB per imported block** across rungs. A re-snap would rewrite the whole ~238 GiB directory. Resume time scaled gently: 121s @ 12 min → 186s @ 1 h → 483s @ 4 h → 35m09s @ ~35 h. CL catch-up on missed slots dominated, rather than EL import.",
      "**A separate nethermind fresh sync took 1h52m51s on 2026-07-31:** ~280 GiB at snap, zero restarts. This supplements the ~14.5h Stage-B figure. Its minutes-old near-tip pivot and different network conditions explain the faster result.",
      "**prysm resumed from its own DB in four clean events (n=4, 2026-08-02 to 08-03).** After a deliberate 30-min CL stop, it drove the EL at `sync_distance=0` within **~2m44s**, without re-checkpoint-sync. During the stop, EL head froze undriven, beyond ethrex’s ~25-min cliff. The 12 min / 1 h / 4 h bisection rungs repeated re-checkpoint-free resume.\n\n**Only prysm was resume-tested.** Other CLs remain untested; prysm’s intermittent discovery-listener wedge was absent here, not disproven. Beacon-only operation, without validator keys, made deliberate stops zero-risk.",
    ],
  },
  {
    id: 'gotchas-client-measurement',
    title: 'Client-specific & measurement notes',
    items: [
      "**ethrex serves nothing before its snap-sync pivot, measured live 2026-07-29.** At head ~25,639,228, pivot 25,634,445 resolved at pivot+0 and pivot+200; pivot−1 (25,634,444) returned `null`. The exact window held 4,783 blocks (~16h), grew forward, and never backfilled. Blocks 1, 1,000,000, 21,600,000, and merge block 15,537,394 returned `null`.\n\n**Current-state RPC works.** `eth_chainId`, `eth_gasPrice`, `eth_getBalance`/`eth_getTransactionCount` @ latest, and `eth_call` @ latest resolved. Post-pivot blocks/receipts/logs worked: 615 logs over a 2-block USDC range at head−1000. Balances, current quotes, and allowances work for wallet traffic.\n\nPre-pivot blocks/logs/receipts fail with `Internal Error: Could not get body for block N`, excluding effectively all Ethereum history. This breaks indexer/subgraph backfill, portfolio history, and tax/accounting exports. The Q&A details the tighter state window, `eth_getLogs` deviation, and nginx/Caddy endpoint tradeoff against geth `--history.chain postmerge`.",
      "**Market share weakly predicts syncability.** erigon deadlocked; full-sync-only reth/nimbus_eth1 could not finish in 72h. Yet **ethrex (~0% share, Lambda Class) synced fastest (~2h16m)**. Snap availability and client reliability explain more: ethrex has snap and clock-based stale-pivot self-healing. Its measured ~470 GiB no-history plateau is not a disk win; speed remains its supported claim.",
      "**Loopback P2P broke peering.** besu and nethermind advertised `127.0.0.1`, causing degraded/zero peering. Removing loopback `p2p-host` / injecting routable `ExternalIp` fixed them. geth/erigon/reth/ethrex/nimbus_eth1 bind externally by default.",
      "**erigon3 OtterSync + checkpoint-synced prysm deadlock** — the one structural no-sync (see the erigon row): EL head freezes behind tip while the beacon stays optimistic; neither issues the `forkchoiceUpdated` that would close the gap. Raising CPU caps advanced it ~5k blocks then re-froze.",
      "**reth is `--full`-only here** (archive was the disk-hostile default; switched to `--full`); sequential full block execution can't finish a mainnet sync inside the 72h cap.",
      '**Sampler timestamp skew (~2h):** samples label local CEST times as `Z`. Trust file mtime for wall-clock, not the sample\'s `timestamp_utc` string.',
    ],
  },
]

// ---------------------------------------------------------------------------
// Reader Q&A: does ethrex serve a usable RPC? (measured live 2026-07-29/30
// against our own synced ethrex node, head ~25,646,566)
// ---------------------------------------------------------------------------
const rpcHistoryProbes = [
  { block: '1', era: 'genesis, 2015', result: 'null' },
  { block: '4,374,488', era: '2017 — ICO era', result: 'null' },
  { block: '12,000,000', era: '2021 — DeFi summer', result: 'null' },
  { block: '15,537,394', era: 'the merge block itself', result: 'null' },
]

const rpcConsequentlyBroken = [
  'Indexer/subgraph backfill',
  'Portfolio history',
  'Tax and accounting exports',
  'Historical charts',
  '"Show me my transaction from last month"',
  'Any analytics that replays past logs',
]

function RestartWindowFigure() {
  const gaps = [
    { gap: '12 min / 68 blocks', result: 'Resumed', color: '#a855f7' },
    { gap: '20 min / 108 blocks', result: 'Resumed', color: '#a855f7' },
    { gap: '23 min / 124 blocks', result: 'Resumed', color: '#a855f7' },
    { gap: '26 min / 132 blocks', result: 'Stalled', color: '#e5726e' },
  ]
  return (
    <figure className="mt-5 rounded-lg border border-border bg-muted/30 p-4" aria-label="ethrex resumed after gaps up to 23 minutes but stalled after 26 minutes in the restart bisection.">
      <p className="text-sm font-medium text-foreground">ethrex restart gaps · 2026-07-10 · v19.0.0</p>
      <svg className="mt-3 h-auto w-full" viewBox="0 0 320 224" role="img" aria-labelledby="restart-window-title" aria-describedby="restart-window-description">
        <title id="restart-window-title">ethrex restart gaps around the servable-state boundary</title>
        <desc id="restart-window-description">Gaps of 68, 108, and 124 blocks resumed. A gap of 132 blocks stalled, beyond the roughly 128-block window.</desc>
        <line x1={12 + (128 / 140) * 220} x2={12 + (128 / 140) * 220} y1="24" y2="216" stroke="#f5b46b" strokeDasharray="4 4" />
        <text x={12 + (128 / 140) * 220} y="14" textAnchor="end" className="fill-muted-foreground text-[13px]">~128-block boundary</text>
        {gaps.map((row, i) => {
          const blocks = [68, 108, 124, 132][i]
          const y = 42 + i * 50
          return (
            <g key={row.gap}>
              <text x="12" y={y} className="fill-foreground text-[13px]">{row.gap}</text>
              <rect x="12" y={y + 8} width={(blocks / 140) * 220} height="12" rx="2" fill={row.color} />
              <text x="244" y={y + 19} fill={row.color} className="text-[13px]">{row.result}</text>
            </g>
          )
        })}
      </svg>
      <figcaption className="mt-3 text-xs text-muted-foreground">
        The ~128-block (~24–25 min) boundary separates clean resume from a frozen head.
        Longer ~1.5–2h gaps triggered full re-snap. geth resumed after ~52h; nethermind after ~35h.
      </figcaption>
    </figure>
  )
}

function RpcWindowFigure() {
  return (
    <figure className="mt-5 rounded-lg border border-border bg-muted/30 p-4" aria-label="ethrex serves blocks from its snap-sync pivot onward, while historical state covers only about 128 recent blocks.">
      <div className="space-y-3 text-sm">
        <div className="rounded-md border border-[#e5726e] bg-[#e5726e]/10 p-3">
          <p className="font-medium text-foreground">Before pivot: unavailable</p>
          <p className="text-muted-foreground">25,634,444 → null</p>
        </div>
        <p className="text-center text-muted-foreground" aria-hidden="true">↓</p>
        <div className="rounded-md border border-[#a855f7] bg-[#a855f7]/10 p-3">
          <p className="font-medium text-foreground">Pivot onward: blocks served</p>
          <p className="text-muted-foreground">25,634,445 → head ~25,639,228</p>
          <p className="text-muted-foreground">4,783 blocks (~16h), growing forward</p>
          <div className="mt-3 rounded-md border border-[#f5b46b] bg-[#f5b46b]/10 p-3">
            <p className="font-medium text-foreground">State: ~128 recent blocks (~25 min)</p>
            <p className="text-muted-foreground">eth_call: head−100 works; head−500 fails</p>
          </div>
        </div>
      </div>
      <figcaption className="mt-3 text-xs text-muted-foreground">
        Live probe, 2026-07-29: block history starts at the pivot and never backfills. State has a tighter window.
      </figcaption>
    </figure>
  )
}

export default function BakeoffResultsPage() {
  return (
    <div className="min-h-screen py-12 sm:py-16 md:py-24">
      <div className="mx-auto max-w-5xl px-4 sm:px-6">
        <ArticleJsonLd slug="bakeoff-results" />
        <header id="article-top" tabIndex={-1} className="focus:outline-none">
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Raw results
          </p>
          <ArticleByline slug="bakeoff-results" />
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            Bake-off results — the raw data
          </h1>
          <p className="mt-3 text-sm italic text-muted-foreground">
            <Rich text="Stage A triage: synthesized from raw campaign logs on 2026-06-23. This page is the committed summary." />
          </p>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            Every triage row, Stage B disk measurement, three-anchor consensus matrix,
            client limitation, and campaign lesson from{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">
              docs/CLIENT_BAKEOFF_RESULTS.md
            </code>
            . Disk figures round to whole GB/MB. Charts and collapsible detail help scanning.
            For the narrative, read{' '}
            <Link href="/blog/ethereum-client-bakeoff" className="text-primary hover:underline">
              the bake-off blog post
            </Link>
            .
          </p>
          <div className="mt-4 flex flex-wrap gap-3 sm:mt-6">
            <Button href="/blog/ethereum-client-bakeoff" variant="secondary" size="sm">
              Read the narrative write-up
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
            <Button
              href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`}
              external
              variant="ghost"
              size="sm"
            >
              View source on GitHub
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
          </div>
        </header>

        <Card padding="sm" className="mt-8 bg-muted/30">
          <h2 className="font-medium text-foreground">In 30 seconds</h2>
          <ul className="mt-3 list-disc space-y-3 pl-5 text-sm text-muted-foreground">
            {atAGlance.map((item) => (
              <li key={item.title}>
                <strong className="text-foreground">{item.title}.</strong> {item.body}
              </li>
            ))}
          </ul>
        </Card>

        <ArticleToc links={tocLinks} />

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="method" className="text-lg sm:text-xl font-semibold text-foreground">Method</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Sequential testing isolates each candidate on a shared semi-prod host. No MEV; no validator keys.
            Execution clients (ELs) process transactions. Consensus clients (CLs) track the beacon chain.
            A shared JWT secret authenticates their connection.
          </p>
          <div className="mt-4 grid gap-3 sm:gap-4 md:grid-cols-2">
            {methodStages.map((s) => (
              <Card key={s.stage} padding="sm" className="bg-muted/30">
                <div className="flex items-center justify-between gap-3">
                  <h3 className="font-medium text-foreground">{s.stage}</h3>
                  <Badge variant="primary">{s.result}</Badge>
                </div>
                <dl className="mt-3 space-y-1.5 text-sm">
                  <div className="flex gap-2">
                    <dt className="w-16 shrink-0 text-muted-foreground">When</dt>
                    <dd className="text-foreground">{s.when}</dd>
                  </div>
                  <div className="flex gap-2">
                    <dt className="w-16 shrink-0 text-muted-foreground">Window</dt>
                    <dd className="text-foreground">{s.window}</dd>
                  </div>
                  <div className="flex gap-2">
                    <dt className="w-16 shrink-0 text-muted-foreground">Asks</dt>
                    <dd className="text-muted-foreground">{s.asks}</dd>
                  </div>
                </dl>
              </Card>
            ))}
          </div>
          <Details summary="Full method detail — coverage, stages, execution, pass criterion" className="mt-6">
          <ul className="space-y-3 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">Baseline-anchored coverage (12 candidates):</span>{' '}
              7 ELs against Prysm; 5 other CLs against a fixed EL.
              Each known-good counterpart isolates the candidate without testing every N×M pair.
              <ul className="mt-2 space-y-1.5 pl-4">
                <li>ELs × prysm: geth, erigon, reth, nethermind, besu, nimbus_eth1, ethrex</li>
                <li>
                  <Rich text="CLs × fixed anchor EL: lighthouse, teku, nimbus, lodestar, grandine. First anchor: **ethrex**, already at tip. The planned geth sweep was deferred, then completed on 2026-07-08; **nethermind** followed on 2026-07-26. All reproduced lightweight {lodestar, lighthouse}, mid {teku, grandine}, heavy {nimbus} tiers. Within-pair order depends on measurement time: lodestar↔lighthouse switched between ethrex/geth. On nethermind, teku varied ~25% (~700 → ~875 MB), crossing grandine’s ~765 MB. Published grandine < teku holds on every anchor; this is teku re-read variance, not an observed ranking swap." />
                </li>
              </ul>
            </li>
            <li>
              <span className="font-medium text-foreground">Two stages:</span>
              <ul className="mt-2 space-y-1.5 pl-4">
                <li>
                  <span className="font-medium text-foreground">Stage A — triage (this doc):</span>{' '}
                  does each candidate install, checkpoint-sync, and authenticate the Engine API?
                  June runs observed each candidate for ~5 min (300s), sampling every 60s.
                  geth__grandine used 15-min/120s. The shipped harness now defaults
                  `--stage=triage` to 90 min (5400s), sampling every 120s.
                </li>
                <li>
                  <span className="font-medium text-foreground">Stage B — full sync (complete):</span>{' '}
                  each candidate reached a final synced, capped, or no-sync verdict; synced disk footprints are recorded below.
                </li>
              </ul>
            </li>
            <li>
              <span className="font-medium text-foreground">Execution:</span> one candidate at a time,
              resource-capped to protect co-resident agents. No MEV or validator keys.
              Destructive data-clean requires{' '}
              <Rich text="`ETH2QS_BAKEOFF_CONFIRMED=yes` (secrets/validator material preserved)." />
            </li>
            <li>
              <span className="font-medium text-foreground">Pass criterion (Stage A):</span>{' '}
              <Rich text="beacon `head_slot` reaches network tip (~14.6M) on the first checkpoint-import sample (`is_optimistic=true`). `el_offline=false` confirms Engine-API JWT authentication; `sync_distance` trends to 0. This is the signature used for CL live-tracking of a validating EL; see the stalled-EL caveat below." />
            </li>
          </ul>
          </Details>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="stage-a" className="text-lg sm:text-xl font-semibold text-foreground">
            Stage A results — 12/12 PASS
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**All 12 pairs passed triage.** Prysm’s `el_offline` checks EL reachability and Engine API authentication. `False` throughout means correct JWT wiring and EL payload validation. `restErr` counts brief beacon REST outages during heavy-client startup; see Resource contention." />
          </p>

          <Details summary="All 12 Stage A rows — slots, samples, errors, and installer fixes" className="mt-4">
          <div
            className="mt-4 sm:mt-6 hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
            role="region"
            aria-label="Stage A triage results for all 12 client pairs"
            tabIndex={0}
          >
            <table className="w-full min-w-[52rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">Candidate</th>
                  <th className="pb-3 font-medium text-muted-foreground">Install</th>
                  <th className="pb-3 font-medium text-muted-foreground">Crash</th>
                  <th className="pb-3 font-medium text-muted-foreground">head (first→last)</th>
                  <th className="pb-3 font-medium text-muted-foreground">el_offline</th>
                  <th className="pb-3 font-medium text-muted-foreground">restErr</th>
                  <th className="pb-3 font-medium text-muted-foreground">n</th>
                  <th className="pb-3 font-medium text-muted-foreground">Verdict</th>
                  <th className="pb-3 font-medium text-muted-foreground">Installer fix</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {stageAResults.map((row) => (
                  <tr key={row.candidate}>
                    <td className="py-3 align-top font-medium text-foreground">
                      <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{row.candidate}</code>
                    </td>
                    <td className="py-3 align-top text-muted-foreground">{row.install}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.crash}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.head}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.elOffline}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.restErr}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.n}</td>
                    <td className="py-3 align-top"><Badge variant="primary">{row.verdict}</Badge></td>
                    <td className="py-3 align-top text-muted-foreground">{row.fix}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="mt-4 space-y-3 sm:hidden">
            {stageAResults.map((row) => (
              <div key={row.candidate} className="rounded-lg border border-border p-3">
                <div className="flex items-center justify-between gap-3">
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{row.candidate}</code>
                  <Badge variant="primary">{row.verdict}</Badge>
                </div>
                <dl className="mt-3 space-y-2 text-sm">
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Install</dt>
                    <dd className="text-right text-foreground">{row.install}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Crash</dt>
                    <dd className="text-right text-foreground">{row.crash}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">head (first→last)</dt>
                    <dd className="text-right text-foreground">{row.head}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">el_offline</dt>
                    <dd className="text-right text-foreground">{row.elOffline}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">restErr</dt>
                    <dd className="text-right text-foreground">{row.restErr}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">n</dt>
                    <dd className="text-right text-foreground">{row.n}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Installer fix</dt>
                    <dd className="text-right text-foreground">{row.fix}</dd>
                  </div>
                </dl>
              </div>
            ))}
          </div>

          <p className="mt-4 text-sm text-muted-foreground">
            <Rich text="All 12: `install_exit_code=0`, no service crash, `is_optimistic=true`, checkpoint-sync PASS signature." />
          </p>
          </Details>

          <AnchorHeading id="per-candidate-notes" as="h3" className="mt-8 font-medium text-foreground">
            Per-candidate notes
          </AnchorHeading>
          <ul className="mt-3 space-y-3 text-sm text-muted-foreground">
            {perCandidateNotes.map((note, i) => (
              <li key={i}><Rich text={note} /></li>
            ))}
          </ul>

          <AnchorHeading id="resource-contention" as="h3" className="mt-8 font-medium text-foreground">
            Resource contention
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**Startup contention caused brief REST outages, without blocking checkpoint sync.** Non-geth ELs and lodestar left Prysm’s beacon REST unavailable for 1–3 minutes (`restErr` above), then it recovered. CPU/IO competition with co-resident agents fits this shared-host behavior. This is the headline risk for Stage B: multi-day, IO-heavy syncs compete with co-resident workloads. Execution strategy must account for it when choosing sequential runs or small parallel batches." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="client-limitations" className="text-lg sm:text-xl font-semibold text-foreground">
            Client limitations
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Successful sync can still leave operational limits. besu risks stalled snap sync; ethrex has history and restart limits.
            reth/nimbus_eth1 exceeded the time cap; erigon deadlocked.
          </p>

          <Details summary="Per-client limitations — footprints, sync status, and causes" className="mt-4">
          <div
            className="mt-4 overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            role="region"
            aria-label="Execution client limitations"
            tabIndex={0}
          >
            <table className="w-full min-w-[52rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">EL</th>
                  <th className="pb-3 font-medium text-muted-foreground">Footprint recorded</th>
                  <th className="pb-3 font-medium text-muted-foreground">Synced?</th>
                  <th className="pb-3 font-medium text-muted-foreground">
                    Why it&apos;s listed here
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {clientLimitations.map((row) => (
                  <tr key={row.el}>
                    <td className="py-3 align-top font-medium text-foreground">{row.el}</td>
                    <td className="py-3 align-top text-muted-foreground min-w-[16rem]"><Rich text={row.footprint} /></td>
                    <td className="py-3 align-top">
                      <Badge variant={row.synced === 'yes' ? 'primary' : 'default'}>{row.synced}</Badge>
                      {row.syncedDetail && (
                        <p className="mt-1 text-xs text-muted-foreground">{row.syncedDetail}</p>
                      )}
                    </td>
                    <td className="py-3 align-top text-muted-foreground min-w-[28rem]"><Rich text={row.why} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          </Details>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="disk-flag-audit" className="text-lg sm:text-xl font-semibold text-foreground">
            Sync-mode &amp; disk-flag audit
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**Stage B uses each EL’s most disk- and time-efficient available sync mode.** We audited before starting slow full-sync runs to avoid accidental archive comparisons. geth’s `--history.chain postmerge` triggered the audit: it saves disk by pruning pre-merge block history. We verified it on the baseline, then checked every other EL." />
          </p>

          <Details summary="Per-EL disk/sync flag audit — full table (7 ELs)" className="mt-4">
          <div
            className="overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            role="region"
            aria-label="Sync-mode and disk-flag audit by execution client"
            tabIndex={0}
          >
            <table className="w-full min-w-[52rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">EL</th>
                  <th className="pb-3 font-medium text-muted-foreground">Disk/sync flags</th>
                  <th className="pb-3 font-medium text-muted-foreground">Status</th>
                  <th className="pb-3 font-medium text-muted-foreground">Notes</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {diskFlagAudit.map((row) => (
                  <tr key={row.el}>
                    <td className="py-3 align-top font-medium text-foreground">{row.el}</td>
                    <td className="py-3 align-top text-muted-foreground whitespace-nowrap"><Rich text={row.flags} /></td>
                    <td className="py-3 align-top"><Badge variant={row.variant}>{row.status}</Badge></td>
                    <td className="py-3 align-top text-muted-foreground min-w-[24rem]"><Rich text={row.notes} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          </Details>

          <p className="mt-4 rounded-lg border border-border p-3 text-sm font-medium text-foreground">
            <Rich text="**All seven ELs now use disk-optimal sync settings.** Six were already correct; only archive-by-default reth changed. Configuration comparisons are therefore equivalent. Sync time still differs: full-sync ELs execute all ~25M blocks, unlike geth’s snap baseline. Final footprint remains comparable." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="stage-b" className="text-lg sm:text-xl font-semibold text-foreground">
            Final synced disk footprint (Stage B)
          </AnchorHeading>
          <p className="mt-2 text-sm italic text-muted-foreground">
            <Rich text="**Every candidate has a final verdict:** synced, capped, or no-sync. Runs were sequential. Footprint means EL + CL datadir size, excluding secrets/validator material; capped and no-sync rows are partial." />
          </p>
          <p className="mt-4 text-sm text-muted-foreground">
            <Rich text="**Full post-merge history converges at ~1.0–1.2 TiB.** History retention sets size across clients. ethrex and minimal-history nethermind are smaller only because they retain no history, not because they’re leaner. Choose on snap-sync speed and restart-resume; see recommendations." />
          </p>

          <ElDiskBandChart />
          <dl className="mt-4 space-y-1.5 text-sm sm:hidden">
            {elDiskBand.map((row) => (
              <div key={row.name} className="flex items-baseline justify-between gap-3">
                <dt className="font-medium text-foreground">{row.name}</dt>
                <dd className="text-right text-xs text-muted-foreground">~{row.gib} GiB · {row.phase}{row.note ? ` · ${row.note}` : ''}</dd>
              </div>
            ))}
          </dl>

          <Details summary="Full Stage B footprint table — per-candidate bytes, verdicts, and notes" className="mt-6">
          <div
            className="overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            role="region"
            aria-label="Stage B final synced disk footprint results"
            tabIndex={0}
          >
            <table className="w-full min-w-[52rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">Candidate</th>
                  <th className="pb-3 font-medium text-muted-foreground">Result</th>
                  <th className="pb-3 font-medium text-muted-foreground">Sync time</th>
                  <th className="pb-3 font-medium text-muted-foreground">Final disk footprint (EL + CL)</th>
                  <th className="pb-3 font-medium text-muted-foreground">Notes</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {stageBFootprint.map((row) => (
                  <tr key={row.candidate}>
                    <td className="py-3 align-top font-medium text-foreground whitespace-nowrap">
                      <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{row.candidate}</code>
                    </td>
                    <td className="py-3 align-top"><Badge variant={row.variant}>{row.result}</Badge></td>
                    <td className="py-3 align-top text-muted-foreground whitespace-nowrap">{row.syncTime}</td>
                    <td className="py-3 align-top text-muted-foreground min-w-[16rem]"><Rich text={row.footprint} /></td>
                    <td className="py-3 align-top text-muted-foreground min-w-[28rem]"><Rich text={row.notes} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          </Details>

          <AnchorHeading id="fresh-vs-steady-state" as="h3" className="mt-10 font-medium text-foreground">
            Fresh-sync vs. steady-state disk footprint
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**“Synced” and “settled” can have different sizes.** nethermind’s pre-backfill ~251 GiB was not final. ethrex’s mid-climb ~467 GiB did not prove continuing growth. Both fresh and steady measurements appear below where available; missing phases are explicit." />
          </p>

          <FreshVsSteadyChart />
          <dl className="mt-4 space-y-1.5 text-sm sm:hidden">
            {freshVsSteadyBars.map((row) => (
              <div key={row.name} className="flex items-baseline justify-between gap-3">
                <dt className="font-medium text-foreground">{row.name}</dt>
                <dd className="text-right text-xs text-muted-foreground">
                  {row.freshLabel} fresh → {row.steadyLabel} steady ({row.steadyNote})
                </dd>
              </div>
            ))}
          </dl>

          <Details summary="Fresh and steady measurements — all recorded phases" className="mt-6">
          <div
            className="overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            role="region"
            aria-label="Fresh-sync versus steady-state disk footprint by execution client"
            tabIndex={0}
          >
            <table className="w-full min-w-[40rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">EL</th>
                  <th className="pb-3 font-medium text-muted-foreground">At snap-sync (fresh)</th>
                  <th className="pb-3 font-medium text-muted-foreground">Steady-state</th>
                  <th className="pb-3 font-medium text-muted-foreground">Note</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {freshVsSteadyFootprint.map((row) => (
                  <tr key={row.el}>
                    <td className="py-3 align-top font-medium text-foreground whitespace-nowrap">{row.el}</td>
                    <td className="py-3 align-top text-muted-foreground min-w-[14rem]"><Rich text={row.fresh} /></td>
                    <td className="py-3 align-top text-muted-foreground min-w-[16rem]"><Rich text={row.steady} /></td>
                    <td className="py-3 align-top text-muted-foreground min-w-[16rem]"><Rich text={row.note} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-xs text-muted-foreground">
            Only nethermind and ethrex have distinct fresh/steady measurements. geth and besu were measured only at finished size.
            reth never finished within 72h.
          </p>
          </Details>
          {/* -------------------------------------------------------------- */}
          <AnchorHeading id="cl-matrix" as="h3" className="mt-10 font-medium text-foreground">
            Consensus-client matrix across three anchors
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**The same three CL tiers appear on every execution anchor.** We held the EL constant and cycled CLs: **ethrex** first, already at tip, saving a multi-day re-sync; then **geth** and **nethermind** cross-checks. Each CL footprint is under ~1.1% of its anchor’s EL datadir. Engine API decoupling means anchor choice does not bias the comparison. Every EL datadir stayed untouched at tip; runs cycled only CL and validator keys." />
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <Rich text="**All five CLs reached a fully validating head on every anchor, without crashes.** Sync took **~22–23 min on ethrex**, already at tip, versus **~6–10 min on fresh geth/nethermind**. Time tracks anchor freshness, rather than CL choice, so footprint is the real differentiator. Figures below are decimal MB/GB." />
          </p>

          <Details summary="Full per-client table — all three anchors" className="mt-4">
          <div
            className="hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
            role="region"
            aria-label="Consensus client matrix across the ethrex, geth, and nethermind anchors"
            tabIndex={0}
          >
            <table className="w-full min-w-[52rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">CL</th>
                  <th className="pb-3 font-medium text-muted-foreground">Ethrex anchor</th>
                  <th className="pb-3 font-medium text-muted-foreground">Geth anchor</th>
                  <th className="pb-3 font-medium text-muted-foreground">Nethermind anchor</th>
                  <th className="pb-3 font-medium text-muted-foreground">Disk-optimal lever</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {clCrossAnchorMatrix.map((row) => (
                  <tr key={row.cl}>
                    <td className="py-3 align-top font-medium text-foreground">{row.cl}</td>
                    {(['ethrex', 'geth', 'nethermind'] as const).map((anchor) => (
                      <td key={anchor} className="py-3 align-top text-muted-foreground">
                        <div>{row[anchor].time}</div>
                        <div className="text-foreground">
                          {row[anchor].size}{row[anchor].tag ? ` (${row[anchor].tag})` : ''}
                        </div>
                      </td>
                    ))}
                    <td className="py-3 align-top text-muted-foreground min-w-[16rem]">{row.lever}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {clCrossAnchorMatrix.map((row) => (
              <div key={row.cl} className="rounded-lg border border-border p-3">
                <div className="font-medium text-foreground">{row.cl}</div>
                <dl className="mt-3 space-y-2 text-sm">
                  {(['ethrex', 'geth', 'nethermind'] as const).map((anchor) => (
                    <div key={anchor} className="flex justify-between gap-4">
                      <dt className="text-muted-foreground capitalize">{anchor} anchor</dt>
                      <dd className="text-right text-foreground">
                        {row[anchor].time} · {row[anchor].size}{row[anchor].tag ? ` (${row[anchor].tag})` : ''}
                      </dd>
                    </div>
                  ))}
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Lever</dt>
                    <dd className="text-right text-foreground">{row.lever}</dd>
                  </div>
                </dl>
              </div>
            ))}
          </div>
          </Details>

          <p className="mt-4 text-sm font-medium text-foreground">Disk ranking, smallest → largest:</p>
          <ul className="mt-2 space-y-1.5 text-sm text-muted-foreground">
            {clRankingsByAnchor.map((row) => (
              <li key={row.anchor}>
                <span className="font-medium text-foreground">{row.anchor}:</span> {row.order}
              </li>
            ))}
          </ul>

          <Details summary="CL measurement caveats — heap, watchdog, and sparse files" className="mt-4">
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground">
            {clMatrixNotes.map((note, i) => (
              <li key={i}><Rich text={note} /></li>
            ))}
          </ul>
          </Details>

          <p className="mt-4 text-sm font-medium text-foreground">Cross-anchor verdict — the tiers reproduce, not an identical order:</p>
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground">
            {crossAnchorVerdict.map((point, i) => (
              <li key={i}><Rich text={point} /></li>
            ))}
          </ul>

          <h3 className="mt-8 text-sm font-semibold text-foreground">The tier story across anchors</h3>
          <figure className="mt-2 hidden sm:block" aria-labelledby="cl-anchor-chart-title" aria-describedby="cl-anchor-chart-description">
            <svg className="h-auto w-full" viewBox="0 0 680 306" role="img">
              <title id="cl-anchor-chart-title">Consensus-client footprints across all three EL anchors (log scale)</title>
              <desc id="cl-anchor-chart-description">
                Each consensus client shows three marks, one per execution-client anchor. The tiers reproduce on every anchor: lodestar and lighthouse smallest, teku and grandine mid, nimbus largest. Ethrex-anchor values are systematically larger because those sweeps were measured longer after checkpoint-sync.
              </desc>
              {[200, 500, 1000, 2000, 5000].map((mb) => (
                <g key={mb}>
                  <line x1={clX(mb)} x2={clX(mb)} y1="24" y2="252" className="stroke-border" />
                  <text x={clX(mb)} y="270" textAnchor="middle" className="fill-muted-foreground text-[12px]">
                    {mb >= 1000 ? `${mb / 1000},000` : mb}
                  </text>
                </g>
              ))}
              <text x="592" y="270" className="fill-muted-foreground text-[11px]">MB (log scale)</text>
              {clCrossAnchorPoints.map((row, index) => {
                const y = 48 + index * 44
                return (
                  <g key={row.name}>
                    <text x="136" y={y + 4} textAnchor="end" className="fill-foreground text-[13px]">
                      {row.name}
                    </text>
                    <rect x={clX(row.geth) - 5} y={y - 5} width="10" height="10" rx="2" fill="#e9d5ff" stroke="#09090b" strokeWidth="2" />
                    <rect
                      x={clX(row.nethermind) - 5}
                      y={y - 5}
                      width="10"
                      height="10"
                      rx="1"
                      fill="none"
                      stroke="#c084fc"
                      strokeWidth="2"
                      transform={`rotate(45 ${clX(row.nethermind)} ${y})`}
                    />
                    <circle cx={clX(row.ethrex)} cy={y} r="5" fill="#a855f7" stroke="#09090b" strokeWidth="2" />
                  </g>
                )
              })}
              <g>
                <circle cx="156" cy="292" r="5" fill="#a855f7" stroke="#09090b" strokeWidth="2" />
                <text x="168" y="296" className="fill-muted-foreground text-[12px]">ethrex anchor (07-06)</text>
                <rect x="325" y="287" width="10" height="10" rx="2" fill="#e9d5ff" stroke="#09090b" strokeWidth="2" />
                <text x="342" y="296" className="fill-muted-foreground text-[12px]">geth anchor (07-08)</text>
                <rect x="498" y="287" width="10" height="10" rx="1" fill="none" stroke="#c084fc" strokeWidth="2" transform="rotate(45 503 292)" />
                <text x="514" y="296" className="fill-muted-foreground text-[12px]">nethermind anchor (07-26)</text>
              </g>
            </svg>
            <figcaption className="mt-2 text-xs text-muted-foreground">
              Circles (ethrex anchor) sit right of the others because those runs were measured
              longer after checkpoint-sync, not because the anchor changes the ranking.
              lodestar&apos;s geth- and nethermind-anchor marks overlap almost exactly (~185 vs ~186
              MB). Values are the published figures from the matrix above.
            </figcaption>
          </figure>
          <dl className="mt-4 space-y-2 text-sm sm:hidden">
            {clCrossAnchorPoints.map((row) => (
              <div key={row.name} className="flex items-baseline justify-between gap-3">
                <dt className="font-medium text-foreground">{row.name}</dt>
                <dd className="text-right text-xs text-muted-foreground">
                  ~{row.ethrex} / {row.geth} / {row.nethermind} MB (ethrex / geth / nethermind anchor)
                </dd>
              </div>
            ))}
          </dl>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="qa-ethrex-rpc" className="text-lg sm:text-xl font-semibold text-foreground">
            Reader Q&amp;A: does ethrex serve a usable RPC?
          </AnchorHeading>
          <p className="mt-2 text-sm italic text-muted-foreground">
            <Rich text="Live probes: 2026-07-29/30, our synced ethrex v22.0.0 node. Head advanced between probes." />
          </p>

          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**Usable from the sync point onward.** Earlier blocks are unavailable. The boundary is when you synced, rather than “wallet vs DeFi”." />
          </p>
          <RpcWindowFigure />

          <AnchorHeading id="qa-what-works" as="h3" className="mt-6 font-medium text-foreground">
            What works (verified)
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**Current-state DeFi reads work:** swap quotes, balances, allowances, and pool state. Every frontend method tested at `latest` passed: `eth_call`, `eth_getCode`, `eth_getStorageAt`, `eth_estimateGas`, `eth_getBalance`, `eth_getTransactionCount`, `eth_gasPrice`, `eth_feeHistory`, `eth_maxPriorityFeePerGas`, `web3_clientVersion`, `net_version`. `eth_sendRawTransaction` exists and validates input: malformed input returned `Invalid params: InvalidLength`." />
          </p>

          <AnchorHeading id="qa-deploy-today" as="h3" className="mt-6 font-medium text-foreground">
            The deploy-today test
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**Every dapp read worked for a recent deployment.** At head ~25,646,566, we tested a real contract-creation transaction 17 blocks back: block 25,646,549, tx `0xc909b51c…`, contract `0x227efd38ef38a798ae5ec9af062c437ee4bbef35`. `eth_getCode` returned **8,043 bytes of bytecode**. `eth_getStorageAt`, `eth_getTransactionByHash`, `eth_getTransactionReceipt`, and `eth_getLogs` from deploy block to `latest` also worked." />
          </p>
          <p className="mt-3 rounded-lg border border-border p-3 text-sm font-medium text-foreground">
            ethrex can serve a dapp frontend for a contract deployed today, including current-state reads.
          </p>

          <AnchorHeading id="qa-what-doesnt-work" as="h3" className="mt-6 font-medium text-foreground">
            What does NOT work
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Every pre-merge probe returns <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">null</code>:
          </p>
          <div
            className="mt-4 overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            role="region"
            aria-label="ethrex historical block probes, all pre-merge"
            tabIndex={0}
          >
            <table className="w-full min-w-[32rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">Block probed</th>
                  <th className="pb-3 font-medium text-muted-foreground">Era</th>
                  <th className="pb-3 font-medium text-muted-foreground"><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_getBlockByNumber</code></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {rpcHistoryProbes.map((row) => (
                  <tr key={row.block}>
                    <td className="py-3 align-top font-medium text-foreground">{row.block}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.era}</td>
                    <td className="py-3 align-top"><Badge>{row.result}</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            <Rich text="**History starts exactly at the snap-sync pivot.** pivot−1 (25,634,444) returned `null`; pivot+0 (25,634,445) was served. At this earlier probe, head ~25,639,228, the window held 4,783 blocks (~16h). It grows forward but never backfills." />
          </p>

          <AnchorHeading id="qa-historical-state" as="h3" className="mt-6 font-medium text-foreground">
            Historical state limit
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**Historical state is roughly the last ~128 blocks (~25 minutes).** `eth_call` succeeds at head−100; head−500 fails: `Vm execution error: DB error: state root missing for block N`. Older “balance at block X” requests fail." />
          </p>

          <p className="mt-4 text-sm font-medium text-foreground">Consequently broken:</p>
          <ul className="mt-2 list-inside list-disc space-y-1 text-sm text-muted-foreground">
            {rpcConsequentlyBroken.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>

          <p className="mt-4 text-sm text-muted-foreground">
            <Rich text="**`eth_getLogs` requires `topics`.** Omitting it returns `Expected parameter: topics is missing`; geth treats it as optional. Conformant tooling can fail even inside ethrex’s served window." />
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <Rich text="**The shipped nginx/Caddy RPC setup inherits these limits.** geth with `--history.chain postmerge` serves post-merge history. ethrex handles current-state/wallet traffic but returns `null`/errors outside its history window. If exposing an endpoint is the goal, that’s an independent reason to prefer geth or nethermind. ethrex is not a drop-in public RPC for users expecting history." />
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <Rich text="**ethrex’s ~470–476 GiB plateau is not a disk win.** The ~600 GiB difference is history other clients retain. Footprint tracks retention." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="operational-viability" className="text-lg sm:text-xl font-semibold text-foreground">
            Recommendation &amp; operational viability
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**geth and nethermind clear the durability bar.** All 12 pairs installed, checkpoint-synced, and passed Stage A; full-history disk sizes converge. Restarts, upgrades, and weeks of uptime separate them. ELs carry the operational risk. CLs look solved only for measured sync and footprint; only prysm was restart-tested." />
          </p>

          <div className="mt-6 grid gap-3 sm:gap-4 md:grid-cols-3">
            {elPicks.map((pick) => (
              <Card key={pick.tier} padding="sm" className="bg-muted/30">
                <Badge variant={pick.variant}>{pick.tier}</Badge>
                <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
                  {pick.items.map((item, i) => (
                    <li key={i}><Rich text={item} /></li>
                  ))}
                </ul>
              </Card>
            ))}
          </div>
          <p className="mt-4 text-xs italic text-muted-foreground">
            EL summary; CL guidance and caveats follow.
          </p>

          <AnchorHeading id="execution-clients-viability" as="h3" className="mt-6 font-medium text-foreground">
            Execution clients
          </AnchorHeading>
          <ul className="mt-3 space-y-3 text-sm text-muted-foreground">
            <li>
              <Rich text="**History retention sets disk size.** Full-history ELs converge at ~1.0–1.2 TiB: geth 1.13, nethermind ~1.06, besu 1.08, reth ~1.1–1.2 projected. **Update 2026-08-03:** nethermind ships **minimal-history by default**, staying at ~250–280 GiB, state only. Pre-sync blocks return `null`, like ethrex. For public RPC history, set `NETHERMIND_FULL_HISTORY=true` on a fresh datadir. Its no-history size beats ethrex’s ~470 GiB and reaches a floor geth cannot. Calling it “4× leaner than geth” would compare unlike history settings. With history retained, choose on snap speed and restart-resume." />
            </li>
            <li>
              <Rich text="**geth and nethermind both reached validating tip and resumed cleanly.** They are the two most battle-tested codebases here, with comparable full-history disk (~1.06 vs ~1.13 TiB). geth offers the largest ecosystem, conservative default, and cleanest ~8h28m snap. nethermind offers diversity and compact flat-storage state. Every tested gap from 12 min to ~35h resumed through ordinary import, without re-snap or cliff. Either supports long-running operation." />
            </li>
            <li>
              <Rich text="**besu is a viable enterprise third.** It fully validated; ~1.08 TiB is the same magnitude as geth/nethermind: comparable, not an outlier. A prolonged CL outage can age its snap pivot beyond servable state. The sync thread then dies, observed twice and unrecoverable. Keep the CL current; this is not a set-and-forget solo-staker choice." />
            </li>
            <li>
              <span className="font-medium text-foreground">Each remaining EL missed a specific operational requirement:</span>
              <ul className="mt-2 space-y-2 pl-4">
                <li>
                  <Rich text="**ethrex** syncs fastest (~2h16m), but 26-minute downtime stalled; 1.5–2h gaps triggered full re-snap. Its datadir settles at ~470–476 GiB, rather than growing unbounded. It is smaller only because it retains no history, not because it’s leaner. nethermind’s ~226–230 GiB state is smaller, though different encodings prevent a perfectly controlled comparison. Fast setup remains painful to operate without restart recovery. This young client moved v19.0.0 → v22.0.0 during the campaign and may improve." />
                </li>
                <li>
                  <Rich text="**reth, nimbus_eth1** cannot reach tip practically on this host: full-sync-only, no snap. This misses our snap-to-tip bar; it is not a universal client verdict. reth is widely run elsewhere." />
                </li>
                <li>
                  <Rich text="**erigon** — deadlocked against checkpoint-synced prysm on this host (structural, reproducible), so no synced datadir." />
                </li>
              </ul>
            </li>
            <li>
              <Rich text="**Stage-A note:** geth, besu, nimbus_eth1, ethrex passed Stage A with zero installer changes and zero REST contention — the cleanest out-of-the-box ELs against Prysm." />
            </li>
          </ul>

          <AnchorHeading id="consensus-clients-viability" as="h3" className="mt-6 font-medium text-foreground">
            Consensus clients
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**Every swept CL worked:** lighthouse, lodestar, grandine, teku, nimbus. All checkpoint-synced to validating head in ~22–23 min without crashes. Within measured sync/footprint, choose by size and preference; only prysm has resume evidence." />
          </p>
          <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
            <li>
              <Rich text="**Disk order (the only differentiator):** on ethrex, lighthouse (~773 MB) &lt; lodestar (~868 MB) &lt; grandine (~992 MB with `--prune-storage`) &lt; teku (~2,161 MB) &lt; nimbus (~5,302 MB). **Recommended: lighthouse**, ~22-min checkpoint-sync, blob pruning enabled by default. lodestar is smaller on geth/nethermind, down to ~185 MB." />
            </li>
            <li>
              <Rich text="**Size teku’s JVM heap generously:** undersizing caused GC pressure on co-resident services and invalidated the first run. **Enable grandine `--prune-storage`**, or every state is stored. **nimbus** is otherwise clean but heaviest, ~6.9× lighthouse." />
            </li>
            <li>
              <Rich text="**Keep the CL binary current.** Stale prysm v7.1.5 stalled ~28h on a PeerDAS/data-column bug, aging out besu’s pivot. Binary freshness is an operational requirement." />
            </li>
          </ul>

          <p className="mt-4 text-sm text-muted-foreground">
            <Rich text="**Choose geth or nethermind** for long-running EL operation; besu qualifies where operators keep the CL healthy. Any swept CL works on measured axes; lighthouse is the lean default. Initial speed and size alone do not prove durability across restarts and uptime. That deciding risk sits in the EL layer." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="gotchas" className="text-lg sm:text-xl font-semibold text-foreground">
            Gotchas &amp; lessons learned
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Verify EL progress and restart recovery, even when RPC answers. Dates and measured thresholds follow by theme.
          </p>
          <RestartWindowFigure />
          {gotchaGroups.map((group) => (
            <div key={group.id} className="mt-8 first:mt-6">
              <AnchorHeading id={group.id} as="h3" className="font-medium text-foreground">
                {group.title}
              </AnchorHeading>
              <ul className="mt-3 space-y-4 text-sm text-muted-foreground">
                {group.items.map((item, i) => (
                  <li key={i} className="space-y-2">
                    {item.split('\n\n').map((paragraph, j) => (
                      <p key={j}><Rich text={paragraph} /></p>
                    ))}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="bottom-line" className="text-lg sm:text-xl font-semibold text-foreground">
            Bottom line
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Across six weeks and 12 pairs, sync speed and restart recovery separated clients. Disk size reflected history settings.
          </p>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
            <li>
              <Rich text="**Disk converges, it doesn’t rank:** ~1.0–1.2 TiB for full-history ELs (geth 1.13, nethermind ~1.06, besu 1.08, reth ~1.1–1.2 projected). Minimal-history nethermind (~250–280 GiB default) and ethrex (~470–476 GiB plateau) are smaller because they retain no history, not because they’re leaner." />
            </li>
            <li>
              <Rich text="**Speed has a real order:** ethrex (~2h16m) &lt; geth (~8h28m) &lt; nethermind (~14.5h) &lt; besu (~19h18m). reth and nimbus_eth1 never reached tip in the 72h cap (full-sync-only), and erigon deadlocked entirely against a checkpoint-synced CL." />
            </li>
            <li>
              <Rich text="**Restart-resume decides.** geth and nethermind imported missed blocks cleanly across tested gaps: 12 min up to ~52h/~35h. Neither re-snapped. ethrex stalled past ~25 min/~128 blocks; ~1.5–2h gaps triggered re-snap near scratch. besu’s snap sync deadlocks if a CL outage ages its pivot out of the ~128-block servable-state window." />
            </li>
            <li>
              <Rich text="**Pick geth or nethermind** for long-running nodes; besu qualifies for enterprise operators keeping the CL current. Any swept CL works, with lighthouse the lean default. ethrex’s fastest cold sync cannot offset its restart cliff and missing history: watch, rather than deploy, today." />
            </li>
          </ul>
        </section>

        <ReadNext currentSlug="bakeoff-results" />

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <h2 className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Sources
          </h2>
          <ul className="mt-3 flex flex-wrap gap-x-6 gap-y-2 text-sm">
            <li>
              <a
                href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary hover:underline"
              >
                Raw results doc{' '}
                <span className="text-muted-foreground">(CLIENT_BAKEOFF_RESULTS.md)</span>
              </a>
            </li>
          </ul>
        </section>
      </div>
      <BackToTop />
    </div>
  )
}
