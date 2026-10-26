import type { Metadata } from 'next'
import { AnchorHeading } from '@/components/ui/AnchorHeading'
import { ArticleJsonLd } from '@/components/ui/ArticleJsonLd'
import { ArticleToc } from '@/components/ui/ArticleToc'
import { BackToTop } from '@/components/ui/BackToTop'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Details } from '@/components/ui/Details'
import { ReadNext } from '@/components/ui/ReadNext'
import { ArticleByline } from '@/components/ui/ArticleByline'
import { buildArticleMetadata } from '@/lib/articles'
import { SITE_CONFIG } from '@/lib/constants'
import { ArrowDown, ArrowRight, ArrowUp } from 'lucide-react'

export const metadata: Metadata = buildArticleMetadata('how-we-tested-with-claude')

const tocLinks = [
  { label: 'TL;DR', href: '#tldr' },
  { label: 'The plan', href: '#the-plan' },
  { label: 'What broke', href: '#at-a-glance' },
  { label: 'The shape of the problem', href: '#shape-of-the-problem' },
  { label: 'The orchestration model', href: '#orchestration-model' },
  { label: 'The harness', href: '#the-harness' },
  { label: "What we'd tell the next person", href: '#next-person' },
  { label: 'Bottom line', href: '#bottom-line' },
  { label: 'Reproduce it', href: '#reproduce-it' },
]

// ---------------------------------------------------------------------------
// Semantic status palette, shared with the sibling bake-off pages: purple =
// good / solved, amber = caution / the axis that needs care, red = failed.
// Categorical (identity), not sequential — never used for parts-of-one-whole.
// ---------------------------------------------------------------------------
const toneStyles = {
  good: { fg: '#a855f7', bg: 'rgba(168,85,247,0.1)', border: 'rgba(168,85,247,0.4)' },
  caution: { fg: '#f5b46b', bg: 'rgba(245,180,107,0.1)', border: 'rgba(245,180,107,0.4)' },
  bad: { fg: '#e5726e', bg: 'rgba(229,114,110,0.1)', border: 'rgba(229,114,110,0.4)' },
} as const

type Tone = keyof typeof toneStyles

function StatusPill({ label, tone }: { label: string; tone: Tone }) {
  const s = toneStyles[tone]
  return (
    <span
      className="inline-flex items-center whitespace-nowrap rounded-md border px-2.5 py-0.5 font-mono text-xs font-medium"
      style={{ color: s.fg, backgroundColor: s.bg, borderColor: s.border }}
    >
      {label}
    </span>
  )
}

// ---------------------------------------------------------------------------
// At-a-glance cards — the what / how / when / who of the campaign in one
// screen, so the body below never has to re-establish the setup. No new data:
// every figure here is restated with provenance further down.
// ---------------------------------------------------------------------------
const atAGlance = [
  {
    title: 'What',
    body: 'We measured final synced disk footprint and cold-sync duration for each client that finished. Seven execution clients (ELs) ran against fixed Prysm, then five consensus clients (CLs) against a fixed execution client. erigon deadlocked; reth and nimbus_eth1 hit the 72h cap.',
  },
  {
    title: 'How',
    body: 'Native systemd services, no Docker. One candidate at a time on a shared 12-core / ~62 GB host. Each run capped at 72 hours.',
  },
  {
    title: 'When',
    body: 'Jun 22 → Jul 14, 2026: 23 days. Steady-state re-measurement and restart-resume follow-ons extended the campaign through Aug 4: six weeks total.',
  },
  {
    title: 'Who',
    body: 'Three AI-agent tiers did the work. A human approved every destructive action and merge.',
  },
]

const tldrPoints = [
  {
    title: 'Agent context runs out first.',
    body: 'Detach node runs with systemd; wake agents only for events. Save conclusions beside the data and durable state in small files.',
  },
  {
    title: 'Three tiers save context.',
    body: 'Opus plans and reviews every diff. Fresh Sonnet builders implement and summarize. Independent Codex lands its own fixes on bake-off branches and adversarially reviews PRs.',
  },
  {
    title: 'Humans control irreversible steps.',
    body: 'One candidate at a time; 72-hour cap. A human explicitly approved wiping the synced 1.1 TiB node for pruning. A human reviewed and approved merging the measured nethermind minimal-history default; the agent never decided to merge it.',
  },
  {
    title: 'Fast sync hides operational limits.',
    body: "ethrex cold-synced fastest but was not production-ready as tested: a 26-minute/132-block restart gap stalled, and longer measured gaps caused a full re-snap. Its datadir (data directory) plateaus at ~470–476 GiB but stores no history, so it is no disk win. besu synced, but its pruned re-run proved fragile after a prolonged pinned-Prysm outage.",
  },
]

// Every date is a shipped fix or completed measurement run, cross-checked against
// CLIENT_BAKEOFF_RESULTS.md and the repo's merged-PR history — none invented or approximated.
// The flat date list is grouped into three phases; every milestone is preserved.
// `days` is plain arithmetic on the stated range (inclusive), used only to size the
// proportional phase bar below — it asserts nothing the dates don't already say.
const campaignPhases = [
  {
    name: 'Phase 1 — Initial measurement campaign',
    short: 'Phase 1',
    range: 'Jun 22 → Jul 14, 2026',
    note: '23 days',
    days: 23,
    summary:
      'Seven execution clients against a fixed Prysm, then a five-way consensus sweep. Triage, installer fixes, and the first full syncs.',
    milestones: [
      { date: '2026-06-22', label: 'Campaign starts, Stage A triage begins' },
      { date: '2026-06-26', label: 'Stage-A installer fixes shipped' },
      { date: '2026-07-01', label: 'besu completes un-pruned sync' },
      { date: '2026-07-05', label: 'besu pruned re-run abandoned, deadlocked twice' },
      { date: '2026-07-06', label: 'CL sweep vs ethrex anchor, 5 CLs' },
      { date: '2026-07-08', label: 'CL cross-check vs geth anchor' },
      { date: '2026-07-10', label: 'ethrex restart-cliff bisected, geth 52h resume verified' },
      { date: '2026-07-13', label: 'Installer / config correctness fixes shipped' },
      { date: '2026-07-13', label: 'nimbus_eth1 72h capped run completes' },
      { date: '2026-07-14', label: 'Initial campaign closes — harness and results docs shipped' },
    ],
  },
  {
    name: 'Phase 2 — Steady-state re-measure',
    short: 'Phase 2',
    range: 'Jul 26 → Jul 29, 2026',
    note: 'footprints settled',
    days: 4,
    summary:
      'Re-read footprints once compaction settled, plus a third CL sweep against a nethermind anchor.',
    milestones: [
      { date: '2026-07-26', label: 'Third anchor: CL sweep re-run against nethermind' },
      { date: '2026-07-28', label: 'Steady-state re-measure: ethrex plateau confirmed (~470–476 GiB)' },
      { date: '2026-07-29', label: 'EL-disk convergence reframe published (no disk winner)' },
    ],
  },
  {
    name: 'Phase 3 — Restart-resume & prune follow-ons',
    short: 'Phase 3',
    range: 'Jul 31 → Aug 4, 2026',
    note: 'no restart cliff found',
    days: 5,
    summary:
      'Restart-resume experiments, the minimal-history prune default, and shipping it as a human-reviewed PR.',
    milestones: [
      { date: '2026-07-31', label: 'Nethermind fresh re-sync in 1h53m (establish run)' },
      { date: '2026-08-01', label: 'Steady-state re-measure: nethermind full-history datadir ~1.06 TiB' },
      { date: '2026-08-01', label: 'Nethermind resumes a 10,607-block gap in 35 min — restart-resume measured' },
      { date: '2026-08-03', label: 'Bisection finds no cliff at any gap (12 min → ~35h); prysm clean-resume measured, n=4' },
      { date: '2026-08-03', label: 'Nethermind prune tuning produces a minimal-history default (~250–280 GiB, no-history tier), measured and shipped as a human-reviewed PR' },
      { date: '2026-08-04', label: 'Minimal-history default merged to master, shipped as the installer default' },
    ],
  },
]

const totalMilestones = campaignPhases.reduce((sum, phase) => sum + phase.milestones.length, 0)

// Gaps between the three measurement phases, in days, so the proportional bar
// spans the real Jun 22 → Aug 4 calendar (44 days) rather than just the active ones.
const phaseGapDays = [11, 1]
const campaignSpanDays = campaignPhases.reduce((sum, p) => sum + p.days, 0) + phaseGapDays[0] + phaseGapDays[1]
const activeMeasurementDays = campaignPhases.reduce((sum, p) => sum + p.days, 0)

const clientIncidents = [
  {
    client: 'nethermind',
    whatHappened: '13.3h silent stall: head frozen at block 4,651, 0 peers. Everything else looked healthy.',
    rootCause: 'P2P (peer-to-peer) bind pinned to loopback, a local-only address (Network.LocalIp=127.0.0.1)',
    resolution: 'Advertise the real external IP',
    status: 'Fixed',
    statusNote: 'production-viable — restart-resume measured 2026-08-01',
    tone: 'good' as Tone,
  },
  {
    client: 'besu',
    whatHappened: 'Mid-sync deadlock: downloader thread died. Process stayed alive and answered RPC (remote procedure calls).',
    rootCause: 'Stale pinned CL (prysm v7.1.5) stalled the beacon ~28h. The snap-sync pivot aged beyond the ~25-min servable-state window.',
    resolution: 'No fix available: upstream CL issue. Keep CL binaries current. Added a harness stall-watchdog.',
    status: 'Fragile',
    statusNote: 'to a prolonged CL outage',
    tone: 'caution' as Tone,
  },
  {
    client: 'ethrex',
    whatHappened: 'Measured restart outcomes appear above. Un-pruned datadir plateau: ~470–476 GiB, drifting 470.2 → 475.5 GiB over ~42h.',
    rootCause: 'Old head leaves the ~128-block servable-state window. The head can freeze; longer gaps can trigger full snap-sync instead of importing missing blocks.',
    resolution: 'None — inherent to current design (v19.0.0)',
    status: 'Not production-ready',
    statusNote: 'as tested — young client, may improve',
    tone: 'bad' as Tone,
  },
  {
    client: 'erigon',
    whatHappened: 'Head froze a few thousand blocks behind tip; consensus stayed is_optimistic=true indefinitely',
    rootCause: 'erigon3 OtterSync deadlocked closing the gap against checkpoint-synced Prysm. Resources were not the cause.',
    resolution: 'No fix. Operator terminated the run; recorded as a no-sync.',
    status: 'No-sync',
    statusNote: 'on this host/CL combination',
    tone: 'bad' as Tone,
  },
]

const controlLoopSteps = [
  'Human operator — approves destructive steps',
  'Claude orchestrator — starts and resumes runs',
  'Detached tmux driver',
  'Bake-off harness → systemd EL/CL services + samples, verdicts, run artifacts',
  'Small durable state: results, queue, handoff',
]

const shapePoints = [
  {
    lead: "It's slow",
    body: 'ethrex snap-synced mainnet in ~2 hours. Full-sync-only clients never finished in three days. Each candidate got 72 hours.',
  },
  {
    lead: "It's sequential",
    body: 'One shared host has one execution slot and one consensus slot. geth and nethermind would compete for CPU, IO, and peers. Candidates run one at a time.',
  },
  {
    lead: "It's easy to measure the wrong thing",
    body: 'A client can install and follow the chain yet hide 0 peers or a frozen head. Archive mode invalidates a disk comparison. Sampling mid-compaction over-counts.',
  },
  {
    lead: "It's destructive",
    body: "Each measurement wipes the previous client’s datadir on a host shared with other people’s work.",
  },
]

// ---------------------------------------------------------------------------
// The article's thesis as one picture: three clocks run at once and the
// shortest one decides how long a campaign can last. Spans are the figures
// already stated elsewhere on this page; `width` is illustrative ordering
// only, which the figure says out loud rather than implying a ratio.
// ---------------------------------------------------------------------------
const threeClocks = [
  {
    name: 'Node wall-clock',
    span: '~2 h → 72 h per candidate · six weeks total',
    width: '100%',
    tone: 'good' as Tone,
    fix: 'Solved by detaching it.',
    detail: 'Native systemd units run from detached tmux. Sync continues after a Claude session dies.',
  },
  {
    name: 'Agent wall-clock',
    span: 'sleeps between events · effectively unbounded',
    width: '100%',
    tone: 'good' as Tone,
    fix: 'Solved by not watching.',
    detail: 'Watchers notify once a run reaches an end condition. The orchestrator sleeps until a decision is needed.',
  },
  {
    name: 'Agent context',
    span: 'fills in hours, not weeks',
    width: '15%',
    tone: 'caution' as Tone,
    fix: 'The one that binds first.',
    detail: 'Raw journalctl, du, and RPC dumps consume context. Save conclusions as env.txt flags and durable state in small files.',
  },
]

// What's actually implemented (test/bakeoff/lib.sh, run_candidate.sh) — no peer-count check
// anywhere; the stall-watchdog tracks one flat no-progress streak and is opt-in. STALLED is
// reachable only through RESTARTING, never directly from SYNCING — VerdictDiagram below renders
// it nested under RESTARTING (not as a same-level fan-out) to keep that chain honest.
const verdictOutcomes = [
  { name: 'SYNCED', trigger: '2 consecutive clean samples', tone: 'good' as Tone },
  { name: 'CAPPED', trigger: 'window elapses, still not synced', tone: 'caution' as Tone },
  { name: 'RESTARTING', trigger: 'opt-in watchdog hits its no-progress threshold. Returns to SYNCING, or reaches STALLED after the restart budget runs out.', tone: 'caution' as Tone },
]

// A real, distinct terminal state (docs/CLIENT_BAKEOFF_HARNESS.md §3.5): a `.stalled` marker
// file / `stall_failed=yes` once the bounded restart budget is exhausted. Nethermind's earlier
// 13.3h 0-peer stall predates this watchdog and motivated adding it.
const stalledOutcome = {
  name: 'STALLED',
  trigger: 'Block number or head slot stops advancing. Opt-in watchdog exhausts bounded restarts, then flags the row before the 72-hour cap.',
  tone: 'bad' as Tone,
}

const durableStatePoints = [
  {
    lead: 'Push conclusions down to where the data lives.',
    body: 'env.txt flags replace logs: fully_synced=yes after two consecutive clean samples. With the watchdog armed, exhausted bounded restarts produce .stalled.',
  },
  {
    lead: 'Keep durable state small and in files.',
    body: 'Small markdown files hold results, governance rules, the queue, and a live self-handoff. Context clears lose no campaign state.',
  },
  {
    lead: 'Keep transient investigation off the context path.',
    body: 'Compute, summarize, then discard logs, probes, and sample dumps.',
  },
]

// ---------------------------------------------------------------------------
// Governance as a fence with two sides: standing rails the agent always runs
// inside, and the two irreversible levers only a human ever pulls. Same five
// rules the campaign ran under, shown as a shape instead of a list.
// ---------------------------------------------------------------------------
const governanceRails = [
  {
    lead: 'One candidate at a time.',
    body: 'No batching. Ever.',
  },
  {
    lead: '72-hour cap per candidate.',
    body: "Use the last sample before teardown: at sync or the cap, never the peak. Compaction changes disk size. reth peaked at 1.06 TiB versus ~0.98 TiB at the 72h cap.",
  },
  {
    lead: 'New commits only, Conventional Commits.',
    body: 'No force-push to master. Secrets stayed in protected local files, outside commits and agent context.',
  },
]

const governanceLevers = [
  {
    lead: 'Destructive data-cleans.',
    body: 'Wiping the live shared node required fresh, explicit human confirmation for every run.',
  },
  {
    lead: 'Merging.',
    body: 'Every PR merge required explicit human approval. The agent never decided to merge.',
  },
]

const harnessPipelineSteps = [
  'Candidate manifest → run_bakeoff.sh (walks one candidate at a time)',
  'run_candidate.sh: hard-reset shared services → install → apply resource caps',
  'run_candidate.sh sampling loop → verdict (SYNCED / CAPPED / STALLED / install error)',
  'Snapshot disk, before teardown',
  'summarize.sh → results table',
]

// The third tier is named from evidence, not from the routing table. The repo's
// AI-delegation table lists devin-delegate and kimi-delegate as the sandboxed and
// cheap-read-only lanes, but neither has any campaign-window bake-off activity:
// Devin's only commit ever is 2026-05-30 (pre-campaign, unrelated) and Kimi has
// none, with its one dated use in docs/audit/FINDINGS-2026-06-09.md — 13 days
// before the campaign, on a different workstream. Codex does have in-window
// bake-off commits (4e842c5 2026-07-11, c5c0edc 2026-07-25) plus reviews cited in
// a9e9df5 (#202) and e02197c (#212, two P1s + one false positive), so it is the
// one named here. grok-delegate never cleared its revival gate and was never invoked.
const agentTiers = [
  {
    role: 'Orchestrator / reviewer',
    who: 'Claude Opus 4.8',
    what: 'Planned the queue, made judgment calls, reviewed every diff, and wrote durable state. Did not hand-write most client code.',
  },
  {
    role: 'Builders',
    who: 'fresh Claude Sonnet subagents',
    what: "Implemented written briefs and returned short summaries. Most tokens stayed outside orchestrator context.",
  },
  {
    role: 'Independent peer',
    who: 'Codex (OpenAI)',
    what: 'Outside Claude’s hierarchy, Codex used its own git identity and branches. It landed the ethrex restart-cliff bracket (2026-07-11) and bake-off review findings (2026-07-25). It also adversarially reviewed campaign PRs. On #212, it found two genuine P1 rerun-queue defects and one false positive. A different-model second opinion, not a cheaper model.',
  },
]

const harnessScripts = [
  { name: 'run_bakeoff.sh', path: 'test/bakeoff/run_bakeoff.sh', desc: 'sequential orchestrator with a resume guard: a killed campaign restarts where it left off, never re-runs finished candidates.' },
  { name: 'run_candidate.sh', path: 'test/bakeoff/run_candidate.sh', desc: 'single-candidate runner: reset → install → cap → sample. Owns the observation loop and captures a final footprint on synced, capped, stalled, and install-error paths before teardown. Preflight aborts such as insufficient disk exit before sampling starts.' },
  { name: 'lib.sh', path: 'test/bakeoff/lib.sh', desc: 'shared probe/sample library: sync probes, the sample writer, the disk snapshotter, and the config-optimality gate.' },
  { name: 'apply_resource_caps.sh', path: 'test/bakeoff/apply_resource_caps.sh', desc: "systemd CPUQuota/MemoryMax caps so a heavy sync can't starve co-resident workloads on the shared host." },
  { name: 'summarize.sh', path: 'test/bakeoff/summarize.sh', desc: 'turns per-run artifacts into the results table, split by whether the config was verified optimal.' },
  { name: 'run_anchor_rotation.sh', path: 'test/bakeoff/run_anchor_rotation.sh', desc: 'preserves the execution-client anchor during the consensus sweep.' },
]

const anchorInstabilityPoints = [
  {
    lead: 'lodestar ↔ lighthouse flipped between anchors:',
    body: 'geth: lodestar < lighthouse; ethrex: lighthouse < lodestar.',
  },
  {
    lead: 'teku swung ~25% on the same anchor:',
    body: '~667 MiB, then ~835 MiB on a clean re-read of the nethermind anchor — enough to flip it from below grandine (~730 MiB) to above it.',
  },
]

const anchorCaveatPoints = [
  {
    lead: "lodestar's first run was a measurement artifact.",
    body: 'The anchor EL was still closing an unrelated block gap. That inflated sync time to ~76 minutes versus ~10 for the other four. We discarded it and re-read cleanly: ~7m36s, ~178 MiB.',
  },
  {
    lead: "teku's run tripped a false positive.",
    body: 'The watchdog reported anchor_synced=no. Independent checks found the anchor healthy: the check was wrong.',
  },
]

const harnessBugs = [
  {
    title: 'The detached-shell landmine (SIGTTIN)',
    cost: 'hung a run for 90 minutes',
    what: "An install step logged the binary version with geth version | head -1. In detached tmux, its non-foreground process group read a tty it did not own. SIGTTIN stopped the whole subtree without killing it.",
    fix: 'Redirect stdin from /dev/null on unattended invocations.',
  },
  {
    title: 'The measurement that vanished at the cap',
    cost: 'cost reth its clean footprint',
    what: 'Only successful syncs took a disk snapshot before teardown. At the 72-hour cap, teardown wiped the datadir before snapshotting. Only reth hit the cap while this bug existed. We reconstructed its partial footprint from samples.jsonl.',
    fix: "Snapshot every end condition after installation, before teardown. Preflight aborts still exit before sampling. Slow clients take the easily forgotten cap path.",
  },
]

const nextPersonPoints = [
  {
    lead: 'Measure on every exit path, before you destroy anything.',
    body: 'Cap and error paths can quietly lose data.',
  },
  {
    lead: 'Gate your benchmark on config, not just on outcome.',
    body: 'Check each number against the client’s best mode, or risk publishing your own configuration mistake.',
  },
]

// Deliberately all repo links, matching this section's "the harness is in the repo and the data is
// committed" framing. The rendered siblings are one block below, as <ReadNext /> cards — pointing
// these at /blog/* too would duplicate that and break the promise the intro sentence makes.
const reproduceLinks = [
  { label: 'The harness', href: `${SITE_CONFIG.github}/tree/master/test/bakeoff` },
  { label: 'The harness, function-by-function', href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_HARNESS.md` },
  { label: 'The results', href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md` },
  { label: 'The narrative', href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_BLOG.md` },
  { label: 'The war stories', href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_ISSUES_LOG.md` },
  { label: 'Running a node for real', href: `${SITE_CONFIG.github}/blob/master/docs/blog/CLIENT_BAKEOFF_OPERATOR_GUIDE.md` },
]

function LeadList({ items }: { items: { lead: string; body: string }[] }) {
  return (
    <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
      {items.map((item) => (
        <li key={item.lead}>
          <span className="font-medium text-foreground">{item.lead}</span> {item.body}
        </li>
      ))}
    </ul>
  )
}

function FlowDiagram({ steps, loopBackTo, loopLabel }: { steps: string[]; loopBackTo?: string; loopLabel?: string }) {
  return (
    <div className="flex flex-col items-stretch">
      {steps.map((step, index) => (
        <div key={step} className="flex flex-col items-center">
          <div className="w-full rounded-lg border border-border bg-background/40 px-4 py-3 text-center text-sm text-foreground">
            {step}
          </div>
          {index < steps.length - 1 && (
            <ArrowDown className="my-1.5 h-4 w-4 shrink-0 text-muted-foreground" aria-hidden="true" />
          )}
        </div>
      ))}
      {loopBackTo && (
        <div className="flex flex-col items-center">
          <div className="my-1.5 flex items-center gap-1.5 text-xs font-medium text-primary">
            <ArrowUp className="h-4 w-4 shrink-0" aria-hidden="true" />
            {loopLabel}
          </div>
          <div className="w-full rounded-lg border border-dashed border-primary/40 bg-primary/5 px-4 py-3 text-center text-sm text-foreground">
            {loopBackTo}
          </div>
        </div>
      )}
    </div>
  )
}

/**
 * The three clocks a long agent-driven campaign runs on, and which one runs out
 * first. Bar length is deliberately illustrative — the figure states that in
 * words — because the honest claim is the ordering (context is shortest by
 * orders of magnitude), not a measured ratio.
 */
function ThreeClocksFigure() {
  return (
    <figure
      className="mt-5 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
      aria-label="Three clocks run at once during an agent-driven campaign. Node wall-clock runs 2 to 72 hours per candidate and is solved by detaching the node into systemd. Agent wall-clock is effectively unbounded and is solved by event-driven wakeups instead of polling. Agent context fills in hours rather than weeks and is the constraint that binds first, solved by collapsing conclusions into flag files and keeping durable state small."
    >
      <p className="text-center text-sm font-medium text-foreground">
        Three clocks run at once. The shortest one decides how long the campaign can last.
      </p>
      <div className="mt-4 space-y-3">
        {threeClocks.map((clock) => {
          const s = toneStyles[clock.tone]
          return (
            <div
              key={clock.name}
              className="rounded-lg border p-3"
              style={{ borderColor: s.border, backgroundColor: s.bg }}
            >
              <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
                <span className="text-sm font-medium" style={{ color: s.fg }}>
                  {clock.name}
                </span>
                <span className="font-mono text-[11px] text-muted-foreground">{clock.span}</span>
              </div>
              <div className="mt-2 h-2 overflow-hidden rounded-full bg-background/60" aria-hidden="true">
                <div className="h-full rounded-full" style={{ width: clock.width, backgroundColor: s.fg }} />
              </div>
              <p className="mt-2 text-xs text-muted-foreground">
                <span className="font-medium text-foreground">{clock.fix}</span> {clock.detail}
              </p>
            </div>
          )
        })}
      </div>
      <p className="mt-3 text-center text-[11px] italic text-muted-foreground">
        not to scale — the claim is the ordering, not the ratio
      </p>
      <figcaption className="mt-3 text-xs text-muted-foreground">
        Infrastructure solves the first two clocks. Context architecture decides whether the campaign lasts six weeks or an afternoon.
      </figcaption>
    </figure>
  )
}

/**
 * The campaign at calendar scale: three measurement phases separated by two
 * gaps, sized by the days between the dates in `campaignPhases`. The full
 * dated milestone log stays available, collapsed, below the figure.
 */
function CampaignPhasesFigure() {
  const segments = [
    { key: 'p0', phase: campaignPhases[0], days: campaignPhases[0].days },
    { key: 'g0', phase: null, days: phaseGapDays[0] },
    { key: 'p1', phase: campaignPhases[1], days: campaignPhases[1].days },
    { key: 'g1', phase: null, days: phaseGapDays[1] },
    { key: 'p2', phase: campaignPhases[2], days: campaignPhases[2].days },
  ]
  return (
    <figure
      className="mt-4 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
      aria-label={`The six-week campaign ran as three measurement phases across ${campaignSpanDays} calendar days: a 23-day initial campaign, an 11-day gap, a 4-day steady-state re-measure, a 1-day gap, and a 5-day restart-resume and prune phase.`}
    >
      <div className="flex h-8 items-stretch overflow-hidden rounded-lg border border-border" aria-hidden="true">
        {segments.map((segment) => (
          <div
            key={segment.key}
            className={
              segment.phase
                ? 'flex items-center justify-center bg-[#a855f7]/[0.18] text-[10px] font-medium text-[#a855f7]'
                : 'flex items-center justify-center border-x border-dashed border-border bg-background/40 text-[10px] text-muted-foreground'
            }
            style={{ flexGrow: segment.days, flexBasis: 0 }}
          >
            {/* Phase 2 and 3 are narrow segments; their labels only fit from sm up,
                and the phase cards below name them at every width anyway. */}
            <span className="hidden truncate px-1 sm:inline">{segment.phase ? segment.phase.short : ''}</span>
          </div>
        ))}
      </div>
      <div className="mt-2 flex items-baseline justify-between px-0.5 text-[11px] text-muted-foreground">
        <span>2026-06-22</span>
        <span>
          {activeMeasurementDays} of {campaignSpanDays} days actively measuring
        </span>
        <span>2026-08-04</span>
      </div>
      <div className="mt-4 grid gap-3 sm:grid-cols-3">
        {campaignPhases.map((phase) => (
          <div key={phase.name} className="rounded-lg border border-border bg-background/40 p-3">
            <div className="flex items-baseline justify-between gap-2">
              <span className="text-sm font-medium text-foreground">{phase.short}</span>
              <span className="font-mono text-[11px] text-[#a855f7]">{phase.days}d</span>
            </div>
            <p className="mt-0.5 font-mono text-[11px] text-muted-foreground">{phase.range}</p>
            <p className="mt-2 text-xs text-muted-foreground">{phase.summary}</p>
            <p className="mt-2 text-[11px] text-muted-foreground">
              <span className="font-medium text-foreground">{phase.milestones.length} milestones</span>
              {' · '}
              {phase.note}
            </p>
          </div>
        ))}
      </div>
      <figcaption className="mt-3 text-xs text-muted-foreground">
        Steady-state and restart-resume follow-ons extended the initial campaign to six weeks. The host and orchestration model stayed the same throughout.
      </figcaption>
    </figure>
  )
}

/**
 * The three tiers, as the shape the work actually took: one orchestrator holding
 * the diff, several disposable builders holding the investigation, and one
 * independent peer agent outside the hierarchy doing adversarial review.
 */
function AgentHierarchy() {
  return (
    <figure
      className="mt-4 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
      aria-label="A Claude Opus 4.8 orchestrator sits at the top, planning, reviewing every diff, and writing durable state. Below it, fresh Claude Sonnet subagents each take one task and report a summary back. Outside the hierarchy, Codex works as an independent peer agent, landing its own commits on bake-off branches and adversarially reviewing the pull requests. Only summaries return to the orchestrator, never full context."
    >
      <div className="mx-auto max-w-sm rounded-lg border border-[#a855f7]/40 bg-[#a855f7]/10 px-4 py-3 text-center text-sm text-foreground">
        Orchestrator / reviewer &mdash; <span className="font-medium text-[#a855f7]">Claude Opus 4.8</span>
        <span className="block text-xs text-muted-foreground">plans, reviews every diff, writes durable state</span>
      </div>
      <ArrowDown className="mx-auto my-1.5 h-4 w-4 text-muted-foreground" aria-hidden="true" />
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="rounded-lg border border-border bg-background/40 px-4 py-3 text-center text-sm text-foreground">
          Builder &mdash; fresh Sonnet subagent
          <span className="block text-xs text-muted-foreground">one task, reports a summary back</span>
        </div>
        <div className="rounded-lg border border-border bg-background/40 px-4 py-3 text-center text-sm text-foreground">
          Builder &mdash; fresh Sonnet subagent
          <span className="block text-xs text-muted-foreground">one task, reports a summary back</span>
        </div>
      </div>
      <div className="mx-auto mt-3 flex w-fit flex-col items-center gap-1 rounded-lg border border-dashed border-primary/40 bg-primary/5 px-3 py-1.5">
        <ArrowUp className="h-4 w-4 shrink-0 text-primary" aria-hidden="true" />
        <span className="text-xs text-muted-foreground">summary only, not full context &mdash; returns to the orchestrator</span>
      </div>
      {/* Codex sits below the rule, with no arrow to the orchestrator: it was not dispatched
          by this hierarchy, so drawing it as a third child would assert the opposite of the copy. */}
      <div className="mt-5 border-t border-dashed border-border pt-4">
        <p className="mb-2 text-center text-[11px] uppercase tracking-wide text-muted-foreground">
          outside the hierarchy
        </p>
        <div className="mx-auto max-w-sm rounded-lg border border-dashed border-muted-foreground/50 bg-background/40 px-4 py-3 text-center text-sm text-foreground">
          Independent peer &mdash; <span className="font-medium">Codex</span>
          <span className="block text-xs text-muted-foreground">
            its own identity and branches: lands fixes, reviews the PRs adversarially
          </span>
        </div>
      </div>
      <figcaption className="mt-3 text-xs text-muted-foreground">
        Builders read client source and return diffs and summaries, keeping investigations outside the expensive model&apos;s context.
        Independently dispatched Codex reviews without the orchestrator&apos;s assumptions.
      </figcaption>
    </figure>
  )
}

function VerdictDiagram() {
  return (
    <figure
      className="mt-4 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
      aria-label="A syncing candidate ends in one of three ways: SYNCED after two consecutive clean samples, CAPPED when the observation window elapses unsynced, or RESTARTING when the opt-in stall watchdog trips — which loops back to syncing, or falls through to STALLED once the restart budget is exhausted."
    >
      <div className="mx-auto max-w-xs rounded-lg border border-border bg-background/40 px-4 py-2 text-center text-sm font-medium text-foreground">
        SYNCING
      </div>
      <ArrowDown className="mx-auto my-1.5 h-4 w-4 text-muted-foreground" aria-hidden="true" />
      <div className="grid gap-3 sm:grid-cols-3">
        {verdictOutcomes.map((outcome) => (
          <div key={outcome.name} className="flex flex-col items-center gap-1.5">
            <div className="w-full rounded-lg border border-border bg-background/40 px-3 py-2 text-center">
              <StatusPill label={outcome.name} tone={outcome.tone} />
              <p className="mt-1.5 text-xs text-muted-foreground">{outcome.trigger}</p>
            </div>
            {outcome.name === 'RESTARTING' && (
              <>
                <ArrowDown className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden="true" />
                <div className="w-full rounded-lg border border-border bg-background/40 px-3 py-2 text-center">
                  <StatusPill label={stalledOutcome.name} tone={stalledOutcome.tone} />
                  <p className="mt-1.5 text-xs text-muted-foreground">{stalledOutcome.trigger}</p>
                </div>
              </>
            )}
          </div>
        ))}
      </div>
      <figcaption className="mt-3 text-xs text-muted-foreground">
        Only <span className="font-medium text-foreground">SYNCED</span> yields a usable footprint.
        Other paths still snapshot disk before teardown, as the second harness bug below explains.
      </figcaption>
    </figure>
  )
}

/**
 * Governance as a shape: standing rails the agent always runs inside, and the
 * two irreversible levers only a human ever pulls.
 */
function GovernanceFence() {
  return (
    <figure
      className="mt-4 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
      aria-label="Governance had two sides. Standing rails the agent always ran inside: one candidate at a time with no batching, a 72-hour cap per candidate with the footprint taken from the last sample before teardown, and new commits only under Conventional Commits with no force-push and secrets kept out of agent context. Levers only the human pulled: destructive data-cleans, which needed a fresh go-ahead per run, and merging, because no pull request merges without an explicit human go-ahead."
    >
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="rounded-lg border border-[#a855f7]/40 bg-[#a855f7]/10 p-3">
          <p className="text-xs font-medium uppercase tracking-wide text-[#a855f7]">
            Rails the agent runs inside
          </p>
          <ul className="mt-2 space-y-2 text-xs text-muted-foreground">
            {governanceRails.map((rail) => (
              <li key={rail.lead}>
                <span className="font-medium text-foreground">{rail.lead}</span> {rail.body}
              </li>
            ))}
          </ul>
        </div>
        <div className="rounded-lg border border-[#f5b46b]/40 bg-[#f5b46b]/10 p-3">
          <p className="text-xs font-medium uppercase tracking-wide text-[#f5b46b]">
            Levers only the human pulls
          </p>
          <ul className="mt-2 space-y-2 text-xs text-muted-foreground">
            {governanceLevers.map((lever) => (
              <li key={lever.lead}>
                <span className="font-medium text-foreground">{lever.lead}</span> {lever.body}
              </li>
            ))}
          </ul>
        </div>
      </div>
      <figcaption className="mt-3 text-xs text-muted-foreground">
        The split is about reversibility, not capability: the agent owns repeatable work; humans control irreversible steps.
      </figcaption>
    </figure>
  )
}

function RestartGapFigure() {
  const gaps = [
    { gap: 'Through 23 min / 124 blocks', outcome: 'Resumed', detail: 'Imported the gap', tone: 'good' as Tone },
    { gap: '26 min / 132 blocks', outcome: 'Stalled', detail: 'Head stopped advancing', tone: 'bad' as Tone },
    { gap: '1.5–2h', outcome: 'Re-snapped (~2h)', detail: 'Discarded state', tone: 'bad' as Tone },
  ]
  return (
    <figure
      className="mt-4 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
      aria-label="ethrex resumed measured gaps through 23 minutes and 124 blocks, stalled at 26 minutes and 132 blocks, and discarded state for a roughly two-hour re-snap after measured gaps of 1.5 to 2 hours."
    >
      <div className="grid gap-3 sm:grid-cols-3">
        {gaps.map((gap) => (
          <div key={gap.gap} className="rounded-lg border bg-background/40 p-3" style={{ borderColor: toneStyles[gap.tone].border }}>
            <p className="font-mono text-xs text-foreground">{gap.gap}</p>
            <p className="mt-2 text-sm font-medium" style={{ color: toneStyles[gap.tone].fg }}>{gap.outcome}</p>
            <p className="mt-1 text-xs text-muted-foreground">{gap.detail}</p>
          </div>
        ))}
      </div>
      <figcaption className="mt-3 text-xs text-muted-foreground">
        ethrex v19.0.0 cold-synced fastest, but these restart outcomes made it unsuitable for production as tested.
      </figcaption>
    </figure>
  )
}

function ConsensusTiersFigure() {
  const tiers = [
    { tier: 'Lightweight', clients: 'lodestar · lighthouse', color: '#e9d5ff' },
    { tier: 'Mid', clients: 'teku · grandine', color: '#c084fc' },
    { tier: 'Heavy', clients: 'nimbus', color: '#a855f7' },
  ]
  return (
    <figure
      className="mt-4 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
      aria-label="All three execution-client anchors reproduced the same consensus-client disk tiers: lodestar and lighthouse were lightweight, teku and grandine were mid, and nimbus was heavy. Within-tier ordering varied."
    >
      <div className="grid gap-3 sm:grid-cols-3">
        {tiers.map((tier) => (
          <div key={tier.tier} className="rounded-lg border border-border bg-background/40 p-3">
            <div className="mb-3 h-1 rounded-full" style={{ backgroundColor: tier.color }} aria-hidden="true" />
            <p className="text-sm font-medium text-foreground">{tier.tier}</p>
            <p className="mt-1 text-xs text-muted-foreground">{tier.clients}</p>
          </div>
        ))}
      </div>
      <figcaption className="mt-3 text-xs text-muted-foreground">
        Disk tiers held across ethrex, geth, and nethermind anchors; order within each pair was less stable.
      </figcaption>
    </figure>
  )
}

export default function HowWeTestedWithClaudePage() {
  return (
    <div className="min-h-screen py-12 sm:py-16 md:py-24">
      <div className="mx-auto max-w-5xl px-4 sm:px-6">
        <ArticleJsonLd slug="how-we-tested-with-claude" />
        <header id="article-top" tabIndex={-1} className="focus:outline-none">
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Blog &middot; Companion to the bake-off writeup
          </p>
          <ArticleByline slug="how-we-tested-with-claude" />
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            How we ran a six-week Ethereum client bake-off with Claude
          </h1>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            How AI agents coordinated a six-week benchmark on a shared host: the test harness (measurement scripts),
            the orchestration model, and what broke. The results post covers the clients.
          </p>
          <div className="mt-4 flex flex-wrap gap-3 sm:mt-6">
            <Button href="/deck/how-we-tested.html" external variant="secondary" size="sm">
              View as slides
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
            <Button href="/blog/ethereum-client-bakeoff" variant="secondary" size="sm">
              Read the results writeup
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
            <Button href="/blog/bakeoff-harness" variant="ghost" size="sm">
              The bake-off harness
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
            <Button href="/blog/bakeoff-results" variant="ghost" size="sm">
              Bake-off results (raw data)
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
          </div>
        </header>

        <Card padding="sm" className="mt-8 border-primary/20 bg-primary/5">
          <p className="text-sm text-foreground">
            This was AI-<em>driven</em>, not AI-<em>unsupervised</em>. Humans explicitly approved every live-node destructive action and PR merge.
            Every result was committed using Conventional Commits and reviewed. The claim isn&apos;t that AI did it alone: the right agent–operator division of labor completed a disk-and-timing-sensitive benchmark without a person watching sync.
          </p>
        </Card>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="tldr" className="text-lg sm:text-xl font-semibold text-foreground">In 30 seconds</AnchorHeading>
          <Card padding="sm" className="mt-4 bg-muted/30">
            <ul className="list-disc space-y-3 pl-4 text-sm text-muted-foreground">
              {tldrPoints.map((point) => (
                <li key={point.title}>
                  <span className="font-medium text-foreground">{point.title}</span> {point.body}
                </li>
              ))}
            </ul>
          </Card>
        </section>

        <section className="mt-8" aria-label="Campaign at a glance: what, how, when, and who ran it">
          <h2 className="text-sm font-medium uppercase tracking-wide text-muted-foreground">
            At a glance: what, how, when &amp; who
          </h2>
          <div className="mt-3 grid gap-3 sm:gap-4 md:grid-cols-2">
            {atAGlance.map((item) => (
              <Card key={item.title} padding="sm" className="bg-muted/30">
                <h3 className="font-medium text-foreground">{item.title}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{item.body}</p>
              </Card>
            ))}
          </div>
        </section>

        <ArticleToc links={tocLinks} />

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="the-plan" className="text-lg sm:text-xl font-semibold text-foreground">The plan</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            We measured each client that finished with the same protocol, across three phases over six weeks.
          </p>

          <div className="mt-6">
            <AnchorHeading id="campaign-timeline" as="h3" className="font-medium text-foreground">
              Six weeks, in three phases
            </AnchorHeading>
            <CampaignPhasesFigure />
            <Details
              summary={`Full milestone log — all ${totalMilestones} dated entries`}
              className="mt-4"
            >
              <div className="space-y-4">
                {campaignPhases.map((phase) => (
                  <div key={phase.name}>
                    <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
                      <h4 className="text-sm font-medium text-foreground">{phase.name}</h4>
                      <span className="font-mono text-xs text-primary">{phase.range}</span>
                    </div>
                    <ol className="mt-2 space-y-1.5">
                      {phase.milestones.map((milestone, index) => (
                        <li key={`${milestone.date}-${index}`} className="flex gap-3 text-xs">
                          <span className="w-[5.5rem] shrink-0 font-mono text-primary">{milestone.date}</span>
                          <span className="text-muted-foreground">{milestone.label}</span>
                        </li>
                      ))}
                    </ol>
                  </div>
                ))}
              </div>
              <p className="mt-4 text-xs text-muted-foreground">
                Every date is a shipped fix or a completed measurement run, sourced from{' '}
                <a href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`} target="_blank" rel="noopener noreferrer" className="text-primary underline underline-offset-2">CLIENT_BAKEOFF_RESULTS.md</a>
                {' '}and the repo&apos;s merged-PR history &mdash; not reconstructed from memory.
              </p>
            </Details>
          </div>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="at-a-glance" className="text-lg sm:text-xl font-semibold text-foreground">What broke</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Four incidents changed client verdicts. The issues log records fourteen client-level problems across triage and full sync.
            The table covers those four.
          </p>
          <RestartGapFigure />
          <div
            className="mt-4 sm:mt-6 hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
            role="region"
            aria-label="Client incidents table"
            tabIndex={0}
          >
            <table className="w-full min-w-[52rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">Client</th>
                  <th className="pb-3 font-medium text-muted-foreground">What happened</th>
                  <th className="pb-3 font-medium text-muted-foreground">Root cause</th>
                  <th className="pb-3 font-medium text-muted-foreground">Resolution</th>
                  <th className="pb-3 font-medium text-muted-foreground">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {clientIncidents.map((incident) => (
                  <tr key={incident.client}>
                    <td className="py-3 align-top font-medium text-foreground">{incident.client}</td>
                    <td className="py-3 align-top text-muted-foreground">{incident.whatHappened}</td>
                    <td className="py-3 align-top text-muted-foreground">{incident.rootCause}</td>
                    <td className="py-3 align-top text-muted-foreground">{incident.resolution}</td>
                    <td className="py-3 align-top">
                      <StatusPill label={incident.status} tone={incident.tone} />
                      <p className="mt-1 text-xs text-muted-foreground">{incident.statusNote}</p>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            {clientIncidents.map((incident) => (
              <div key={incident.client} className="rounded-lg border border-border p-3">
                <div className="flex items-center justify-between gap-3">
                  <span className="font-medium text-foreground">{incident.client}</span>
                  <StatusPill label={incident.status} tone={incident.tone} />
                </div>
                <p className="mt-1 text-xs text-muted-foreground">{incident.statusNote}</p>
                <p className="mt-2 text-sm text-muted-foreground">{incident.whatHappened}</p>
                <p className="mt-2 text-xs text-muted-foreground"><span className="font-medium">Root cause:</span> {incident.rootCause}</p>
                <p className="mt-1 text-xs text-muted-foreground"><span className="font-medium">Resolution:</span> {incident.resolution}</p>
              </div>
            ))}
          </div>

          <div className="mt-8">
            <AnchorHeading id="durable-control-loop" as="h3" className="font-medium text-foreground">
              The durable control loop
            </AnchorHeading>
            <figure
              className="mt-4 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
              aria-label="A human operator approves destructive steps; a Claude orchestrator starts and resumes runs; a detached tmux driver runs the bake-off harness, which drives systemd execution and consensus services and writes samples, verdicts, and run artifacts; those collapse into small durable state — results, queue, and handoff — which a fresh orchestrating session reads to recover context."
            >
              <FlowDiagram
                steps={controlLoopSteps}
                loopBackTo={controlLoopSteps[1]}
                loopLabel="fresh session recovers context"
              />
              <figcaption className="mt-3 text-xs text-muted-foreground">
                A fresh session resumes from small state files without reconstructing runs from raw logs.
              </figcaption>
            </figure>
          </div>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="shape-of-the-problem" className="text-lg sm:text-xl font-semibold text-foreground">The shape of the problem</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Sync benchmarks are slow, sequential, easy to misread, and destructive.
          </p>
          <div className="mt-4 grid gap-3 sm:gap-4 md:grid-cols-2">
            {shapePoints.map((point) => (
              <Card key={point.lead} padding="sm" className="bg-muted/30">
                <h3 className="font-medium text-foreground">{point.lead}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{point.body}</p>
              </Card>
            ))}
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            The challenge is <em>sustained correctness</em>: repeat the protocol dozens of times across all supported clients.
            Preserve final measurements before teardown. Separate shared-host quirks from client properties.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="orchestration-model" className="text-lg sm:text-xl font-semibold text-foreground">The orchestration model</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Run nodes independently of agent sessions. Store durable state outside agent context.
            Extending the campaign to six weeks needed more state entries, not a different design or sustained attention.
          </p>
          <ThreeClocksFigure />

          <AnchorHeading id="node-runs-agent-doesnt-watch" as="h3" className="mt-6 font-medium text-foreground">
            1. The node runs; the agent doesn&apos;t watch it run
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Native systemd services <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth1.service</code> and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">cl.service</code> kept running after orchestrator sessions died.
            This happened more than once, including an out-of-memory event. The sampler continued; fresh sessions resumed from durable state without data loss.
          </p>

          <AnchorHeading id="three-tiers-of-agent" as="h3" className="mt-6 font-medium text-foreground">
            2. Three tiers of agent, by cost and by role
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Builders save the strongest model&apos;s context. A different model provides independent review.
          </p>
          <AgentHierarchy />
          <Details summary="Full tier table — who each tier was, and what it did" className="mt-4">
            <div
              className="hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
              role="region"
              aria-label="Agent tiers table"
              tabIndex={0}
            >
              <table className="w-full min-w-[44rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
                <thead>
                  <tr className="border-b border-border text-left">
                    <th className="pb-3 font-medium text-muted-foreground">Role</th>
                    <th className="pb-3 font-medium text-muted-foreground">Who</th>
                    <th className="pb-3 font-medium text-muted-foreground">What they did</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {agentTiers.map((tier) => (
                    <tr key={tier.role}>
                      <td className="py-3 align-top font-medium text-foreground">{tier.role}</td>
                      <td className="py-3 align-top text-muted-foreground">{tier.who}</td>
                      <td className="py-3 align-top text-muted-foreground">{tier.what}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="space-y-3 sm:hidden">
              {agentTiers.map((tier) => (
                <div key={tier.role} className="rounded-lg border border-border p-3">
                  <p className="font-medium text-foreground">{tier.role}</p>
                  <p className="mt-1 text-xs text-muted-foreground">{tier.who}</p>
                  <p className="mt-2 text-sm text-muted-foreground">{tier.what}</p>
                </div>
              ))}
            </div>
          </Details>
          <p className="mt-3 text-sm text-muted-foreground">
            Builder subagents implemented the reth archive-default fix and six config-gate corrections under orchestrator review.
            Because it had never seen the reasoning that produced them, Codex caught defects that review missed.
          </p>

          <AnchorHeading id="durable-state-backbone" as="h3" className="mt-6 font-medium text-foreground">
            3. Durable state is the backbone
          </AnchorHeading>
          {/* The context-window-is-the-bottleneck claim is made by ThreeClocksFigure above;
              restating it here as a pull-quote was duplication, so this leads with the fix. */}
          <p className="mt-3 text-sm text-muted-foreground">
            Small files and disposable investigations keep orchestrator context available.
          </p>
          <LeadList items={durableStatePoints} />
          <VerdictDiagram />
          <p className="mt-3 text-xs text-muted-foreground">
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_is_synced()</code> combines <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">sync_distance</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">is_optimistic</code>, and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">el_offline</code>.
            These are the implemented checks, not a peer-aware state machine. They do not trust <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_syncing=false</code> alone. They never check peer count. The stall-watchdog is opt-in.
          </p>
          <p className="mt-2 text-xs text-muted-foreground">
            nethermind&apos;s 13.3h loopback stall predates the watchdog. The harness never falsely reported sync, but could not distinguish <em>stuck</em> from <em>still syncing</em>.
            That gap prompted the watchdog.
          </p>

          <AnchorHeading id="governance" as="h3" className="mt-6 font-medium text-foreground">
            4. Governance the agent could not override
          </AnchorHeading>
          <GovernanceFence />
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="the-harness" className="text-lg sm:text-xl font-semibold text-foreground">The harness</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            The measurement machinery lives in{' '}
            <a href={`${SITE_CONFIG.github}/tree/master/test/bakeoff`} target="_blank" rel="noopener noreferrer" className="text-primary underline underline-offset-2">
              test/bakeoff
            </a>
            : plain bash, ~1,550 lines across eight scripts. No extra runtime can drift beneath a systemd service.
            See <a href="/blog/bakeoff-harness" className="text-primary underline underline-offset-2">the bake-off harness post</a> for the function-by-function breakdown.
            Here are the parts that shaped the campaign.
          </p>

          <div className="mt-6">
            <AnchorHeading id="harness-pipeline" as="h3" className="font-medium text-foreground">
              The harness pipeline
            </AnchorHeading>
            <figure
              className="mt-4 rounded-xl border border-border bg-muted/30 p-4 sm:p-6"
              aria-label="The candidate manifest feeds run_bakeoff.sh, which walks one candidate at a time. run_candidate.sh hard-resets shared services, installs, and applies resource caps, then runs a sampling loop to a verdict of synced, capped, stalled, or install error. Disk is snapshotted before teardown, and summarize.sh turns the artifacts into the results table."
            >
              <FlowDiagram steps={harnessPipelineSteps} />
              <figcaption className="mt-3 text-xs text-muted-foreground">
                Five stages take each candidate from the test manifest to the results table.
              </figcaption>
            </figure>
            <Details
              summary={`The ${harnessScripts.length} core scripts — what each one owns`}
              className="mt-4"
            >
              <ul className="space-y-2 text-sm text-muted-foreground">
                {harnessScripts.map((script) => (
                  <li key={script.name}>
                    <a href={`${SITE_CONFIG.github}/blob/master/${script.path}`} target="_blank" rel="noopener noreferrer" className="font-mono text-xs text-primary underline underline-offset-2">
                      {script.name}
                    </a>
                    {' '}&mdash; {script.desc}
                  </li>
                ))}
              </ul>
            </Details>
          </div>

          <AnchorHeading id="config-optimality-gate" as="h3" className="mt-8 font-medium text-foreground">
            The config-optimality gate, and why it needed six bug-fixes
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Check the running configuration before trusting disk measurements. We corrupted early results by skipping this check.
            reth defaults to a ~2.8 TiB archive node; pruned mode
            (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--full</code>) projects to ~1.2 TiB.
            We nearly recorded the archive size as &ldquo;reth&apos;s footprint&rdquo;. A benchmark of your own misconfiguration is worse than no benchmark: it looks authoritative.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            The config-optimality gate checks the running config and stamps rows <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=yes|no</code>.
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code> quarantines non-optimal rows as &ldquo;superseded&rdquo;.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            We trusted the gate after six bug-fixes across three review rounds. Each assertion mismatched the generated config:
            the same failure the gate was built to catch.
          </p>

          <AnchorHeading id="anchor-preserving-mode" as="h3" className="mt-6 font-medium text-foreground">
            Anchor-preserving mode: don&apos;t re-sync the world five times
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Anchor-preserving mode tests five consensus clients with one execution-client sync, avoiding five full EL re-syncs.
            It keeps the synced EL running, cycles only the CL service per candidate, and purges the consensus datadir between runs.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Three sweeps, against ethrex, geth, and nethermind anchors, empirically confirmed EL/CL decoupling.
            All reproduced the same tiers; within-tier order changed.
          </p>
          <ConsensusTiersFigure />
          <LeadList items={anchorInstabilityPoints} />
          <p className="mt-3 text-sm text-muted-foreground">
            Within-tier order tracks the measurement window more than the client. No client changed tiers.
          </p>
          <Details summary="Two harness-fidelity caveats from the nethermind-anchor sweep" className="mt-4">
            <LeadList items={anchorCaveatPoints} />
          </Details>

          <AnchorHeading id="two-harness-bugs" as="h3" className="mt-8 font-medium text-foreground">
            Two harness bugs that nearly cost us data
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Unattended runs exposed two harness bugs beyond the four client incidents: a stopped shell and a lost snapshot.
          </p>
          <div className="mt-4 grid gap-3 sm:gap-4 md:grid-cols-2">
            {harnessBugs.map((bug) => (
              <Card key={bug.title} padding="sm" className="bg-muted/30">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h4 className="font-medium text-foreground">{bug.title}</h4>
                  <StatusPill label={bug.cost} tone="bad" />
                </div>
                <p className="mt-2 text-sm text-muted-foreground">{bug.what}</p>
                <p className="mt-2 text-sm text-muted-foreground">
                  <span className="font-medium text-foreground">Fix:</span> {bug.fix}
                </p>
              </Card>
            ))}
          </div>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="next-person" className="text-lg sm:text-xl font-semibold text-foreground">What we&apos;d tell the next person</AnchorHeading>
          <div className="mt-4 grid gap-3 sm:gap-4 md:grid-cols-2">
            {nextPersonPoints.map((point) => (
              <Card key={point.lead} padding="sm" className="bg-muted/30">
                <h3 className="font-medium text-foreground">{point.lead}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{point.body}</p>
              </Card>
            ))}
          </div>
          <AnchorHeading id="honest-limitations" as="h3" className="mt-8 font-medium text-foreground">
            Honest limitations
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Shared-host contention limits these measurements. The semi-production host had 12 cores, ~62 GB RAM, and co-resident workloads.
            That reflects many real node setups, but cannot fully isolate contention. Each client had one run at a pinned version:
            a data point, not a distribution or lab result.
          </p>
          <p className="mt-2 text-sm text-muted-foreground">
            An agent driving a shared host can destroy what it measures with one wrong wipe argument. Wrong numbers look right until checked.
            Those risks made the governance fence mandatory.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="bottom-line" className="text-lg sm:text-xl font-semibold text-foreground">Bottom line</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            An agent can run this multi-week, disk-and-timing-sensitive benchmark unattended with three safeguards:
          </p>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-muted-foreground">
            <li>Node time independent of agent time.</li>
            <li>Conclusions in small durable files, outside context.</li>
            <li>Human approval for irreversible steps.</li>
          </ul>
          <p className="mt-2 text-sm text-muted-foreground">
            Process, not greater Ethereum expertise, preserved the measurements and supports the client verdicts.
            It survived session deaths, context clears, config-gate bugs, SIGTTIN, and the cap-path snapshot bug.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="reproduce-it" className="text-lg sm:text-xl font-semibold text-foreground">Reproduce it</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">The harness is in the repo and the data is committed:</p>
          <div className="mt-4 flex flex-wrap gap-3">
            {reproduceLinks.map((link) => (
              <Button key={link.href} href={link.href} external variant="secondary" size="sm">
                {link.label}
              </Button>
            ))}
          </div>
        </section>

        <ReadNext currentSlug="how-we-tested-with-claude" />

        <Card padding="sm" className="mt-10 sm:mt-16 bg-muted/30">
          <p className="text-xs text-muted-foreground">
            <span className="font-medium text-foreground">Sources:</span> this page is adapted from{' '}
            <a
              href={`${SITE_CONFIG.github}/blob/master/docs/HOW_WE_TESTED_WITH_CLAUDE.md`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary hover:underline"
            >
              docs/HOW_WE_TESTED_WITH_CLAUDE.md
            </a>{' '}
            on GitHub, with every measured figure cross-checked against{' '}
            <a
              href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary hover:underline"
            >
              CLIENT_BAKEOFF_RESULTS.md
            </a>
            .
          </p>
        </Card>
      </div>
      <BackToTop />
    </div>
  )
}
