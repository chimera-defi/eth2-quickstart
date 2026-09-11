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
    body: 'Every execution client against Prysm (7) plus every consensus client against a fixed anchor (5) installed, checkpoint-synced, and authenticated the Engine API — Stage A, June 2026.',
  },
  {
    title: 'Disk converges at ~1.0–1.2 TiB',
    body: 'At steady state, with full post-merge history, geth (1.13), nethermind (~1.06), and besu (1.08) land in the same band; reth\'s ~1.1–1.2 is a projection from its partial 72h-capped run. Footprint is a config knob, not a winner axis.',
  },
  {
    title: 'Pick on speed + restart-resume',
    body: 'geth and nethermind clear the full operational bar; besu is a qualified enterprise third. ethrex has the fastest cold sync in the field but a restart cliff.',
  },
  {
    title: 'Six weeks, every figure phased',
    body: 'Stage A (June) → Stage B disk + CL sweeps → steady-state and restart-resume follow-ups (through August 2026). Every number below states its lifecycle phase.',
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
  "**erigon — PASS with Stage-B re-verify flag.** Head stayed frozen at the checkpoint slot (14615808) and `sync_distance` grew 71→97 over the 5-min window. This is benign warmup, not a defect: `el_offline=false` throughout (Engine API reachable and authenticating), so the freeze is beacon-P2P backfill catching up, not a broken EL handshake. Re-verify head advances under Stage B's longer window.",
  "**reth — the only EL that needed installer fixes.** reth was the sole EL not passing `--authrpc.jwtsecret` to the shared secret that `ensure_jwt_secret` already created, so Prysm fell back to a non-shared auto-JWT → 401 → frozen head (`el_offline=True` early samples). Two commits fixed it; `el_offline` flips True→False once the shared JWT is wired. Also enabled HTTP-RPC on 127.0.0.1 for monitoring/consumers, matching the other ELs.",
  "**besu / nimbus_eth1 / ethrex — clean PASS, no fix.** JWT wiring correct out of the box. ethrex reached finalization (`finalizedEpoch=456756`). nimbus_eth1 additionally runs its own background historical EL sync from genesis (independent of the Engine API path, which works immediately).",
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
  { el: 'nimbus_eth1', flags: 'fast-sync (default) + `prune = true`', status: 'online-prune confirmed', variant: 'primary' as const, notes: '`prune = true` is now **empirically confirmed to prune online**: across a 72h run the journal logged continuous `Pruning history … pruned=N` entries as it imported blocks. The flag is **not** inert — it resolves an earlier open question about whether online pruning actually runs (it does). At-tip completeness vs. a full era1 export stays untested, since the node is full-sync-only and never reached tip inside 72h.' },
  { el: 'reth', flags: 'was archive (no flag) → now `--full`', status: 'fixed', variant: 'default' as const, notes: 'The **only misconfigured EL.** Default reth runs archive (~2.8 TiB). `--full` gives a pruned full node (~1.2 TiB): full block/receipt history, but pruned state changesets and indices (retains the last ~10k blocks). reth__prysm was relaunched with the fix.' },
]

// ---------------------------------------------------------------------------
// Final synced disk footprint (Stage B)
// ---------------------------------------------------------------------------
const stageBFootprint = [
  { candidate: 'geth__prysm', result: 'synced', variant: 'primary' as const, syncTime: '~8h28m', footprint: '**1.13 TiB** — geth 1,245 GB + prysm 655 MB', notes: 'Baseline. A snap-synced EL hands Prysm an already-validated head, so there is no large optimistic gap to close (verified clean, no crash).' },
  { candidate: 'erigon__prysm', result: 'no-sync', variant: 'default' as const, syncTime: 'n/a', footprint: '~1.21 TiB* — erigon 1,333 GB + prysm 1,646 MB', notes: '*Partial — captured at a near-tip **frozen** head, not a clean synced datadir. erigon3 OtterSync deadlocks against a checkpoint-synced Prysm: the EL head freezes a few thousand blocks behind tip while the beacon stays `is_optimistic=true`, and neither side issues the `forkchoiceUpdated` that would close the gap. Raising the CL CPU cap 200%→600% advanced the head ~5k blocks, then it re-froze — a genuine deadlock, not resource starvation. Terminated; no synced datadir was ever reached.' },
  { candidate: 'reth__prysm', result: 'capped (72h)', variant: 'default' as const, syncTime: 'n/a', footprint: '~0.98 TiB* — reth 1,065 GB + prysm 12.5 GB', notes: '*Partial — capped at block 11,970,965 of 25,395,872 (47% by block count, ~21% gas-weighted) after 72h. reth `--full` is the only no-snap EL here; sequential full block execution is too slow to finish inside the cap. Clean stop, no crash. This figure is reconstructed from the last sample before the cap, not a final disk scan. Extrapolation: at ~21% gas-executed it was already ~87% of geth\'s 1.13 TiB, projecting a final footprint of ~1.1–1.2 TiB.' },
  { candidate: 'nethermind__prysm', result: 'synced', variant: 'primary' as const, syncTime: '~14.5h', footprint: '**~1.06 TiB steady-state** (re-measured 2026-08-01: ~1,088 GiB — state ~226–230 GiB compact flat storage + ~843 GiB post-merge bodies/receipts + ~19 GiB headers/code) — **~251 GiB at snap-sync, before FastBlocks backfilled post-merge history** (268 GB at that point) + prysm 1,431 MB', notes: 'Snap-synced to head 25,428,620 with 49 peers, no crash. Compact flat-storage state (~226–230 GiB), but full post-merge history backfills it to ~1.06 TiB — on par with geth. **Update 2026-08-03:** post-merge history is a config knob, and the shipped default is now **minimal-history** (`NETHERMIND_FULL_HISTORY=false`): a fresh sync lands at **~250–280 GiB** (state only, no bodies/receipts) and stays there. This ~1.06 TiB figure is the full-history opt-in for RPC providers. The first attempt hit a 13.3h zero-peer loopback stall (P2P bound to 127.0.0.1, execution head frozen while the beacon looked healthy) — the origin of the "triage is blind to a stalled EL" lesson below. Fixing the installer to advertise a routable external IP resolved it; the re-run synced cleanly.' },
  { candidate: 'besu__prysm', result: 'synced; pruned re-run abandoned', variant: 'primary' as const, syncTime: '~19h18m', footprint: '**~1.08 TiB** — besu 1,190 GB + prysm 1,682 MB', notes: '**besu synced successfully** — snap-synced cleanly to a fully validating head (~50 peers) in ~19h18m, a working, production-viable node. Its **~1.08 TiB is the same magnitude** as geth (1.13 TiB) and nethermind (~1.06 TiB) at full post-merge history — comparable, not an outlier. A follow-up re-run testing a further prune lever **deadlocked twice and was abandoned** (see the besu snap-sync deadlock gotcha below — the trigger was a stale CL stall, **not** a besu fault). besu\'s real open issue is that snap sync is **fragile to a prolonged CL outage**, not its disk size.' },
  { candidate: 'ethrex__prysm', result: 'synced', variant: 'primary' as const, syncTime: '~2h16m–4h10m', footprint: '**~470–476 GiB steady-state plateau** (as of 2026-07-31: drifting 470.2 → 475.5 GiB over ~42 hours at +0.13 GiB/hr) — **~286 GiB at first sync** (307 GB, 2026-07-06); **~300 GiB at a later re-sync** (4h09m56s)', notes: 'Snap-synced to a fully validating head in ~2h16m on v19.0.0 — **fastest EL sync in the field.** A later re-sync on v22.0.0 took 4h09m56s (different day/host load, not a regression). 50 peers throughout; one automatic stale-pivot update self-healed in ~4 min with no intervention. No crash. Footprint is un-pruned and **not full-history** — ethrex serves ~no history (`eth_getBlockByNumber` returns `null` below head, verified live). Its datadir **plateaus, it does not grow unbounded**: after sync it climbed +43 GiB/hr during post-sync settling, then growth collapsed ~300× to +0.13 GiB/hr and drifted 470.2 → 475.5 GiB over ~42 hours (verified clean throughout). The earlier ~467 GiB reading was this same plateau caught mid-climb, not evidence of unbounded growth. **Not a disk win:** it\'s smaller only because it retains no history — nethermind\'s state alone is ~226–230 GiB, roughly half ethrex\'s total (not a perfectly controlled comparison — different state encodings, and ethrex\'s total also includes headers/recent blocks). See client limitations and gotchas for the restart cliff (unchanged) and the no-history RPC cost.' },
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
    ethrex: { time: '~22m', size: '946 MB (actual)' },
    geth: { time: '~8m50s', size: '725 MB (actual)' },
    nethermind: { time: '~9m58s', size: '730 MB (actual)' },
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
  { anchor: 'Ethrex anchor', order: 'lighthouse (773 MB) < lodestar (868 MB) < grandine (946 MB) < teku (2,161 MB) < nimbus (5,302 MB)' },
  { anchor: 'Geth anchor', order: 'lodestar (185 MB) < lighthouse (542 MB) < grandine (725 MB) < teku (977 MB) < nimbus (1,198 MB)' },
  { anchor: 'Nethermind anchor', order: 'lodestar (186 MB) < lighthouse (492 MB) < grandine (730 MB) < teku (875 MB) < nimbus (1,338 MB)' },
]

const clMatrixNotes = [
  "**teku needed a re-run on the ethrex anchor.** Its first attempt starved the shared host's JVM heap, took 64 min to sync, and produced a discarded reading. Raising `TEKU_CACHE` to 8192m fixed it — the re-run synced clean in 22 min. Lesson: size teku's JVM heap generously on a shared host, or its GC pressure spills onto co-resident services.",
  "**lodestar's first nethermind-anchor run (~76m) was a fluke, not a lodestar property.** It started while the anchor EL was still importing an unrelated ~2-day block gap left by a separate crash-loop incident. Re-measured after the anchor recovered: ~7m36s / 186 MB — in line with the other four CLs and its own geth-anchor number.",
  '**teku showed a false "not synced" reading twice on the nethermind anchor — a watchdog bug, not a real problem.** In both cases the anchor was healthy by the time the measurement was taken; the watchdog had latched onto an early warm-up blip and never re-checked. Both runs\' footprints are valid; the published figure (875 MB) is the clean re-read (a first run measured ~667 MB).',
  "**grandine's apparent size overstates real usage.** It uses sparse DB files: a raw byte count reads ~1,074 MB on the geth/nethermind anchors and ~1,344 MB on the longer-running ethrex anchor — not measurement error, just a bigger sparse pre-allocation from more time since sync. Actual on-disk usage is what's used above: ~725–730 MB on the geth/nethermind anchors, ~946 MB on the ethrex anchor.",
]

const crossAnchorVerdict = [
  '**nimbus is the largest CL on all three anchors** — the one ranking that holds without exception.',
  '**{lodestar, lighthouse} are the two smallest CLs on all three anchors**, but which one is smallest is measurement-window-sensitive: lighthouse is smallest on the ethrex anchor; lodestar is smallest on the geth and nethermind anchors.',
  "**{teku, grandine} form a \"mid\" tier with a soft internal order.** teku's two nethermind-anchor readings (~667 → 875 MB, see note above) cross grandine's ~730 MB. Taking the clean re-read as authoritative, grandine < teku holds on all three anchors — but that pair's order is measurement-sensitive, not a stable client property.",
  '**Absolute footprints scale with observation time, not just the anchor.** The geth- and nethermind-anchor numbers are much smaller than the ethrex-anchor ones (e.g. nimbus ~1.2–1.3 GB vs ~5.3 GB) because those sweeps were measured minutes after checkpoint-sync, while the ethrex-anchor runs ran longer post-sync. The tiers hold anyway; exact within-tier order does not.',
  '**Net:** three different EL anchors reproduce the same three tiers — lightweight {lodestar, lighthouse}, mid {teku, grandine}, heavy {nimbus} — supporting EL/CL decoupling, without an identical total order across anchors.',
]

// Cross-anchor CL footprints (approximate published values, MiB) for the dot plot.
// Log axis: the field spans ~177 MiB to ~5 GiB. Anchor identity is double-encoded
// (shape + tone) since the site palette is single-accent.
const clCrossAnchorPoints = [
  { name: 'Lodestar', ethrex: 827, geth: 177, nethermind: 178 },
  { name: 'Lighthouse', ethrex: 739, geth: 518, nethermind: 470 },
  { name: 'Grandine', ethrex: 946, geth: 725, nethermind: 730 },
  { name: 'Teku', ethrex: 2150, geth: 936, nethermind: 848 },
  { name: 'Nimbus', ethrex: 5120, geth: 1229, nethermind: 1331 },
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
  { el: 'besu', footprint: '~1.08 TiB', synced: 'yes', syncedDetail: '(~19h18m, fully validated)', why: 'besu **synced fine**, and its ~1.08 TiB is the same magnitude as geth/nethermind at full post-merge history — comparable, not an outlier. It\'s listed here for its operational caveat, not its disk size: a follow-up re-run to test a further prune lever deadlocked twice and was abandoned (stale-pivot → `SnapSyncChainDownloader` thread death; root-caused to a ~28h prysm-v7.1.5 CL stall, **not** a besu fault — see gotcha below), underscoring that besu\'s snap sync is fragile to a prolonged CL outage.' },
  { el: 'reth', footprint: '~0.98 TiB partial (72h-capped)', synced: 'partial', syncedDetail: '', why: '`--full`-only (no snap); sequential full block execution can\'t finish mainnet inside the 72h cap. Speed-bound, not config-bound.' },
  { el: 'nimbus_eth1', footprint: '**~40 GB partial @72h cap** (2026-07-13; supersedes an earlier ~21 GB aborted run)', synced: 'partial', syncedDetail: '(~21.6%)', why: 'Full-sync-only (no snap). A 72h capped run (2026-07-11 to 07-13) ran **72h continuously with zero restarts** (stable throughout, 20–25 peers) and reached **~21.6%** of tip — nowhere close. Separately confirmed this run: `prune = true` **does prune online** (the journal logged continuous pruning during import), resolving an earlier open question about whether the flag does anything. It\'s listed here only because a full-sync-only client can\'t reach tip in a practical window on this host, **not** because the prune lever fails.' },
  { el: 'erigon', footprint: '~1.21 TiB frozen partial', synced: 'no', syncedDetail: '', why: 'Structural no-sync: erigon3 OtterSync + checkpoint-synced-prysm optimistic gap-close deadlock. Not a synced datadir.' },
  { el: 'ethrex', footprint: '~286–300 GiB at sync (fresh) → **~470–476 GiB steady-state plateau** (drifting 470.2 → 475.5 GiB over ~42h)', synced: 'yes', syncedDetail: '(~2h16m on v19.0.0, fully validated; a later re-sync on v22.0.0 took 4h09m56s — different day/host load too, not a regression)', why: 'ethrex **synced cleanly and fastest in the field (~2h16m snap).** It has no history-prune lever (`--syncmode snap` only) — moot, since it retains no history to prune. It serves ~no history (`eth_getBlockByNumber` returns `null` below head, verified live) and its datadir **plateaus rather than growing unbounded**: +43 GiB/hr while post-sync settling, then a ~300× collapse to +0.13 GiB/hr, drifting for ~42 hours (verified clean throughout). The earlier ~467 GiB reading was this same plateau caught mid-climb, not evidence of unbounded growth. **Not a disk win:** it\'s smaller only because it\'s a no-history node — nethermind\'s state alone (~226–230 GiB) is roughly half ethrex\'s entire total on a state-only basis (not a perfectly controlled comparison — different state encodings, and ethrex\'s total includes headers/recent blocks). See gotchas for the restart cliff and the no-history RPC cost.' },
]

// ---------------------------------------------------------------------------
// Gotchas & lessons learned
// ---------------------------------------------------------------------------
const gotchaGroups = [
  {
    id: 'gotchas-sync-signals',
    title: 'Sync signals that lie',
    items: [
      '**Stage-A triage is blind to a stalled EL.** Triage only checks that the CL reaches tip and the Engine-API JWT handshake works. A node whose CL checkpoint-syncs optimistically PASSES triage even with 0 EL peers and a frozen execution head (nethermind hid a 13.3h zero-progress stall this way). A sync-health verdict must combine peer-count>0 + EL-head advancing + beacon `sync_distance` — never `sync_distance` alone.',
      '**`eth_syncing=false` is a trap, not a done-signal.** It returns `false` BOTH before snap-sync starts (no pivot yet) and after it finishes. The authoritative "synced" gate is prysm `is_optimistic=false` (EL validated the head payload). besu\'s `eth_syncing` also returns `false` mid-sync — same trap.',
      '**A synced nethermind\'s `eth_syncing` returns an OBJECT, not boolean false** (`currentBlock==highestBlock`). The bakeoff harness now treats the EL as synced on `currentBlock==highestBlock`, not only boolean `false`.',
      "**besu snap sync is two tracks:** block-import reaches head first (a premature “done” signal), but world-state download/heal (Bonsai) is the real bottleneck and where the footprint balloons.",
    ],
  },
  {
    id: 'gotchas-restart-resume',
    title: 'Restart & resume — the deciding axis',
    items: [
      '**besu snap-sync deadlocks if the CL stalls long enough.** The besu pruned re-run deadlocked **twice** and was abandoned. Chain of events: a stale **prysm v7.1.5** build hit a PeerDAS bug and stalled the CL for ~28h, so with no `forkchoiceUpdated` driving it, besu\'s snap-sync pivot **aged out** of the network\'s servable-state window (full nodes only serve state for ~128 recent blocks, ≈25 min). World-state heal became un-completable, besu threw `IllegalStateException: The pivot block number has not increased`, and the sync thread **died without restarting** — the process stayed alive and answered RPC while frozen (datadir untouched, zero DB writes). A restart just resumed on the same stale pivot and re-deadlocked identically. **Takeaways:** keep the CL binary current before a long besu snap-sync; besu answering `eth_blockNumber` does not mean besu is syncing (watch DB writes instead). This is also why the harness now ships an opt-in stall-watchdog: if a client makes no forward progress for a bounded number of polls, it restarts that unit a few times, then fails the row instead of spinning to the cap.',
      "**ethrex restart cliff: gaps past ~25 min stall, and gaps of ~1.5–2h trigger a full re-snap from scratch (operational cliff, v19.0.0).** A routine restart with a ~1.5–2h gap made ethrex **discard its fully-synced 286 GiB state and start a fresh snap sync from near-genesis** (datadir collapsed 286 GiB → ~9 GiB → climbing; journal `SNAP SYNC STARTED` → `PHASE 1/8: BLOCK HEADERS` from ~198k/25.47M; `eth_blockNumber`=`0x0` throughout). Root cause: ethrex's old head aged out of the network's ~128-block (~25 min) servable-state window, so when prysm drove `forkchoiceUpdated` to the current head, ethrex re-pivoted to a full snap instead of importing the missed gap — contrast **geth**, which resumes by importing the missed blocks and keeps its state. Two measured re-sync costs: **~2h16m (cold) + ~2h11m (post-downtime re-snap)**; the re-snapped datadir then rebuilt *past* the old 286 GiB. **Blog through-line:** a client that stops resuming beyond ~25 minutes and can full-re-sync on longer gaps is operationally painful — a strong candidate explanation for ethrex's ~0% adoption despite the field's fastest cold sync.",
      "**ethrex's resume cliff is precisely bracketed at ~128 blocks / ~24–25 min (2026-07-10 restart bisection).** Controlled `systemctl stop eth1` → wait → `start` runs with a live prysm driving forkchoice: gaps of **12 min / 68 blk, 20 min / 108 blk, and 23 min / 124 blk all resumed cleanly** (ethrex imported the missed blocks, datadir intact, canonical head climbed back to tip). A **26 min / 132 blk gap stuck** instead: the canonical head froze (`eth_blockNumber` flat at the pre-stop block for 12+ min, `eth_syncing.currentBlock=0x0`), ethrex logged `FCU head state not reachable from DB state … Starting sync toward head` and `Failed to fetch headers for sync head — peer(s) queried but did not serve headers`, and the gap widened as the tip advanced (no datadir collapse *within* the 12-min watch — the stuck disconnected-head state is the onset that escalates to the full re-snap at larger gaps). The cliff edge (**~128 blocks ≈ 24–25 min**) matches the servable window exactly: inside it, peers still serve the gap headers and ethrex bridges; beyond it, they don't, the head freezes, and the ~1.5–2h gap above drove the full datadir-collapse re-snap. Caveat: young client (v19.0.0, may improve); this does **not** change the recorded sync-time result (2h16m, captured at synced time).",
      '**geth resumes gracefully after a ~52h (multi-day) downtime — measured 2026-07-10 (the positive contrast to ethrex).** Restarted after a stop that had left it ~15,400 blocks / ~52h behind (`eth_syncing.startingBlock`=25,487,154 — *not* genesis, no snap-pivot reset), geth **kept its full multi-hundred-GB datadir** and caught up purely by **sequential block-import with trie-diff application** — journal `Imported new chain segment … triediffs=… triedirty=…` on every segment, *not* a re-snap. Throughout: no datadir collapse (contrast ethrex\'s 286 GiB → ~9 GiB), `eth_syncing` returned an import object (never `0x0`), state healing ran to completion (`healingTrienodes=0x0`), and it **converged back to the validating tip** (`eth_syncing=false` at block 25,502,592). This is the resume profile you want for an EL you upgrade/restart regularly, and it is *why* geth clears the operational bar above where ethrex\'s re-snap cliff does not. (Wall-clock resume time not cleanly bounded on this shared host, so only the mechanism + datadir preservation are claimed.)',
      '**nethermind\'s restart-resume is measured and bisected (2026-08-01 to 08-03): no servable-window cliff** — the direct contrast to ethrex\'s ~128-block cliff and besu\'s pivot-aging deadlock. An opportunistic CL-outage catch-up came first: a CL restart left nethermind **10,607 blocks (~35h of chain) behind** the external tip, and it closed the entire gap by ordinary block import in **35m09s (~302 blocks/min)**. The datadir grew **1.165 → 1.178 TB (+1.1%**, exactly the imported bodies/receipts) with **no state wipe, no re-snap**.',
      '**A controlled stop→wait→start bisection confirms the same resume path at every gap size tested.** At 12 min / 30 min / 1 h / 4 h gaps (69 / 151 / 301 / 1,196 blocks), **every rung resumed geth-style** — ordinary Engine-API block import, no re-pivot, no snap/state-sync (verified clean throughout). The re-pivot tell stayed silent: the state dir moved **~1.0–1.3 MiB per imported block, constant across rungs** (a re-snap would rewrite the whole ~238 GiB state dir). Resume time scales gently with the gap (121s @ 12 min → 186s @ 1 h → 483s @ 4 h → 35m09s @ ~35 h), dominated by the CL re-syncing its missed slots, not by EL import.',
      '**A separate fresh-sync run (2026-07-31) is a second data point, not a replacement for the Stage-B figure.** It snap-synced nethermind fresh in **1h52m51s** (~280 GiB at snap, zero restarts) — far faster than the ~14.5h Stage-B figure because the pivot was minutes-old and near-tip, and network conditions differ.',
      '**prysm restarts cleanly from its own DB — measured, n=4 (2026-08-02 to 08-03).** A deliberate 30-min CL stop (past ethrex\'s ~25-min cliff, the EL left undriven with its head frozen) resumed from the existing beacon DB and was back driving the EL at `sync_distance=0` within **~2m44s** of start — with no re-checkpoint-sync. The three bisection rungs (12 min / 1 h / 4 h) each repeated the same re-checkpoint-free resume, for **four clean resume events total**. Scope honestly stated: **prysm only** — this earns "prysm resumes cleanly," not "the CL layer is solved" (the other CLs are untested for resume, and prysm\'s intermittent discovery-listener wedge simply didn\'t occur in these runs — absent, not disproven). The node was beacon-only (no validator keys), so the deliberate stops were zero-risk.',
    ],
  },
  {
    id: 'gotchas-client-measurement',
    title: 'Client-specific & measurement notes',
    items: [
      '**ethrex serves no history beyond its snap-sync pivot — measured live 2026-07-29, to single-block precision.** Probing the live node (head ~25,639,228) against its snap pivot (block 25,634,445): `eth_getBlockByNumber` returns `null` at pivot−1 (25,634,444) but resolves cleanly at pivot+0 and pivot+200 — the servable window\'s back edge is *exactly* the pivot, not an approximation. That window held only 4,783 blocks (~16h of chain) at measurement time; it grows forward as new blocks arrive but never backfills — deep probes at blocks 1, 1,000,000, 21,600,000, and the merge block (15,537,394) all returned `null`. State is an even tighter window: `eth_call` succeeds at head−100 but fails at head−500 with `Vm execution error: DB error: state root missing for block N` — historical state is available for only the last ~128 blocks (~25 min), the same servable-state window that drives the restart cliff above. **What this costs the RPC-endpoint feature this repo ships (nginx/Caddy in front of the client):** current-state reads work fine on ethrex — `eth_chainId`, `eth_gasPrice`, `eth_getBalance`/`eth_getTransactionCount` @ latest, `eth_call` @ latest, and blocks/receipts/logs at or after the pivot all resolve (615 logs returned over a 2-block USDC range at head−1000), so wallet-style traffic (balances, current quotes, allowances) is fine. But any block/log/receipt before the pivot fails (`Internal Error: Could not get body for block N`) — effectively all of Ethereum history — breaking indexer/subgraph backfill, portfolio history, and tax/accounting exports. A geth endpoint with `--history.chain postmerge` serves that same history; ethrex does not, so it is not a drop-in replacement for a public DeFi-facing RPC. One more spec deviation inside the served window: ethrex\'s `eth_getLogs` **requires** `topics` (`Expected parameter: topics is missing`), where geth treats it as optional — conformant tooling that omits `topics` can break even on blocks ethrex does serve.',
      '**Client distribution is a WEAK/NUANCED predictor of syncability.** The tempting story — low/zero-share clients all struggle — is only half true. erigon (deadlock), reth & nimbus_eth1 (full-sync-only, can\'t finish in 72h) did struggle, but **ethrex (~0% share, Lambda Class) synced FASTEST in the whole field (~2h16m).** The real driver is **snap-sync availability + client robustness** (ethrex has both: snap + clock-based stale-pivot self-healing), not market share per se. Don\'t overclaim the correlation in the blog — ethrex\'s steady-state footprint (now measured: a ~470 GiB plateau) isn\'t a disk win, since it\'s a no-history node; speed remains its clean, settled claim.',
      '**Loopback-P2P class of bug.** besu AND nethermind both defaulted P2P advertising to `127.0.0.1` → degraded/zero peering. Fixed (remove loopback `p2p-host` / inject routable `ExternalIp`). geth/erigon/reth/ethrex/nimbus_eth1 bind externally by default.',
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
            <Rich text="Stage A (triage) was synthesized on 2026-06-23 from the raw campaign logs; this page is the committed summary." />
          </p>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            This is the full reference appendix: every Stage A triage row, every Stage B
            disk-footprint measurement, the consensus-client matrix across three anchors, the
            client-limitations table, and every gotcha from{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">
              docs/CLIENT_BAKEOFF_RESULTS.md
            </code>
            . Disk figures are rounded to whole GB/MB for readability, and charts and collapsible
            sections make the whole appendix scannable. For the story instead of the raw data,
            read{' '}
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

        <div className="mt-8 grid gap-3 sm:gap-4 md:grid-cols-2">
          {atAGlance.map((item) => (
            <Card key={item.title} padding="sm" className="bg-muted/30">
              <h3 className="font-medium text-foreground">{item.title}</h3>
              <p className="mt-1 text-sm text-muted-foreground">{item.body}</p>
            </Card>
          ))}
        </div>

        <ArticleToc links={tocLinks} />

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="method" className="text-lg sm:text-xl font-semibold text-foreground">Method</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Two stages, run strictly sequentially — one candidate at a time on a shared semi-prod host,
            no MEV, no validator keys.
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
              every execution client vs fixed Prysm (7 ELs), plus every other consensus client vs
              a fixed execution anchor (5 CLs). This isolates each client against a known-good counterpart
              instead of testing every N×M pair.
              <ul className="mt-2 space-y-1.5 pl-4">
                <li>ELs × prysm: geth, erigon, reth, nethermind, besu, nimbus_eth1, ethrex</li>
                <li>
                  <Rich text="CLs × fixed anchor EL: lighthouse, teku, nimbus, lodestar, grandine. The first sweep used **ethrex**, already synced at tip. The originally planned geth sweep was initially deferred, then completed on 2026-07-08 as a cross-anchor check, and a third sweep against a **nethermind** anchor followed on 2026-07-26. Across all three anchors the same three tiers reproduce — lightweight {lodestar, lighthouse}, mid {teku, grandine}, heavy {nimbus} — while the order within each pair is measurement-window-sensitive (lodestar↔lighthouse between ethrex and geth; on the nethermind anchor, teku itself moved ~27% across two runs — ~667 MB → ~875 MB — enough to cross grandine's ~730 MB; grandine < teku holds on all three anchors, so this is teku's own re-read variance, not a genuine swap with grandine)." />
                </li>
              </ul>
            </li>
            <li>
              <span className="font-medium text-foreground">Two stages:</span>
              <ul className="mt-2 space-y-1.5 pl-4">
                <li>
                  <span className="font-medium text-foreground">Stage A — triage (this doc):</span>{' '}
                  does each candidate install, checkpoint-sync, and authenticate the Engine API?
                  The June triage runs used a ~5-min (300s) observation window per candidate, 60s
                  sampling (one candidate, geth__grandine, ran 15-min/120s); the published harness
                  now defaults `--stage=triage` to a more generous 90-min (5400s) window, 120s sampling.
                </li>
                <li>
                  <span className="font-medium text-foreground">Stage B — full sync (complete):</span>{' '}
                  each candidate reached a final synced, capped, or no-sync verdict; synced disk footprints are recorded below.
                </li>
              </ul>
            </li>
            <li>
              <span className="font-medium text-foreground">Execution:</span> strictly sequential,
              ONE candidate at a time on this shared semi-prod host. Resource-capped to protect
              co-resident agents. MEV: none. No validator keys. Destructive data-clean gated by{' '}
              <Rich text="`ETH2QS_BAKEOFF_CONFIRMED=yes` (secrets/validator material preserved)." />
            </li>
            <li>
              <span className="font-medium text-foreground">Pass criterion (Stage A):</span>{' '}
              <Rich text="beacon `head_slot` reaches the network tip (~14.6M) via checkpoint import on the first sample (`is_optimistic=true`), `el_offline=false` (Engine-API JWT handshake succeeded), and `sync_distance` trending to 0 — i.e. the CL is live-tracking a validating EL." />
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
            <Rich text="`el_offline` is Prysm's own verdict on whether the EL is reachable **and** authenticating over the Engine API. `False` across the window = JWT wired correctly and the EL is validating payloads. `restErr` = beacon REST momentarily unavailable during heavy-client startup (see Resource contention below)." />
          </p>

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
            <Rich text="Heavier-client startups (non-geth ELs, and lodestar) showed Prysm's beacon REST briefly unavailable for the first 1–3 minutes (`restErr` counts above) before recovering — consistent with startup contending for CPU/IO against co-resident agents on this shared host. It did **not** block any checkpoint sync, but it is the headline risk for Stage B: a multi-day, IO-heavy full sync will compete with co-resident workloads. Stage B execution strategy (sequential vs. small parallel batches) must account for this." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="client-limitations" className="text-lg sm:text-xl font-semibold text-foreground">
            Client limitations
          </AnchorHeading>

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
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="disk-flag-audit" className="text-lg sm:text-xl font-semibold text-foreground">
            Sync-mode &amp; disk-flag audit
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="Before letting the slow full-sync ELs run, we audited every execution client to confirm it uses the most disk- and time-efficient sync mode available — so the Stage B footprint numbers reflect each client's *best* configuration, not an accidental archive run. Trigger: geth's `--history.chain postmerge` flag (prunes pre-merge block history, a large disk saving). We verified it was on for the baseline, then checked the rest." />
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
            <Rich text="**Net effect:** all seven ELs now run their disk-optimal sync mode. Six were already correct out of the box; reth was archive-by-default and is the one change this audit produced. Footprint comparisons across ELs are therefore apples-to-apples on configuration (the snap-vs-full *time* asterisk from the method section still applies — full-sync ELs execute all ~25M blocks, so time-to-sync is not comparable to geth's snap baseline, but final footprint is)." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="stage-b" className="text-lg sm:text-xl font-semibold text-foreground">
            Final synced disk footprint (Stage B)
          </AnchorHeading>
          <p className="mt-2 text-sm italic text-muted-foreground">
            <Rich text="Complete. Runs were sequential, one candidate at a time; every candidate now has a final synced, capped, or no-sync verdict. Footprint = final synced datadir size (EL + CL); secrets/validator material excluded." />
          </p>
          <p className="mt-4 text-sm text-muted-foreground">
            <Rich text="**Disk does not rank the field.** Every EL that carries full post-merge history converges on ~1.0–1.2 TiB — size is set by history-retention config, a client-agnostic knob. The two small footprints below (ethrex, minimal-history nethermind) sit left of the band only because they retain *no* history, not because they are leaner. Choose an EL on snap-sync speed and restart-resume instead (see the recommendation section)." />
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
            <Rich text="Several execution clients were captured at more than one point in their lifecycle, and a single number can mislead: nethermind's pre-backfill ~251 GiB looked like a final figure, and ethrex's mid-climb ~467 GiB looked like it was still growing. Neither was. Where both a fresh (at-sync) and a steady-state (settled) figure exist, both are recorded below; where only one was ever captured, that's stated explicitly." />
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

          <div
            className="mt-6 overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
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
            nethermind and ethrex are the only two ELs where a fresh-sync number was captured meaningfully before the steady-state figure; geth and besu were only ever measured at their finished, steady-state size, and reth never finished within the 72h cap.
          </p>
          {/* -------------------------------------------------------------- */}
          <AnchorHeading id="cl-matrix" as="h3" className="mt-10 font-medium text-foreground">
            Consensus-client matrix across three anchors
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="This matrix holds the **execution client constant** and cycles the consensus client — the mirror of the EL scorecard above. Three EL anchors were swept in turn: **ethrex** (already synced at tip, so reusing it saved a multi-day re-sync), then **geth** and **nethermind** as cross-anchor checks. Because the EL and CL are decoupled across the Engine API — every CL footprint here is under ~1.1% of its anchor's EL datadir, and doesn't depend on which EL it pairs with — the anchor choice does **not** bias the comparison, and all three sweeps land on the same three-tier ranking below. Each anchor's EL datadir stayed untouched and at tip throughout its sweep; every run only cycled the CL and validator keys." />
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <Rich text="All five CLs checkpoint-synced to a fully validating head on every anchor, no crashes. Sync took **~22–23 min on the ethrex anchor** (already at tip) and a faster **~6–10 min on the fresh geth and nethermind anchors** — sync time tracks anchor freshness, not the CL, so **footprint is the real differentiator** (figures below are decimal MB/GB)." />
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

          <p className="mt-4 text-sm font-medium text-foreground">Caveats:</p>
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground">
            {clMatrixNotes.map((note, i) => (
              <li key={i}><Rich text={note} /></li>
            ))}
          </ul>

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
              <text x="592" y="270" className="fill-muted-foreground text-[11px]">MiB (log scale, approximate)</text>
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
              lodestar&apos;s geth- and nethermind-anchor marks overlap almost exactly (~177 vs ~178
              MB). Values are the published approximations from the matrix above.
            </figcaption>
          </figure>
          <dl className="mt-4 space-y-2 text-sm sm:hidden">
            {clCrossAnchorPoints.map((row) => (
              <div key={row.name} className="flex items-baseline justify-between gap-3">
                <dt className="font-medium text-foreground">{row.name}</dt>
                <dd className="text-right text-xs text-muted-foreground">
                  ~{row.ethrex} / {row.geth} / {row.nethermind} MiB (ethrex / geth / nethermind anchor)
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
            <Rich text="Everything below was measured live on 2026-07-29/30 against our own synced ethrex node (v22.0.0), across several probes taken at different moments as the head advanced." />
          </p>

          <p className="mt-4 text-base font-medium text-foreground">Q: Does ethrex serve a usable RPC?</p>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="**A:** Yes — for anything at or after the block you synced at. No — for anything before it. The dividing line is your sync point, not “wallet vs DeFi”." />
          </p>

          <AnchorHeading id="qa-what-works" as="h3" className="mt-6 font-medium text-foreground">
            What works (verified)
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="A full dapp-frontend method sweep at `latest` all passed — `eth_call`, `eth_getCode`, `eth_getStorageAt`, `eth_estimateGas`, `eth_getBalance`, `eth_getTransactionCount`, `eth_gasPrice`, `eth_feeHistory`, `eth_maxPriorityFeePerGas`, `web3_clientVersion`, `net_version`. `eth_sendRawTransaction` is present and validates input (a deliberately malformed payload was rejected with `Invalid params: InvalidLength`). Current-state DeFi reads — swap quotes, balances, allowances, pool state — work normally." />
          </p>

          <AnchorHeading id="qa-deploy-today" as="h3" className="mt-6 font-medium text-foreground">
            The deploy-today test
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="We took a real contract-creation transaction from 17 blocks back — head ~25,646,566 at the time, block 25,646,549, tx `0xc909b51c…`, contract `0x227efd38ef38a798ae5ec9af062c437ee4bbef35` — and every dapp read worked: `eth_getCode` returned **8,043 bytes of bytecode**, plus `eth_getStorageAt`, `eth_getTransactionByHash`, `eth_getTransactionReceipt`, and `eth_getLogs` from its deploy block to `latest`." />
          </p>
          <p className="mt-3 rounded-lg border border-border p-3 text-sm font-medium text-foreground">
            So: deploy a contract today, read its state, and serve a dapp frontend from ethrex — all fine.
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
            <Rich text="The cutoff is exactly the snap-sync pivot, probed to single-block precision: pivot−1 (25,634,444) → `null`, pivot+0 (25,634,445) → served. At this earlier probe (head ~25,639,228), the node held only 4,783 blocks (~16h of chain). That window grows forward as it imports but never extends backward — ethrex does not backfill." />
          </p>

          <AnchorHeading id="qa-historical-state" as="h3" className="mt-6 font-medium text-foreground">
            Historical state limit
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="A second, much tighter limit: `eth_call` succeeds at head−100 but fails at head−500 with `Vm execution error: DB error: state root missing for block N`. Historical state is roughly the last ~128 blocks (~25 minutes). “What was this balance at block X” does not work." />
          </p>

          <p className="mt-4 text-sm font-medium text-foreground">Consequently broken:</p>
          <ul className="mt-2 list-inside list-disc space-y-1 text-sm text-muted-foreground">
            {rpcConsequentlyBroken.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>

          <p className="mt-4 text-sm text-muted-foreground">
            <Rich text="**One spec deviation:** ethrex's `eth_getLogs` **requires** a `topics` parameter — omitting it returns `Expected parameter: topics is missing`, while geth treats `topics` as optional. Conformant tooling can therefore fail even inside the window ethrex does serve." />
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <Rich text="**What this means for the nginx/Caddy RPC setup this repo ships:** on geth (`--history.chain postmerge`) that endpoint serves post-merge history properly. The same setup on ethrex answers current-state and wallet traffic fine but returns `null`/errors for anything historical — so it is not a drop-in public RPC if your users expect history. If exposing an endpoint is the goal, that's an independent reason to prefer geth or nethermind." />
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <Rich text="**Why this connects to the disk numbers:** this is precisely why ethrex's ~470–476 GiB plateau is not a disk win — the missing ~600 GiB *is* the history the other clients are storing. Footprint tracks what you retain." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="operational-viability" className="text-lg sm:text-xl font-semibold text-foreground">
            Recommendation &amp; operational viability
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="All 12 client pairs installed, checkpoint-synced, and passed Stage A. Disk size converges once ELs carry full post-merge history, so it doesn't separate the field — the real question is durability: will it survive restarts, upgrades, and weeks of uptime? Under that lens the two layers tell opposite stories: the **EL layer carries the operational risk; the CL layer looks solved** on the axes measured here (sync and footprint — only prysm was restart-tested)." />
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
            Execution-layer summary; the consensus layer is covered below. Full reasoning and every caveat follow.
          </p>

          <AnchorHeading id="execution-clients-viability" as="h3" className="mt-6 font-medium text-foreground">
            Execution clients
          </AnchorHeading>
          <ul className="mt-3 space-y-3 text-sm text-muted-foreground">
            <li>
              <Rich text="**There is no disk winner — the field converges.** Every EL with full post-merge history lands at ~1.0–1.2 TiB (geth 1.13, nethermind ~1.06, besu 1.08, reth ~1.1–1.2 projected). Size is set by history-retention config, not client efficiency. If you don't need historical RPC, turn retention down: **Update 2026-08-03** — nethermind now ships **minimal-history by default**, landing at ~250–280 GiB (state only) and staying there. The tradeoff is serving **no history** (pre-sync blocks return `null`, like ethrex; set `NETHERMIND_FULL_HISTORY=true` on a fresh datadir to keep full history for a public RPC). Among no-history configs, nethermind is the smallest — ~250–280 GiB vs ethrex's ~470 GiB — and a floor geth can't reach. It is **not**, however, “4× leaner than geth”: that compares a no-history node to a with-history one, so the win is within the no-history tier only. If you do need history, pick on **snap-sync speed** and **restart-resume stability** instead." />
            </li>
            <li>
              <Rich text="**geth and nethermind both cleared the operational bar** — snap-sync to a validating tip, clean restart-resume, the two most battle-tested codebases here. On disk they're on par (~1.06 vs ~1.13 TiB). Choose **geth** for the conservative default: largest ecosystem, cleanest ~8h28m snap, resumes gracefully after downtime. Choose **nethermind** for client diversity: compact flat-storage state, and restart-resume is directly measured — every gap from 12 min to ~35h resumed by plain block import, no re-snap, no cliff. Run one of these two for the long haul." />
            </li>
            <li>
              <Rich text="**besu is a viable enterprise third.** It synced cleanly to a fully validated head, and its ~1.08 TiB is the same magnitude as geth/nethermind — not an outlier. The catch is operational: its snap sync is **fragile to a prolonged CL outage** (a stalled CL ages the pivot out of the servable-state window, and the sync thread dies — observed twice, unrecoverable). Fine for a shop that keeps its CL current; not a set-and-forget solo-staker pick." />
            </li>
            <li>
              <span className="font-medium text-foreground">The rest each missed the bar for a specific, documented reason — not a blanket “bad client”:</span>
              <ul className="mt-2 space-y-2 pl-4">
                <li>
                  <Rich text="**ethrex** — fastest cold sync in the field (~2h16m), but the restart cliff is a real weakness: a 26-minute downtime gap stalled instead of resuming, and gaps of 1.5–2 hours triggered a full re-snap. Its datadir also **plateaus at ~470–476 GiB** rather than growing unbounded — but that's not a disk win either, since it plateaus low only because it serves no history at all; nethermind's state alone (~226–230 GiB) is smaller still (not a perfectly controlled comparison — different state encodings). Snap speed is a trap if the restart cliff isn't fixed: fast to stand up, painful to operate. Young, fast-moving client (v19.0.0 → v22.0.0 across this campaign) — may improve." />
                </li>
                <li>
                  <Rich text="**reth, nimbus_eth1** — full-sync-only (no snap); can't reach tip in a practical window on this host. This is a time-to-sync limit under our snap-to-tip bar, **not** a verdict on the clients in every context (reth in particular is widely run elsewhere)." />
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
            <Rich text="All five swept CLs (lighthouse, lodestar, grandine, teku, nimbus) checkpoint-synced to a validating head in ~22–23 min with zero crashes. Unlike the EL layer, none of them failed — the choice here is footprint and preference, not survivability:" />
          </p>
          <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
            <li>
              <Rich text="**Recommended: lighthouse** — smallest on the ethrex-anchor sweep (~773 MB; lodestar is actually smaller on the geth and nethermind anchors, down to ~185 MB), checkpoint-syncs in ~22 min, blob pruning on by default. lodestar (~868 MB) and grandine (~946 MB, with `--prune-storage`) are close seconds; teku (~2,161 MB) and nimbus (~5,302 MB) are heavier." />
              <br />
              <span className="font-medium text-foreground">Disk order (the only differentiator):</span>{' '}
              <strong className="text-foreground">
                lighthouse (~773 MB) &lt; lodestar (~868 MB) &lt; grandine (~946 MB) &lt; teku (~2,161 MB)
                &lt; nimbus (~5,302 MB).
              </strong>
            </li>
            <li>
              <Rich text="Two small operational caveats: **teku** needs a generously sized JVM heap on a shared host (undersized, its GC pressure spilled onto co-resident services and poisoned a first run); **grandine** needs `--prune-storage` or it stores every state. **nimbus** is simply the heaviest (~6.9× lighthouse) but otherwise clean." />
            </li>
            <li>
              <Rich text="Cross-cutting CL lesson (learned from prysm, the constant anchor): **keep the CL binary current.** A stale prysm v7.1.5 pin stalled ~28h on a PeerDAS/data-column bug and is precisely what aged out besu's pivot. Binary freshness is an operational requirement, not a nicety." />
            </li>
          </ul>

          <p className="mt-4 text-sm text-muted-foreground">
            <Rich text="**Net:** on the EL side a real long-running node comes down to **geth or nethermind** (besu if you're an enterprise shop that keeps its CL healthy); on the CL side **any of the five works**, with **lighthouse** the lean default. Fast initial sync and small footprints do not by themselves make a client operationally viable — durability across restarts and uptime is the deciding axis, and that's an EL-layer problem." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="gotchas" className="text-lg sm:text-xl font-semibold text-foreground">
            Gotchas &amp; lessons learned
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Every lesson learned across the campaign, grouped by theme. Each bullet leads with its
            verdict; the supporting dates and thresholds follow.
          </p>
          {gotchaGroups.map((group) => (
            <div key={group.id} className="mt-8 first:mt-6">
              <AnchorHeading id={group.id} as="h3" className="font-medium text-foreground">
                {group.title}
              </AnchorHeading>
              <ul className="mt-3 space-y-4 text-sm text-muted-foreground">
                {group.items.map((item, i) => (
                  <li key={i}><Rich text={item} /></li>
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
            Across six weeks and 12 client pairs, disk footprint turned out to be the wrong axis to
            rank this field on — sync speed and restart-resume are the ones that actually separate
            the clients:
          </p>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
            <li>
              <Rich text="**Disk converges, it doesn't rank.** Every EL that carries full post-merge history lands at ~1.0–1.2 TiB (geth 1.13, nethermind ~1.06 full-history, besu 1.08, reth ~1.1–1.2 projected). The two small footprints — nethermind's minimal-history default (~250–280 GiB) and ethrex's ~470–476 GiB plateau — are smaller because they retain no history, not because they're leaner." />
            </li>
            <li>
              <Rich text="**Speed has a real order:** ethrex (~2h16m) &lt; geth (~8h28m) &lt; nethermind (~14.5h) &lt; besu (~19h18m). reth and nimbus_eth1 never reached tip in the 72h cap (full-sync-only), and erigon deadlocked entirely against a checkpoint-synced CL." />
            </li>
            <li>
              <Rich text="**Restart-resume is the deciding axis.** geth and nethermind both resume cleanly from any gap tested (12 min up to ~52h/~35h) by ordinary block import — no re-snap, no cliff. ethrex stalls beyond ~25 minutes/~128 blocks, and measured ~1.5–2h gaps triggered a full re-snap from near-scratch; besu's snap sync deadlocks if a CL outage ages its pivot out of the ~128-block servable-state window." />
            </li>
            <li>
              <Rich text="**Net pick:** geth or nethermind for a long-running node (besu as a qualified enterprise third if you keep the CL current); on the consensus side, any of the five swept CLs works, with lighthouse the lean default. ethrex is the fastest cold sync in the field but its restart cliff and lack of history keep it a watch-don't-deploy pick today." />
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
