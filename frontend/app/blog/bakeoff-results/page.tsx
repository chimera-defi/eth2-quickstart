import type { Metadata } from 'next'
import Link from 'next/link'
import { AnchorHeading } from '@/components/ui/AnchorHeading'
import { ArticleJsonLd } from '@/components/ui/ArticleJsonLd'
import { ArticleToc } from '@/components/ui/ArticleToc'
import { BackToTop } from '@/components/ui/BackToTop'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { ReadNext } from '@/components/ui/ReadNext'
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
  { label: 'Method', href: '#method' },
  { label: 'Stage A results', href: '#stage-a' },
  { label: 'Changes driven by this bake-off', href: '#changes' },
  { label: 'Recommendation (Stage A)', href: '#recommendation' },
  { label: 'Sync-mode & disk-flag audit', href: '#disk-flag-audit' },
  { label: 'Stage B footprint + CL matrix', href: '#stage-b' },
  { label: 'Client limitations', href: '#client-limitations' },
  { label: 'Q&A: does ethrex serve a usable RPC?', href: '#qa-ethrex-rpc' },
  { label: 'Operational viability', href: '#operational-viability' },
  { label: 'Gotchas & lessons learned', href: '#gotchas' },
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
// Changes driven by this bake-off
// ---------------------------------------------------------------------------
const changesDriven = [
  'fix(reth): wire shared JWT + explicit authrpc/datadir for Engine API',
  'fix(reth): enable HTTP-RPC on 127.0.0.1 (eth,net,web3) for monitoring and consumers',
  'fix(nethermind): drop Engine from main JsonRpc.EnabledModules',
  'fix(lodestar): load node options via --rcConfig not --paramsFile',
  'fix(nimbus): checkpoint-sync via trustedNodeSync bootstrap',
  'fix(teku): remove invalid config keys blocking beacon startup',
  'fix(bakeoff): authenticate GitHub release API via gh token to avoid rate limits',
  'fix(bakeoff): bound doctor/stats sampling calls with timeout 30s',
]

// ---------------------------------------------------------------------------
// Recommendation (final campaign synthesis)
// ---------------------------------------------------------------------------
const recommendationPoints = [
  "Execution client: **there is no disk winner — the field converges.** Every EL that carries full post-merge history lands at ~1.0–1.2 TiB (geth 1.13, nethermind ~1.06, besu 1.08, reth ~1.1–1.2 projected); on-disk size is set by history-retention config, a client-agnostic knob, not by client efficiency. So pick on the axes that actually differ: **snap-sync speed** and **restart-resume stability.** **geth** — conservative default, largest ecosystem, cleanest ~8h28m snap, and resumes gracefully after downtime (imports missed blocks, keeps its datadir). **nethermind** — a strong minority-client pick (improves diversity; compact flat-storage state) that resumes cleanly. **ethrex** — fastest cold sync in the field (~2h16m on v19.0.0; a later re-sync took 4h09m56s on v22.0.0 — different ethrex versions and different day/host state, not a regression trend) but a ~25-min restart cliff (longer gaps trigger a full re-snap); its datadir plateaus at ~470 GiB, smaller than the pack only because it retains no history at all — a no-history node, not a pruned-comparable one, so this is not a disk win. besu snap-synced cleanly (~1.08 TiB) but is fragile to a prolonged CL outage; reth and nimbus_eth1 are full-sync-only (multi-day, capped partial here); erigon deadlocked against checkpoint-synced prysm on this host.",
  'Recommended consensus client: **lighthouse** — smallest synced footprint (~739 MB), checkpoint-syncs in ~22 min, blob pruning on by default. lodestar (~827 MB) and grandine (~946 MB, with `--prune-storage`) are close seconds; teku (~2.1 GB) and nimbus (~5.0 GB) are heavier. All five checkpoint-sync in ~22–23 min, so footprint is the differentiator.',
  'Stage-A note: geth, besu, nimbus_eth1, ethrex passed with zero installer changes and zero REST contention — the cleanest out-of-the-box ELs against Prysm.',
]

// ---------------------------------------------------------------------------
// Sync-mode & disk-flag audit (2026-06-25)
// ---------------------------------------------------------------------------
const diskFlagAudit = [
  { el: 'geth', flags: '`--syncmode snap` + `--history.chain postmerge`', status: 'optimal', variant: 'primary' as const, notes: '**Verified ON in the actual 1.13 TiB baseline run** (service-status.txt). Snap-sync + post-merge history prune is the disk floor for geth.' },
  { el: 'besu', flags: '`sync-mode="SNAP"` + `data-storage-format="BONSAI"`', status: 'optimal', variant: 'primary' as const, notes: "Bonsai is Besu's space-efficient flat-DB layout; SNAP avoids full historical execution." },
  { el: 'nethermind', flags: '`SnapSync: true` + `FastBlocks: true`', status: 'optimal', variant: 'primary' as const, notes: 'Snap on; Halite/Paprika flat storage is the modern default.' },
  { el: 'ethrex', flags: '`--syncmode snap`', status: 'optimal', variant: 'primary' as const, notes: 'Snap is the only efficient mode it exposes.' },
  { el: 'erigon', flags: 'OtterSync (default) + `prune.mode: "full"`', status: 'disk-optimal', variant: 'primary' as const, notes: '`prune.mode: full` is the smallest erigon3 footprint. (Separately deadlocks → no-sync; see erigon row.)' },
  { el: 'nimbus_eth1', flags: 'fast-sync (default) + `prune = true`', status: 'online-prune confirmed', variant: 'primary' as const, notes: '`prune = true` (commit `0a1730f`) is now **empirically confirmed to prune online**: across the 2026-07-11→13 72h run the journal logged continuous `Pruning history topics="pruner" tail=1262189 … pruned=N` as it imported blocks — so the flag is **not** inert (this contradicts the "pre-merge history needs a separate era1 export" reading of the docs; the online history-pruner demonstrably runs). At-tip *completeness* vs a full era1 export stays untestable here because the node is full-sync-only and never reached tip inside 72h, but the contested-lever question ("does `prune=true` do anything online?") is answered: **yes.**' },
  { el: 'reth', flags: 'was archive (no flag) → now `--full`', status: 'fixed 2026-06-25', variant: 'default' as const, notes: 'The **only misconfigured EL.** Default reth = archive (~2.8 TiB). `--full` = pruned full node (~1.2 TiB): keeps full block/receipt history, prunes historical state changesets+indices (retains last ~10k blocks). Committed `fix(reth): run pruned full node (--full)`; reth__prysm relaunched.' },
]

// ---------------------------------------------------------------------------
// Final synced disk footprint (Stage B)
// ---------------------------------------------------------------------------
const stageBFootprint = [
  { candidate: 'geth__prysm', result: 'synced', variant: 'primary' as const, syncTime: '~8h28m', footprint: '**1.13 TiB** — geth 1,245,128,582,247 B + prysm 654,985,849 B', notes: 'Baseline. snap-sync EL hands prysm an already-validated head, so there is no large optimistic gap to close. fully_synced=yes, no crash.' },
  { candidate: 'erigon__prysm', result: 'no-sync', variant: 'default' as const, syncTime: 'n/a (terminated)', footprint: '~1.21 TiB* — erigon 1,333,017,755,599 B + prysm 1,646,160,347 B', notes: '*Partial, captured at a near-tip **frozen** head — NOT a clean synced datadir. erigon3 OtterSync + checkpoint-synced prysm deadlock: the EL execution head freezes a few thousand blocks behind tip while the beacon stays `is_optimistic=true`; neither side issues the `forkchoiceUpdated` that would close the >96-block backward-download gap. Raising the CL CPU cap 200%→600% advanced the head ~5k blocks then re-froze — confirming a genuine gap-close deadlock, not resource starvation. Terminated per operator decision (“record no-sync, move on”). See artifact `findings.md`.' },
  { candidate: 'reth__prysm', result: 'capped (72h)', variant: 'default' as const, syncTime: 'n/a', footprint: '~0.98 TiB* — reth 1,064,695,764,125 B + prysm 12,468,756,540 B', notes: '*Partial — window-capped at Execution stage block 11,970,965/25,395,872 (47% by block count, ~21% gas-weighted; ended 2026-06-28T16:53:20Z). reth `--full` is the only no-snap EL; sequential full block execution too slow to finish in 72h under caps. Clean SIGTERM stop (ExecMainStatus=0), no crash, 578 samples. Footprint recovered from `samples.jsonl` last entry (16:52:46Z) — `disk-final.tsv` absent due to harness capped-path gap (fixed commit `af0d77f`). Extrapolation: at ~21% gas-exec already ~87% of geth\'s 1.13 TiB; projected final `--full` footprint ~1.1–1.2 TiB.' },
  { candidate: 'nethermind__prysm', result: 'synced', variant: 'primary' as const, syncTime: '~14.5h (snap)', footprint: '**~1.06 TiB steady-state** (re-measured 2026-08-01: ~1,088 GiB — state ~226–230 GiB compact flat storage + ~843 GiB post-merge bodies/receipts + ~19 GiB headers/code) — **~251 GiB at snap-sync, before FastBlocks backfilled post-merge history** (268,110,243,338 B at that point) + prysm 1,431,145,921 B', notes: 'Snap-synced to head 25,428,620, 49 peers, no crash — compact flat-storage STATE (~226–230 GiB) but full post-merge history backfills to ~1.06 TiB — on par with geth. NOTE: nethermind\'s FIRST attempt was a 13.3h 0-peer loopback stall (P2P pinned to 127.0.0.1, execution head frozen ~block 4,651 while the beacon looked healthy) — the origin of the "triage is blind to a stalled EL" lesson below. After the installer was fixed to advertise a routable `ExternalIp` (commit `676e4da`), the re-run synced cleanly.' },
  { candidate: 'besu__prysm', result: 'synced; pruned re-run abandoned', variant: 'primary' as const, syncTime: '~19h18m', footprint: '**~1.08 TiB** — besu 1,189,836,723,674 B + prysm 1,682,488,084 B', notes: '**besu synced successfully.** The 2026-06-30 run snap-synced cleanly to a fully validating head (~50 peers, prysm `is_optimistic=false` at 2026-07-01T01:37:10Z → ~19h18m, fully_synced=yes) — a working, production-viable node. Its **~1.08 TiB is the same ~1.1 TiB magnitude** as geth (1.13 TiB) and nethermind (~1.06 TiB) once they carry full post-merge history — comparable, not an outlier; geth\'s 1.13 TiB is itself the `--history.chain postmerge` floor, not a pruned-smaller number besu skipped. A follow-up re-run (`history-expiry-prune=true`, 2026-07-04) to see if a further prune lever shrinks it **deadlocked twice and was abandoned** (operator: “Stop; accept limitation note”, 2026-07-05 — see the besu snap-sync deadlock gotcha below; the deadlock trigger was a stale-CL stall, **not** a besu sync failure). besu **did** sync; its open issue is that snap sync is **fragile to a prolonged CL outage**, not its disk size.' },
  { candidate: 'ethrex__prysm', result: 'synced', variant: 'primary' as const, syncTime: '~2h16m (snap, v19.0.0); a later re-sync (steady-state run, v22.0.0) took 4h09m56s', footprint: '**~470–476 GiB steady-state plateau** (drifting 470.2 → 475.5 GiB over ~42 hours at +0.13 GiB/hr) — **~286 GiB at first sync** (306,564,007,339 B, 2026-07-06); **~300 GiB at sync this run** (2026-07-28, 4h09m56s)', notes: 'Snap-synced to a fully validating head in ~2h16m — **fastest EL sync in the field.** 50 peers throughout. 1 automatic stale-pivot update (block 25,469,233→25,469,696) self-healed in ~4 min with no intervention (ethrex clock-based detection, as designed). No crash (service_crash_observed=no, install_exit_code=0). Footprint is un-pruned and **NOT full-history** — ethrex serves ~no history (`eth_getBlockByNumber` returns `null` below head; verified 2026-07-06 and again 2026-07-29). Its datadir **plateaus, it does not grow unbounded**: run `client-bakeoff-ethrex-steadystate-2026-07-28` (NRestarts=0) climbed +43 GiB/hr during post-sync settling (0→465 GiB, 19:02→05:48Z), then growth collapsed ~300× to +0.13 GiB/hr and held a slow drift for ~42 hours (2026-07-29T06:18Z→2026-07-31T00:03Z, 168 samples, 470.2 → 475.5 GiB — RocksDB compaction; `sync_distance=0`, `is_optimistic=false` throughout). The earlier ~467 GiB reading (2026-07-06) was this same plateau caught mid-climb — that run was wiped believing it was still growing, when it was actually within ~1% of where it settles. **Not a disk win:** ethrex is smaller only because it retains no history — a no-history node, not a pruned-comparable one. On a state-only basis it isn\'t even smallest: nethermind\'s state alone is ~226–230 GiB, roughly half ethrex\'s entire ~475 GiB (not a perfectly controlled comparison — ethrex\'s total also includes headers/recent blocks, and the two clients use different state encodings). See client limitations and gotchas for the restart cliff (unchanged) and the no-history RPC cost. First sync ran v19.0.0; the 2026-07-28 steady-state run ran v22.0.0 (`ethrex/v22.0.0-HEAD-aa6c5f04750595…`) — fully_synced=yes, hit_72h_cap=no.' },
]

// ---------------------------------------------------------------------------
// Fresh-sync vs. steady-state disk footprint — several ELs were captured at
// more than one point in their lifecycle; reporting only one number produced
// the two wrong disk claims this page has had to correct (nethermind's
// pre-backfill ~251 GiB read as final; ethrex's mid-climb ~467 GiB read as
// still-growing). Where only one figure was ever captured, that's stated
// explicitly rather than left ambiguous.
// ---------------------------------------------------------------------------
const freshVsSteadyFootprint = [
  { el: 'nethermind', fresh: '~251 GiB (268,110,243,338 B)', steady: '**~1.06 TiB** (re-measured 2026-08-01: ~1,088 GiB — state ~226–230 GiB + ~843 GiB post-merge bodies/receipts + ~19 GiB headers/code)', note: 'Grew after sync as FastBlocks backfilled post-merge history.' },
  { el: 'ethrex', fresh: '~286 GiB (306,564,007,339 B, 2026-07-06 run, v19.0.0); ~300 GiB (this run, 2026-07-28, v22.0.0, at 4h09m56s)', steady: '**~470–476 GiB plateau** (drifts 470.2 → 475.5 GiB over ~42h)', note: '+43 GiB/hr during post-sync settling, then collapsed ~300× to +0.13 GiB/hr, drifting for ~42 hours (2026-07-29T06:18Z→2026-07-31T00:03Z, 168 samples). No-history node — not pruned-comparable to the rows below. The two runs used different ethrex versions (v19.0.0 → v22.0.0) as well as different days/host load.' },
  { el: 'geth', fresh: 'not separately captured', steady: '**1.13 TiB** (1,245,128,582,247 B)', note: '`--history.chain postmerge`.' },
  { el: 'besu', fresh: 'not separately captured', steady: '**1.08 TiB** (1,189,836,723,674 B)', note: '' },
  { el: 'reth', fresh: '—', steady: '~0.98 TiB partial @72h cap (projected ~1.1–1.2 TiB finished)', note: "Full-sync-only; never reaches a moment distinct from its capped steady state." },
]

// ---------------------------------------------------------------------------
// Consensus-client matrix — COMPLETE (anchor = ethrex)
// ---------------------------------------------------------------------------
const clMatrixEthrex = [
  { cl: 'lighthouse', result: 'synced', syncTime: '~22m', footprint: '773,282,157 B (~739 MB) ← smallest', lever: '`checkpoint-sync-url` (blob-prune default)' },
  { cl: 'lodestar', result: 'synced', syncTime: '~22m', footprint: '867,829,601 B (~827 MB)', lever: '`chain.pruneHistory=true`' },
  { cl: 'grandine', result: 'synced', syncTime: '~22m', footprint: '1,343,716,523 B (~946 MB on disk)', lever: '`--prune-storage` (CRITICAL — stores all states without it)' },
  { cl: 'teku', result: 'synced', syncTime: '~22m', footprint: '2,160,709,791 B (~2.1 GB)', lever: '`data-storage-mode=minimal`' },
  { cl: 'nimbus', result: 'synced', syncTime: '~23m', footprint: '5,302,005,871 B (~5.0 GB) ← largest (6.8×)', lever: '`history=prune`' },
]

const clEthrexNotes = [
  "**teku required a re-run.** Its first attempt (pre-`TEKU_CACHE=8192m`) JVM-OOM-starved the shared host, took 64 min to sync, and briefly blipped the anchor → `anchor_synced=no` (recorded, discarded as `env.txt.poisoned-run1`). The re-run with `TEKU_CACHE` raised to 8192m (commit `bf043aa`) synced clean in 22 min with a healthy anchor. Lesson: teku's JVM heap must be sized generously on a shared host or its GC pressure spills onto co-resident services. The valid 2.1 GB row is the re-run.",
  "**All CL footprints are <1% of the ethrex anchor's ~468 GiB (502 GB) EL datadir** → confirms EL/CL decoupling: consensus-client choice does not move the EL disk ranking, and vice-versa.",
]

// ---------------------------------------------------------------------------
// CL matrix — cross-anchor confirmation (anchor = geth)
// ---------------------------------------------------------------------------
const clMatrixGeth = [
  { cl: 'lodestar', result: 'synced', syncTime: '~6m27s', footprint: '185,100,788 B (~177 MiB) ← smallest', lever: '`pruneHistory=true`' },
  { cl: 'lighthouse', result: 'synced', syncTime: '~8m54s', footprint: '542,301,237 B (~518 MiB)', lever: '`checkpoint-sync-url`' },
  { cl: 'grandine', result: 'synced', syncTime: '~8m50s', footprint: '1,074,340,425 B apparent / ~725 MiB actual (sparse DB)', lever: '`prune-storage`' },
  { cl: 'teku', result: 'synced', syncTime: '~8m52s', footprint: '977,108,456 B (~936 MiB)', lever: '`data-storage-mode=minimal`' },
  { cl: 'nimbus', result: 'synced', syncTime: '~7m58s', footprint: '1,198,275,155 B (~1.2 GiB) ← largest', lever: '`history=prune`' },
]

// ---------------------------------------------------------------------------
// CL matrix — second cross-anchor confirmation (anchor = nethermind)
// ---------------------------------------------------------------------------
const clMatrixNethermind = [
  { cl: 'lodestar', result: 'synced', syncTime: '~7m36s', footprint: '186,083,466 B (~178 MiB) ← smallest', lever: '`--chain.pruneHistory`' },
  { cl: 'lighthouse', result: 'synced', syncTime: '~10m07s', footprint: '491,525,193 B (~470 MiB)', lever: '`checkpoint-sync-url`' },
  { cl: 'teku', result: 'synced*', syncTime: '~10m07s', footprint: '875,146,169 B (~848 MiB)', lever: '`data-storage-mode=minimal`' },
  { cl: 'grandine', result: 'synced', syncTime: '~9m58s', footprint: '1,074,340,425 B apparent / ~730 MiB actual (sparse DB)', lever: '`--prune-storage`' },
  { cl: 'nimbus', result: 'synced', syncTime: '~10m13s', footprint: '1,337,611,316 B (~1.3 GiB) ← largest', lever: '`history=prune`' },
]

const clNethermindNotes = [
  "**lodestar's row is a clean re-read, and the discarded first attempt is worth describing.** lodestar's first run on this anchor recorded ~76m14s — not a lodestar property at all: that run started while the anchor EL was still importing a ~2-day block gap (left by an unrelated lodestar crash-loop incident on this host), so lodestar's beacon could not report `is_optimistic=false` until the EL closed that gap. Once the anchor was back at head and the crash-loop's root cause was fixed, lodestar was re-measured from scratch: **~7m36s and 186,083,466 B (~178 MiB)** — in line with the other four CLs, and within ~1 MiB of lodestar's geth-anchor footprint (~177 MiB). The published row is the re-read; the superseded run is retained in the artifacts for provenance. That gapped run had itself recorded **259,578,455 B (~248 MiB)** — ~40% above the clean re-read, another reason not to carry it forward.",
    "**teku finalized `anchor_synced=no` on both of its runs — a reproducible watchdog false positive, not an anchor problem.** The full sample sequence of the re-read shows why: at 18:14:13Z the anchor was 56 blocks behind (`currentBlock=0x18720c3` vs `highestBlock=0x18720fb`), and at 18:16:51Z **both sides** were transiently behind — the anchor by 21 blocks and teku itself at `sync_distance=49, is_syncing=true`. From 18:19:30Z onward every sample is clean on both sides (`eth_syncing=false`, `sync_distance=0`, `is_optimistic=false`), including at teku's own `synced_at_utc` of 18:22:08Z. So the anchor was healthy when the measurement was taken; the watchdog had already latched on the warm-up samples and never re-evaluated. The cause is teku's slow JVM warm-up: it leaves the anchor briefly undriven, the anchor's head lags, and the watchdog's two-consecutive-sample rule trips. That it reproduced on a deliberate clean re-read is what makes it a known harness limitation rather than a fluke — the watchdog should tolerate a bounded head lag, or only sample once the CL reports synced. Both runs' footprints are valid; the published row is the re-read (~848 MiB, against ~667 MiB on the first run).",
  '**grandine sparse DB, again:** apparent `du -sb` (1,074,340,425 B) overstates real on-disk usage; actual on-disk usage is **~730 MiB**, the fair number for ranking — the same caveat as the geth-anchor row above.',
]

const crossAnchorVerdict = [
  '**nimbus is the largest CL on all three anchors** — the one ranking that holds without exception.',
  '**{lodestar, lighthouse} are the two smallest CLs on all three anchors**, but which one is smallest is measurement-window-sensitive: lighthouse is smallest on the ethrex anchor; lodestar is smallest on both the geth and nethermind anchors.',
  '**{teku, grandine} form a "mid" tier, and teku shows how soft within-tier ordering really is.** teku was measured twice on this same anchor and moved ~27%: ~667 MiB on the first run, **~848 MiB on a deliberate clean re-read** — enough to flip it from below grandine (~730 MiB) to above it. Taking the re-read as authoritative, grandine < teku holds on all three anchors; but the honest reading is that this pair\'s internal order is measurement-window-sensitive rather than a stable property.',
  '**Absolute footprints scale with observation time, not just the EL anchor.** The geth- and nethermind-anchor numbers are much smaller than the ethrex-anchor ones (e.g. nimbus ~1.2–1.3 GiB vs ~5.0 GB) because those sweeps were measured minutes after checkpoint-sync (a fresh datadir), while the ethrex-anchor runs ran longer post-sync and had filled more of the blob-retention / state-history window. The tiers are anchor-independent here; exact within-tier order is measurement-window-sensitive.',
  '**Net:** three different EL anchors (ethrex, geth, nethermind) reproduce the same three tiers — lightweight {lodestar, lighthouse}, mid {teku, grandine}, heavy {nimbus} — empirically supporting EL/CL decoupling, **without** claiming an identical total order across anchors.',
  "**grandine's byte-identical apparent size (1,074,340,425 B) on both the geth-anchor and nethermind-anchor runs is real, not a copy/paste** — it's grandine's fixed ~1 GiB sparse pre-allocation plus deterministic metadata; the actual allocated sizes (~725 MiB vs ~730 MiB) differ as expected.",
]

const measurementNotes = [
  '**grandine uses sparse DB files** → its apparent `du -sb` byte count (1,074,340,425 B) overstates real on-disk usage. `du -sh` reports **~725 MiB actual**, which is the fair number for ranking. The other four CLs had apparent ≈ actual.',
  "**Harness fix `98a52d7` (belongs in PR #190):** `bakeoff_snapshot_disk` guarded its `du | awk` pipeline with `|| true`. Without it, when the live anchor EL churned its datadir during a snapshot, `du` hit a vanishing file → exit 1 → `pipefail` killed the run (this spuriously failed grandine's first attempt; the clean re-run above is authoritative).",
]

// ---------------------------------------------------------------------------
// Client limitations
// ---------------------------------------------------------------------------
const clientLimitations = [
  { el: 'besu', footprint: '~1.08 TiB', synced: 'yes', syncedDetail: '(~19h18m, fully validated)', why: 'besu **synced fine**, and its ~1.08 TiB is the same magnitude as geth/nethermind at full post-merge history — comparable, not an outlier. It\'s listed here for its operational caveat, not its disk size: a follow-up re-run to test a further prune lever deadlocked twice and was abandoned (stale-pivot → `SnapSyncChainDownloader` thread death; root-caused to a ~28h prysm-v7.1.5 CL stall, **not** a besu fault — see gotcha below), underscoring that besu\'s snap sync is fragile to a prolonged CL outage.' },
  { el: 'reth', footprint: '~0.98 TiB partial (72h-capped)', synced: 'partial', syncedDetail: '', why: '`--full`-only (no snap); sequential full block execution can\'t finish mainnet inside the 72h cap. Speed-bound, not config-bound.' },
  { el: 'nimbus_eth1', footprint: '**~40 GB partial @72h cap** (2026-07-13; supersedes an earlier ~21 GB aborted run)', synced: 'partial', syncedDetail: '(~21.6%)', why: 'Full-sync-only (no snap). The 72h governance-cap run (2026-07-11→13, run_id `client-bakeoff-nimbuseth1-2026-07-11`) ran **72h continuously with 0 restarts** (stable throughout, 20–25 peers) and reached **~21.6%** — head 5,509,858 / target 25,505,378, eta ~1w3d still remaining — so it never neared tip. **New, measured this run:** `prune = true` is **empirically confirmed pruning online** (journal `Pruning history … pruned=N` logged continuously during import), which **resolves the earlier "contested / era1-only / unverified" open question** — the lever is NOT inert. It\'s listed here only because a full-sync-only client can\'t reach tip in a practical window on this host, **not** because the prune lever fails.' },
  { el: 'erigon', footprint: '~1.21 TiB frozen partial', synced: 'no', syncedDetail: '', why: 'Structural no-sync: erigon3 OtterSync + checkpoint-synced-prysm optimistic gap-close deadlock. Not a synced datadir.' },
  { el: 'ethrex', footprint: '~286–300 GiB at sync (fresh) → **~470–476 GiB steady-state plateau** (drifting 470.2 → 475.5 GiB over ~42h)', synced: 'yes', syncedDetail: '(~2h16m on v19.0.0, fully validated; a later re-sync on v22.0.0 took 4h09m56s — different day/host load too, not a regression)', why: 'ethrex **synced cleanly and fastest in the field (~2h16m snap).** No history-prune lever (`--syncmode snap` only; no state-prune flag) — moot, since it retains no history to prune. It serves ~no history (`eth_getBlockByNumber` `null` below head, verified 2026-07-06 and 2026-07-29) and its datadir **plateaus rather than growing unbounded**: +43 GiB/hr while post-sync settling, then a ~300× collapse to +0.13 GiB/hr, drifting for ~42 hours (2026-07-29T06:18Z→2026-07-31T00:03Z, 168 samples, run `client-bakeoff-ethrex-steadystate-2026-07-28`, NRestarts=0). The earlier ~467 GiB (2026-07-06) was this same plateau caught mid-climb, ~1% below the settled figure — not evidence of unbounded growth. **Not a disk win:** it\'s smaller only because it\'s a no-history node; nethermind\'s state alone (~226–230 GiB) is roughly half ethrex\'s entire total on a state-only basis (caveat: not a perfectly controlled comparison — different state encodings, and ethrex\'s total includes headers/recent blocks). config_optimal=yes (snap is optimal-by-absence; 1 stale-pivot auto-healed). service_crash_observed=no. See gotchas for the restart cliff (unchanged) and the no-history RPC cost.' },
]

// ---------------------------------------------------------------------------
// Gotchas & lessons learned
// ---------------------------------------------------------------------------
const gotchas = [
  '**Stage-A triage is blind to a stalled EL.** Triage only checks that the CL reaches tip and the Engine-API JWT handshake works. A node whose CL checkpoint-syncs optimistically PASSES triage even with 0 EL peers and a frozen execution head (nethermind hid a 13.3h zero-progress stall this way). A sync-health verdict must combine peer-count>0 + EL-head advancing + beacon `sync_distance` — never `sync_distance` alone.',
  '**`eth_syncing=false` is a trap, not a done-signal.** It returns `false` BOTH before snap-sync starts (no pivot yet) and after it finishes. The authoritative "synced" gate is prysm `is_optimistic=false` (EL validated the head payload). besu\'s `eth_syncing` also returns `false` mid-sync — same trap.',
  '**A synced nethermind\'s `eth_syncing` returns an OBJECT, not boolean false** (`currentBlock==highestBlock`). The bakeoff harness now treats the EL as synced on `currentBlock==highestBlock`, not only boolean `false` (commit `5e7a93d`).',
  "**besu snap sync is two tracks:** block-import reaches head first (a premature “done” signal), but world-state download/heal (Bonsai) is the real bottleneck and where the footprint balloons.",
  '**besu snap-sync deadlocks if the CL stalls long enough (stability finding, 2026-07-05).** The besu pruned re-run deadlocked **twice** and was abandoned. Chain: a **prysm v7.1.5** data-column-sidecar/PeerDAS bug stalled the CL ~28h (besu logged `Execution engine not called in 120 seconds` continuously) → with no `forkchoiceUpdated` driving it, besu\'s snap-sync **pivot block aged out** of the network\'s servable-state window (full nodes serve state for only ~128 recent blocks ≈ 25 min) → world-state heal became un-completable → besu threw `java.lang.IllegalStateException: The pivot block number has not increased` in `SnapSyncChainDownloader.consumePivotUpdate`, cancelled the download, and the downloader **thread died without restarting**. The process stayed alive and answered RPC while the sync engine was dead (datadir frozen, zero DB writes). A restart resumed on the SAME persisted stale pivot and re-deadlocked identically. **Takeaways:** keep the CL binary current before a long besu snap-sync (the stall came from a stale prysm pin); besu answering `eth_blockNumber` ≠ besu syncing (watch DB writes); and this is the prime motivation for the harness stall-watchdog — **now implemented** (#31, PR #190) as an opt-in watchdog: with `ETH2QS_BAKEOFF_STALL_RESTART=yes`, if the unit under test makes no forward progress (EL block number / CL `head_slot` flat) for `ETH2QS_BAKEOFF_STALL_SAMPLES` polls (default 10) it performs up to `ETH2QS_BAKEOFF_STALL_MAX_RESTARTS` bounded restarts (default 3) of *only that unit*, then marks the row `.stalled` and fails it instead of spinning to the 72h cap.',
  "**ethrex restart cliff begins beyond ~25 min; longer measured gaps re-snap from scratch (operational cliff, v19.0.0).** A routine restart with a ~1.5–2h gap made ethrex **discard its fully-synced 286 GiB state and start a fresh snap sync from near-genesis** (datadir collapsed 286 GiB → ~9 GiB → climbing; journal `SNAP SYNC STARTED` → `PHASE 1/8: BLOCK HEADERS` from ~198k/25.47M; `eth_blockNumber`=`0x0` throughout). Root cause: after the gap ethrex's old head aged out of the network's ~128-block (~25 min) servable-state window, so when prysm drove `forkchoiceUpdated` to the current head, ethrex re-pivoted to a full snap rather than importing the missed gap — contrast **geth**, which resumes by importing the missed blocks and keeps its state. Two measured re-sync costs: **~2h16m (cold) + ~2h11m (post-downtime re-snap)**; the re-snapped datadir then rebuilt *past* the old 286 GiB. **Blog through-line:** a client that stops resuming beyond ~25 minutes and can full-re-sync on longer gaps is operationally painful — a strong candidate explanation for ethrex's ~0% adoption despite the field's fastest cold sync. **Threshold precisely bracketed (2026-07-10 restart bisection).** Controlled `systemctl stop eth1` → wait → `start` runs with a live prysm driving forkchoice: gaps of **12 min / 68 blk, 20 min / 108 blk, and 23 min / 124 blk all resumed cleanly** (ethrex imported the missed blocks, datadir intact, canonical head climbed back to tip), while a **26 min / 132 blk gap stuck** — the canonical head froze (`eth_blockNumber` flat at the pre-stop block for 12+ min, `eth_syncing.currentBlock=0x0`), ethrex logged `FCU head state not reachable from DB state … Starting sync toward head` and `Failed to fetch headers for sync head — peer(s) queried but did not serve headers`, and the gap widened as the tip advanced (no datadir collapse *within* the 12-min watch — the stuck disconnected-head state is the onset that escalates to the full snap re-sync at larger gaps). So the cliff edge is **~128 blocks ≈ 24–25 min**, matching the ~128-block servable window exactly: inside it peers still serve the gap headers and ethrex bridges; beyond it they don't, the head freezes, and the ~1.5–2h gap above drove the full datadir-collapse re-snap. Caveat: young client (v19.0.0, may improve); this does **not** change the recorded sync-time result (2h16m, captured at synced time).",
  '**geth resumes gracefully after a ~52h (multi-day) downtime — measured 2026-07-10 (the positive contrast to ethrex).** Restarted after a stop that had left it ~15,400 blocks / ~52h behind (`eth_syncing.startingBlock`=25,487,154 — *not* genesis, no snap-pivot reset), geth **kept its full multi-hundred-GB datadir** and caught up purely by **sequential block-import with trie-diff application** — journal `Imported new chain segment … triediffs=… triedirty=…` on every segment, *not* a re-snap. Throughout: no datadir collapse (contrast ethrex\'s 286 GiB → ~9 GiB), `eth_syncing` returned an import object (never `0x0`), state healing ran to completion (`healingTrienodes=0x0`), and it **converged back to the validating tip** (`eth_syncing=false` at block 25,502,592). This is the resume profile you want for an EL you upgrade/restart regularly, and it is *why* geth clears the operational bar above where ethrex\'s re-snap cliff does not. (Wall-clock resume time not cleanly bounded on this shared host, so only the mechanism + datadir preservation are claimed.)',
  '**ethrex serves no history beyond its snap-sync pivot — measured live 2026-07-29, to single-block precision.** Probing the live node (head ~25,639,228) against its snap pivot (block 25,634,445): `eth_getBlockByNumber` returns `null` at pivot−1 (25,634,444) but resolves cleanly at pivot+0 and pivot+200 — the servable window\'s back edge is *exactly* the pivot, not an approximation. That window held only 4,783 blocks (~16h of chain) at measurement time; it grows forward as new blocks arrive but never backfills — deep probes at blocks 1, 1,000,000, 21,600,000, and the merge block (15,537,394) all returned `null`. State is an even tighter window: `eth_call` succeeds at head−100 but fails at head−500 with `Vm execution error: DB error: state root missing for block N` — historical state is available for only the last ~128 blocks (~25 min), the same servable-state window that drives the restart cliff above. **What this costs the RPC-endpoint feature this repo ships (nginx/Caddy in front of the client):** current-state reads work fine on ethrex — `eth_chainId`, `eth_gasPrice`, `eth_getBalance`/`eth_getTransactionCount` @ latest, `eth_call` @ latest, and blocks/receipts/logs at or after the pivot all resolve (615 logs returned over a 2-block USDC range at head−1000), so wallet-style traffic (balances, current quotes, allowances) is fine. But any block/log/receipt before the pivot fails (`Internal Error: Could not get body for block N`) — effectively all of Ethereum history — breaking indexer/subgraph backfill, portfolio history, and tax/accounting exports. A geth endpoint with `--history.chain postmerge` serves that same history; ethrex does not, so it is not a drop-in replacement for a public DeFi-facing RPC. One more spec deviation inside the served window: ethrex\'s `eth_getLogs` **requires** `topics` (`Expected parameter: topics is missing`), where geth treats it as optional — conformant tooling that omits `topics` can break even on blocks ethrex does serve.',
  '**Client distribution is a WEAK/NUANCED predictor of syncability.** The tempting story — low/zero-share clients all struggle — is only half true. erigon (deadlock), reth & nimbus_eth1 (full-sync-only, can\'t finish in 72h) did struggle, but **ethrex (~0% share, Lambda Class) synced FASTEST in the whole field (~2h16m).** The real driver is **snap-sync availability + client robustness** (ethrex has both: snap + clock-based stale-pivot self-healing), not market share per se. Don\'t overclaim the correlation in the blog — ethrex\'s steady-state footprint (now measured: a ~470 GiB plateau) isn\'t a disk win, since it\'s a no-history node; speed remains its clean, settled claim.',
  '**Loopback-P2P class of bug.** besu AND nethermind both defaulted P2P advertising to `127.0.0.1` → degraded/zero peering. Fixed (remove loopback `p2p-host` / inject routable `ExternalIp`). geth/erigon/reth/ethrex/nimbus_eth1 bind externally by default.',
  "**erigon3 OtterSync + checkpoint-synced prysm deadlock** — the one structural no-sync (see the erigon row): EL head freezes behind tip while the beacon stays optimistic; neither issues the `forkchoiceUpdated` that would close the gap. Raising CPU caps advanced it ~5k blocks then re-froze.",
  "**reth is `--full`-only here** (archive was the disk-hostile default; switched to `--full`); sequential full block execution can't finish a mainnet sync inside the 72h cap.",
  '**Sampler timestamp skew (~2h):** samples label local CEST times as `Z`. Trust file mtime for wall-clock, not the sample\'s `timestamp_utc` string.',
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
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            Bake-off results — the raw data
          </h1>
          <p className="mt-3 text-sm italic text-muted-foreground">
            <Rich text="Stage A (triage) synthesized from `artifacts/client-bakeoff-2026-06-22/` on 2026-06-23. Raw artifacts are gitignored; this doc is the committed summary." />
          </p>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            This page renders{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">
              docs/CLIENT_BAKEOFF_RESULTS.md
            </code>{' '}
            verbatim: every Stage A triage row, every Stage B disk-footprint measurement, the
            consensus-client matrix on three anchors, the client-limitations table, and every gotcha
            — unrounded, unreordered, straight from the committed doc. For the narrative write-up,
            see{' '}
            <Link href="/blog/ethereum-client-bakeoff" className="text-primary hover:underline">
              the bake-off blog post
            </Link>
            .
          </p>
          <div className="mt-4 flex flex-wrap gap-3 sm:mt-6">
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

        <ArticleToc links={tocLinks} />

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="method" className="text-lg sm:text-xl font-semibold text-foreground">Method</AnchorHeading>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">Baseline-anchored coverage (12 candidates):</span>{' '}
              every execution client vs fixed Prysm (7 ELs), plus every other consensus client vs
              a fixed execution anchor (5 CLs). This isolates each client against a known-good counterpart
              instead of testing every N×M pair.
              <ul className="mt-2 space-y-1.5 pl-4">
                <li>ELs × prysm: geth, erigon, reth, nethermind, besu, nimbus_eth1, ethrex</li>
                <li>
                  <Rich text="CLs × fixed anchor EL: lighthouse, teku, nimbus, lodestar, grandine. The first sweep used **ethrex**, already synced at tip. The originally planned geth sweep was initially deferred, then completed on 2026-07-08 as a cross-anchor check, and a third sweep against a **nethermind** anchor followed on 2026-07-26. Across all three anchors the same three tiers reproduce — lightweight {lodestar, lighthouse}, mid {teku, grandine}, heavy {nimbus} — while the order within each pair is measurement-window-sensitive (lodestar↔lighthouse between ethrex and geth; on the nethermind anchor, teku itself moved ~27% across two runs — ~667 MiB → ~848 MiB — enough to cross grandine's ~730 MiB; grandine < teku holds on all three anchors, so this is teku's own re-read variance, not a genuine swap with grandine)." />
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
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16">
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
            Resource contention (shared semi-prod host)
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="Heavier-client startups (non-geth ELs, and lodestar) showed Prysm's beacon REST briefly unavailable for the first 1–3 minutes (`restErr` counts above) before recovering — consistent with startup contending for CPU/IO against co-resident agents on this shared host. It did **not** block any checkpoint sync, but it is the headline risk for Stage B: a multi-day, IO-heavy full sync will compete with co-resident workloads. Stage B execution strategy (sequential vs. small parallel batches) must account for this." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="changes" className="text-lg sm:text-xl font-semibold text-foreground">
            Changes driven by this bake-off
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Installer/harness fixes landed on the bake-off branch as a direct result of triage:
          </p>
          <ul className="mt-4 space-y-2 text-sm">
            {changesDriven.map((commit) => (
              <li key={commit}>
                <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs text-foreground">{commit}</code>
              </li>
            ))}
          </ul>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="recommendation" className="text-lg sm:text-xl font-semibold text-foreground">
            Recommendation (final campaign synthesis)
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="Stage A established **viability**: all 12 client pairs installed, checkpoint-synced, and authenticated the Engine API on this host. The recommendations below incorporate the completed Stage B footprint, sync-time, and restart-resilience results." />
          </p>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
            {recommendationPoints.map((point, i) => (
              <li key={i}><Rich text={point} /></li>
            ))}
          </ul>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="disk-flag-audit" className="text-lg sm:text-xl font-semibold text-foreground">
            Sync-mode &amp; disk-flag audit (2026-06-25)
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="Before letting the slow full-sync ELs run, we audited every execution client to confirm it uses the most disk- and time-efficient sync mode available — so the Stage B footprint numbers reflect each client's *best* configuration, not an accidental archive run. Trigger: geth's `--history.chain postmerge` flag (prunes pre-merge block history, a large disk saving). We verified it was on for the baseline, then checked the rest." />
          </p>

          <div
            className="mt-4 overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
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

          <p className="mt-4 text-sm text-muted-foreground">
            <Rich text="**Net effect:** all seven ELs now run their disk-optimal sync mode. Six were already correct out of the box; reth was archive-by-default and is the one change this audit produced. Footprint comparisons across ELs are therefore apples-to-apples on configuration (the snap-vs-full *time* asterisk from the method section still applies — full-sync ELs execute all ~25M blocks, so time-to-sync is not comparable to geth's snap baseline, but final footprint is)." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="stage-b" className="text-lg sm:text-xl font-semibold text-foreground">
            Final synced disk footprint (Stage B)
          </AnchorHeading>
          <p className="mt-2 text-sm italic text-muted-foreground">
            <Rich text="Complete (run_id `client-bakeoff-stageB-2026-06-23`). Runs were sequential, one candidate at a time; every candidate now has a final synced, capped, or no-sync verdict. Footprint = final synced datadir size (EL + CL); secrets/validator material excluded." />
          </p>

          <div
            className="mt-4 overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
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

          <AnchorHeading id="fresh-vs-steady-state" as="h3" className="mt-10 font-medium text-foreground">
            Fresh-sync vs. steady-state disk footprint
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="Several ELs were captured at more than one point in their lifecycle, and reporting only one number produced the two wrong disk claims this page has had to correct so far (nethermind's pre-backfill ~251 GiB read as final; ethrex's mid-climb ~467 GiB read as still-growing). Where both a fresh (at-sync) and a steady-state (settled) figure exist, both are recorded below; where only one was ever captured, that's stated explicitly rather than left ambiguous." />
          </p>
          <div
            className="mt-4 overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
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
          <AnchorHeading id="cl-matrix-ethrex-anchor" as="h3" className="mt-10 font-medium text-foreground">
            Consensus-client matrix — COMPLETE (anchor = ethrex, run_id{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">client-bakeoff-clsweep-2026-07-06</code>)
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="The CL matrix holds the **execution client constant** and cycles the consensus client, the mirror of the EL scorecard above. The constant anchor is **ethrex** (not geth as first planned): ethrex was already synced at mainnet tip from its EL run, so reusing it as the fixed anchor saved a multi-day re-sync. Because the EL and CL are decoupled across the Engine API (the CL datadir is <1% of the EL and does not depend on which EL it pairs with), the anchor choice does **not** bias the CL comparison. To *prove* that empirically rather than assert it, the full 5-CL sweep was subsequently re-run against a **geth** anchor (2026-07-08, run_id `client-bakeoff-anchor-rotation-2026-07-07`) — the cross-anchor confirmation is recorded below and reproduces the ranking. The ethrex anchor stayed active and `eth_syncing=false` (~468 GiB / 502 GB, never restarted) across all five runs; each run cycled only `cl`+`validator`." />
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <Rich text="All five CLs **checkpoint-synced to a fully validating head in ~22–23 min**, `config_optimal=yes`, `anchor_synced=yes`, `service_crash_observed=no`. Sync **time** is effectively tied (checkpoint sync dominates), so **the CL datadir footprint is the differentiator.**" />
          </p>

          <div
            className="mt-4 sm:mt-6 hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
            role="region"
            aria-label="Consensus client matrix, ethrex anchor"
            tabIndex={0}
          >
            <table className="w-full min-w-[42rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">CL</th>
                  <th className="pb-3 font-medium text-muted-foreground">Result</th>
                  <th className="pb-3 font-medium text-muted-foreground">Sync time</th>
                  <th className="pb-3 font-medium text-muted-foreground">CL datadir footprint</th>
                  <th className="pb-3 font-medium text-muted-foreground">Disk-optimal lever</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {clMatrixEthrex.map((row) => (
                  <tr key={row.cl}>
                    <td className="py-3 align-top font-medium text-foreground">{row.cl}</td>
                    <td className="py-3 align-top"><Badge variant="primary">{row.result}</Badge></td>
                    <td className="py-3 align-top text-muted-foreground">{row.syncTime}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.footprint}</td>
                    <td className="py-3 align-top text-muted-foreground"><Rich text={row.lever} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {clMatrixEthrex.map((row) => (
              <div key={row.cl} className="rounded-lg border border-border p-3">
                <div className="flex items-center justify-between gap-3">
                  <span className="font-medium text-foreground">{row.cl}</span>
                  <Badge variant="primary">{row.result}</Badge>
                </div>
                <dl className="mt-3 space-y-2 text-sm">
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Sync time</dt>
                    <dd className="text-right text-foreground">{row.syncTime}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Footprint</dt>
                    <dd className="text-right text-foreground">{row.footprint}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Disk-optimal lever</dt>
                    <dd className="text-right text-foreground"><Rich text={row.lever} /></dd>
                  </div>
                </dl>
              </div>
            ))}
          </div>

          <p className="mt-4 text-sm text-foreground">
            <strong>
              CL disk ranking (smaller = better, all config-optimal + checkpoint-synced): lighthouse
              (~739 MB) &lt; lodestar (~827 MB) &lt; grandine (~946 MB) &lt; teku (~2.1 GB) &lt; nimbus
              (~5.0 GB).
            </strong>
          </p>
          <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
            {clEthrexNotes.map((note, i) => (
              <li key={i}><Rich text={note} /></li>
            ))}
          </ul>

          {/* -------------------------------------------------------------- */}
          <AnchorHeading id="cl-matrix-geth-anchor" as="h3" className="mt-10 font-medium text-foreground">
            CL matrix — cross-anchor confirmation (anchor = geth, run_id{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">client-bakeoff-anchor-rotation-2026-07-07</code>
            , 2026-07-08)
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="The same 5-CL sweep was re-run against a **geth** anchor to verify the ranking is not an artifact of the ethrex anchor. All five runs were `config_optimal=yes`, `anchor_synced=yes`, no service crash; each cycled only `cl`+`validator` against the preserved geth EL datadir (~1.13 TiB, never wiped)." />
          </p>

          <div
            className="mt-4 sm:mt-6 hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
            role="region"
            aria-label="Consensus client matrix, geth anchor (cross-anchor confirmation)"
            tabIndex={0}
          >
            <table className="w-full min-w-[42rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">Consensus</th>
                  <th className="pb-3 font-medium text-muted-foreground">Sync status</th>
                  <th className="pb-3 font-medium text-muted-foreground">Sync time</th>
                  <th className="pb-3 font-medium text-muted-foreground">Final CL datadir</th>
                  <th className="pb-3 font-medium text-muted-foreground">History-prune lever</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {clMatrixGeth.map((row) => (
                  <tr key={row.cl}>
                    <td className="py-3 align-top font-medium text-foreground">{row.cl}</td>
                    <td className="py-3 align-top"><Badge variant="primary">{row.result}</Badge></td>
                    <td className="py-3 align-top text-muted-foreground">{row.syncTime}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.footprint}</td>
                    <td className="py-3 align-top text-muted-foreground"><Rich text={row.lever} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {clMatrixGeth.map((row) => (
              <div key={row.cl} className="rounded-lg border border-border p-3">
                <div className="flex items-center justify-between gap-3">
                  <span className="font-medium text-foreground">{row.cl}</span>
                  <Badge variant="primary">{row.result}</Badge>
                </div>
                <dl className="mt-3 space-y-2 text-sm">
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Sync time</dt>
                    <dd className="text-right text-foreground">{row.syncTime}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Final CL datadir</dt>
                    <dd className="text-right text-foreground">{row.footprint}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">History-prune lever</dt>
                    <dd className="text-right text-foreground"><Rich text={row.lever} /></dd>
                  </div>
                </dl>
              </div>
            ))}
          </div>

          <p className="mt-4 text-sm text-foreground">
            <strong>
              geth-anchor CL disk ranking (actual disk, smaller = better): lodestar (~177 MiB) &lt;
              lighthouse (~518 MiB) &lt; grandine (~725 MiB actual) &lt; teku (~936 MiB) &lt; nimbus
              (~1.2 GiB).
            </strong>
          </p>

          {/* -------------------------------------------------------------- */}
          <AnchorHeading id="cl-matrix-nethermind-anchor" as="h3" className="mt-10 font-medium text-foreground">
            CL matrix — second cross-anchor confirmation (anchor = nethermind, run_id{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">client-bakeoff-anchor-nethermind-2026-07-26b</code>
            , 2026-07-26)
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="A third run of the same 5-CL sweep was performed against a **nethermind** anchor (nethermind 1.39.2, the same instance recorded in the Stage B row above) to further stress-test the EL/CL decoupling claim beyond the ethrex↔geth check. The anchor EL was brought current to mainnet tip in ~2h04m before this sweep began — a catch-up, not a re-sync; its datadir was preserved untouched — and stayed at tip across all five runs; each run cycled only `cl`+`validator`. All five: `fully_synced=yes`, `config_optimal=yes`, `service_crash_observed=no`." />
          </p>

          <div
            className="mt-4 sm:mt-6 hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
            role="region"
            aria-label="Consensus client matrix, nethermind anchor (second cross-anchor confirmation)"
            tabIndex={0}
          >
            <table className="w-full min-w-[42rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">Consensus</th>
                  <th className="pb-3 font-medium text-muted-foreground">Sync status</th>
                  <th className="pb-3 font-medium text-muted-foreground">Sync time</th>
                  <th className="pb-3 font-medium text-muted-foreground">Final CL datadir</th>
                  <th className="pb-3 font-medium text-muted-foreground">History-prune lever</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {clMatrixNethermind.map((row) => (
                  <tr key={row.cl}>
                    <td className="py-3 align-top font-medium text-foreground">{row.cl}</td>
                    <td className="py-3 align-top"><Badge variant="primary">{row.result}</Badge></td>
                    <td className="py-3 align-top text-muted-foreground">{row.syncTime}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.footprint}</td>
                    <td className="py-3 align-top text-muted-foreground"><Rich text={row.lever} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {clMatrixNethermind.map((row) => (
              <div key={row.cl} className="rounded-lg border border-border p-3">
                <div className="flex items-center justify-between gap-3">
                  <span className="font-medium text-foreground">{row.cl}</span>
                  <Badge variant="primary">{row.result}</Badge>
                </div>
                <dl className="mt-3 space-y-2 text-sm">
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Sync time</dt>
                    <dd className="text-right text-foreground">{row.syncTime}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Final CL datadir</dt>
                    <dd className="text-right text-foreground">{row.footprint}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">History-prune lever</dt>
                    <dd className="text-right text-foreground"><Rich text={row.lever} /></dd>
                  </div>
                </dl>
              </div>
            ))}
          </div>

          <p className="mt-4 text-sm text-foreground">
            <strong>
              nethermind-anchor CL disk ranking (actual disk, smaller = better): lodestar (~178
              MiB) &lt; lighthouse (~470 MiB) &lt; grandine (~730 MiB actual) &lt; teku (~848 MiB)
              &lt; nimbus (~1.3 GiB).
            </strong>
          </p>
          <p className="mt-4 text-sm font-medium text-foreground">Caveats (mandatory — accuracy over a clean story):</p>
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground">
            {clNethermindNotes.map((note, i) => (
              <li key={i}><Rich text={note} /></li>
            ))}
          </ul>

          <p className="mt-4 text-sm font-medium text-foreground">Cross-anchor verdict — the tiers reproduce, not an identical order (now three anchors: ethrex, geth, nethermind):</p>
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground">
            {crossAnchorVerdict.map((point, i) => (
              <li key={i}><Rich text={point} /></li>
            ))}
          </ul>

          <p className="mt-4 text-sm font-medium text-foreground">Measurement notes:</p>
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground">
            {measurementNotes.map((note, i) => (
              <li key={i}><Rich text={note} /></li>
            ))}
          </ul>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="client-limitations" className="text-lg sm:text-xl font-semibold text-foreground">
            Client limitations — why each candidate falls outside a clean, finished comparison
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="At full post-merge history the ELs converge on disk (~1.0–1.2 TiB: geth 1.13, nethermind ~1.06, besu 1.08, reth ~1.1–1.2 projected), so there is no meaningful on-disk ranking to draw — size is config-determined. The clients are separated below on the axes that actually differ: sync speed and restart-resume behavior. **This table does not mean “failed to sync”** — besu in particular synced cleanly (see below); it's here because it hit an operational limitation (fragile to a CL outage) or, for reth/nimbus_eth1/erigon, never reached a finished, tip-synced datadir." />
          </p>

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
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="qa-ethrex-rpc" className="text-lg sm:text-xl font-semibold text-foreground">
            Reader Q&amp;A: does ethrex serve a usable RPC?
          </AnchorHeading>
          <p className="mt-2 text-sm italic text-muted-foreground">
            <Rich text="Everything below was measured live on 2026-07-29/30 against our own synced ethrex node (`ethrex/v22.0.0-HEAD-aa6c5f04750595…`), across several probes taken at different moments as the head advanced." />
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
            The deploy-today test (the decisive one)
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
            A second, much tighter limit — historical state
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="`eth_call` succeeds at head−100 but fails at head−500 with `Vm execution error: DB error: state root missing for block N`. So historical state is roughly the last ~128 blocks (~25 minutes). “What was this balance at block X” does not work." />
          </p>

          <p className="mt-4 text-sm font-medium text-foreground">Consequently broken:</p>
          <ul className="mt-2 list-inside list-disc space-y-1 text-sm text-muted-foreground">
            {rpcConsequentlyBroken.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>

          <p className="mt-4 text-sm text-muted-foreground">
            <Rich text="**One spec deviation worth calling out:** ethrex's `eth_getLogs` **requires** a `topics` parameter — omitting it returns `Expected parameter: topics is missing`, while geth treats `topics` as optional. Conformant tooling can therefore fail even inside the window ethrex does serve." />
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <Rich text="**What this means for the RPC setup we ship:** we ship an nginx/Caddy RPC setup. On geth (`--history.chain postmerge`) that endpoint serves post-merge history properly. The same setup on ethrex answers current-state and wallet traffic fine but returns `null`/errors for anything historical — so it is not a drop-in public RPC if your users expect history. If exposing an endpoint is the goal, that's an independent reason to prefer geth or nethermind." />
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <Rich text="**Why this connects to the disk numbers:** this is precisely why ethrex's ~470 GiB plateau is not a disk win — the missing ~600 GiB *is* the history the other clients are storing. Footprint tracks what you retain." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="operational-viability" className="text-lg sm:text-xl font-semibold text-foreground">
            Operational viability — which clients would we actually run (Stage B + CL matrix synthesis)
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="Disk size converges once ELs carry full post-merge history, so it doesn't separate the field — production instead asks “will it survive restarts, upgrades, and weeks of uptime?” Under that operational lens the field narrows sharply — and the two layers tell opposite stories: the **EL layer is where the operational risk lives; the CL layer is basically solved.**" />
          </p>

          <AnchorHeading id="execution-clients-viability" as="h3" className="mt-6 font-medium text-foreground">
            Execution clients — two clear picks, one qualified third
          </AnchorHeading>
          <ul className="mt-3 space-y-3 text-sm text-muted-foreground">
            <li>
              <Rich text="**geth and nethermind both cleared the full operational bar** (snap-sync to a validating tip, clean restart-resume, the two most battle-tested codebases). On disk they're on par (~1.06 vs ~1.13 TiB — the field converges there). Choose **geth** for the largest ecosystem + cleanest resume, or **nethermind** to improve client diversity (minority client, compact flat-storage state). If you run one EL for the long haul, run one of these two." />
            </li>
            <li>
              <Rich text="**besu** is a viable enterprise third — it *did* snap-sync to a fully validated head, and its ~1.08 TiB is the same magnitude as geth/nethermind, not an outlier. The real asterisk is operational: its snap sync is **fragile to a prolonged CL outage** (a stalled CL ages the pivot out of the servable-state window → `SnapSyncChainDownloader` thread death, observed twice, un-recoverable). Runnable in a shop that keeps its CL current and watches the pivot; not a set-and-forget solo-staker pick." />
            </li>
            <li>
              <span className="font-medium text-foreground">The rest each missed the bar for a specific, documented reason — not a blanket “bad client”:</span>
              <ul className="mt-2 space-y-2 pl-4">
                <li>
                  <Rich text="**ethrex** — fastest cold sync in the whole field (~2h16m), but the restart-cliff is a real operational weakness: a 26-minute/132-block downtime gap stalled instead of resuming, and measured 1.5–2-hour gaps triggered a full ~2-hour re-snap. Separately, its datadir **plateaus at ~470–476 GiB** (confirmed 2026-07-28→31: a +43 GiB/hr post-sync settling climb collapsed ~300× to +0.13 GiB/hr and drifted 470.2 → 475.5 GiB over ~42 hours) — the earlier ~467 GiB reading was this same plateau caught mid-climb, not unbounded growth. That doesn't make it a disk winner: it plateaus low only because it serves no history at all, and on a state-only basis nethermind's ~226–230 GiB state is smaller still. Snap speed is a trap if the restart cliff isn't fixed — fast to stand up, painful to *operate*. Fast-moving young client — v19.0.0 at first sync, v22.0.0 by the 2026-07-28 steady-state run; may improve further." />
                </li>
                <li>
                  <Rich text="**reth, nimbus_eth1** — full-sync-only (no snap) in the mode we tested; can't reach tip inside a practical window on this host. This is a time-to-sync limit under our snap-to-tip bar, **not** a verdict on the clients in every context (reth in particular is widely run elsewhere)." />
                </li>
                <li>
                  <Rich text="**erigon** — deadlocked against checkpoint-synced prysm on this host (structural, reproducible), so no synced datadir." />
                </li>
              </ul>
            </li>
          </ul>

          <AnchorHeading id="consensus-clients-viability" as="h3" className="mt-6 font-medium text-foreground">
            Consensus clients — the healthy half: all five we swept are operationally effective
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <Rich text="Every CL (lighthouse, lodestar, grandine, teku, nimbus) checkpoint-synced to a validating head in ~22–23 min, `config_optimal=yes`, zero crashes, against a live anchor. Unlike the EL layer, none of them *failed* — so the choice is footprint + preference, not survivability:" />
          </p>
          <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
            <li>
              <span className="font-medium text-foreground">Disk order (the only differentiator):</span>{' '}
              <strong className="text-foreground">
                lighthouse (~739 MB) &lt; lodestar (~827 MB) &lt; grandine (~946 MB) &lt; teku (~2.1 GB)
                &lt; nimbus (~5.0 GB).
              </strong>
            </li>
            <li>
              <Rich text="Two small operational caveats: **teku** needs a generously sized JVM heap on a shared host (undersized, its GC pressure spilled onto co-resident services and poisoned a first run); **grandine** needs `--prune-storage` or it stores every state. **nimbus** is simply the heaviest (~6.8× lighthouse) but otherwise clean." />
            </li>
            <li>
              <Rich text="Cross-cutting CL lesson (learned from prysm, the constant anchor): **keep the CL binary current.** A stale prysm v7.1.5 pin stalled ~28h on a PeerDAS/data-column bug and is precisely what aged out besu's pivot. Binary freshness is an operational requirement, not a nicety." />
            </li>
          </ul>

          <p className="mt-4 text-sm text-muted-foreground">
            <Rich text="**Bottom line:** on the EL side a real long-running node comes down to **geth or nethermind** (besu if you're an enterprise shop that keeps its CL healthy); on the CL side **any of the five works**, with **lighthouse** the lean default. Fast initial sync (ethrex) and small archive-context footprints do not by themselves make a client operationally viable — durability across restarts and uptime is the deciding axis, and that is an EL-layer problem." />
          </p>
        </section>

        {/* ---------------------------------------------------------------- */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="gotchas" className="text-lg sm:text-xl font-semibold text-foreground">
            Gotchas &amp; lessons learned
          </AnchorHeading>
          <ul className="mt-4 space-y-4 text-sm text-muted-foreground">
            {gotchas.map((item, i) => (
              <li key={i}><Rich text={item} /></li>
            ))}
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
