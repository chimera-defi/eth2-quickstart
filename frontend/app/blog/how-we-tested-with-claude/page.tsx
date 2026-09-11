import type { Metadata } from 'next'
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
import { ArrowDown, ArrowRight, ArrowUp } from 'lucide-react'

export const metadata: Metadata = buildArticleMetadata('how-we-tested-with-claude')

const tocLinks = [
  { label: 'TL;DR', href: '#tldr' },
  { label: 'The plan', href: '#the-plan' },
  { label: 'At a glance', href: '#at-a-glance' },
  { label: 'The shape of the problem', href: '#shape-of-the-problem' },
  { label: 'The orchestration model', href: '#orchestration-model' },
  { label: 'The harness', href: '#the-harness' },
  { label: "What we'd tell the next person", href: '#next-person' },
  { label: 'Bottom line', href: '#bottom-line' },
  { label: 'Reproduce it', href: '#reproduce-it' },
]

const tldrPoints = [
  {
    title: 'Two clocks, and a third that binds first',
    body: 'Node wall-clock (detached systemd) and agent wall-clock (event-driven wakeups) are the obvious bottlenecks. The real one is agent context — solved by pushing conclusions down to the data and keeping durable state in small files.',
  },
  {
    title: 'Three-tier agent hierarchy for context economy',
    body: 'Opus orchestrator (plans, reviews every diff) → fresh Sonnet builders (implement, report back a summary) → delegate models (cheap and sandboxed work).',
  },
  {
    title: 'Non-negotiable governance, not vibes',
    body: 'One candidate at a time, a 72-hour cap, destructive actions gated behind explicit human confirmation, only a human merges. The prune experiment wiped a synced 1.1 TiB node only after an explicit go-ahead, then put the measured nethermind minimal-history default up as a PR for a human to review and merge — the agent never merged it.',
  },
  {
    title: 'The headline numbers hide operational limits',
    body: "ethrex is the fastest cold-sync in the field but is not production-ready as tested: a 26-minute/132-block restart gap stalled, and longer measured gaps caused a full re-snap. Its datadir plateaus at ~470–476 GiB, but that's not a disk win — it's a no-history node. besu synced successfully; its pruned re-run exposed fragility after a prolonged outage of the pinned Prysm version.",
  },
]

const planCards = [
  {
    title: 'What',
    body: 'Two numbers for each client that finished syncing: final synced disk footprint and cold-sync duration. Seven execution clients ran against a fixed Prysm (three never finished — erigon deadlocked, reth and nimbus_eth1 hit the 72h cap), then a five-way consensus sweep against a fixed execution client.',
  },
  {
    title: 'How',
    body: 'Native systemd services, no Docker, one candidate at a time on a shared 12-core / ~62 GB host, each run capped at 72 hours.',
  },
  {
    title: 'When',
    body: 'A 23-day initial campaign (Jun 22 → Jul 14, 2026), then a steady-state re-measure and restart-resume follow-ons through Aug 4 — six weeks end to end.',
  },
]

// Every date is a shipped fix or completed measurement run, cross-checked against
// CLIENT_BAKEOFF_RESULTS.md and the repo's merged-PR history — none invented or approximated.
// The flat date list is grouped into three phases; every milestone is preserved.
const campaignPhases = [
  {
    name: 'Phase 1 — Initial measurement campaign',
    range: 'Jun 22 → Jul 14, 2026',
    note: '23 days',
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
    range: 'Jul 26 → Jul 29, 2026',
    note: 'footprints settled',
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
    range: 'Jul 31 → Aug 4, 2026',
    note: 'no restart cliff found',
    summary:
      'Restart-resume experiments, the minimal-history prune default, and shipping it as a human-reviewed PR.',
    milestones: [
      { date: '2026-07-31', label: 'Nethermind fresh re-sync in 1h53m (establish run)' },
      { date: '2026-08-01', label: 'Steady-state re-measure: nethermind full-history datadir ~1.06 TiB' },
      { date: '2026-08-01', label: 'Nethermind resumes a 10,607-block gap in 35 min — restart-resume measured' },
      { date: '2026-08-03', label: 'Bisection finds no cliff at any gap (12 min → ~35h); prysm clean-resume measured, n=4' },
      { date: '2026-08-03', label: 'Nethermind prune tuning produces a minimal-history default (~250–280 GiB, no-history tier), measured and shipped as a human-reviewed PR' },
      { date: '2026-08-04', label: 'Minimal-history default merged to master, live on eth2quickstart.com' },
    ],
  },
]

const clientIncidents = [
  {
    client: 'nethermind',
    whatHappened: '13.3h silent stall — head frozen at block 4,651, 0 peers, everything else looked healthy',
    rootCause: 'P2P bind pinned to loopback (Network.LocalIp=127.0.0.1)',
    resolution: 'Advertise the real external IP',
    status: 'Fixed',
    statusNote: 'production-viable — restart-resume measured 2026-08-01',
    variant: 'primary' as const,
  },
  {
    client: 'besu',
    whatHappened: 'Mid-sync deadlock — downloader thread died, process stayed alive and kept answering RPC',
    rootCause: 'Stale pinned CL (prysm v7.1.5) stalled the beacon ~28h; snap-sync pivot aged out of the ~25-min servable-state window',
    resolution: 'None available (upstream CL issue) — keep CL binaries current; harness gained a stall-watchdog',
    status: 'Fragile',
    statusNote: 'to a prolonged CL outage',
    variant: 'default' as const,
  },
  {
    client: 'ethrex',
    whatHappened: 'Gaps through 23 min / 124 blocks resumed; a 26 min / 132 block gap stalled, and measured 1.5–2h gaps discarded state and re-snapped (~2h). The un-pruned datadir plateaus at ~470–476 GiB (drifting 470.2 → 475.5 GiB over ~42h) — settled, but a no-history node, not a disk win',
    rootCause: 'Old head ages out of the ~128-block servable-state window; beyond it the head can freeze and longer gaps can trigger a full snap instead of importing the gap',
    resolution: 'None — inherent to current design (v19.0.0)',
    status: 'Not production-ready',
    statusNote: 'as tested — young client, may improve',
    variant: 'default' as const,
  },
  {
    client: 'erigon',
    whatHappened: 'Head froze a few thousand blocks behind tip; consensus stayed is_optimistic=true indefinitely',
    rootCause: 'Genuine gap-close deadlock, erigon3 OtterSync vs. checkpoint-synced Prysm — not resource starvation',
    resolution: 'None — terminated per operator decision, recorded as a no-sync',
    status: 'No-sync',
    statusNote: 'on this host/CL combination',
    variant: 'default' as const,
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
    lead: "It's slow.",
    body: 'A single mainnet sync ranges from ~2 hours (ethrex, snap) to never finishes in three days (the full-sync-only clients). Each candidate got a 72-hour cap.',
  },
  {
    lead: "It's sequential.",
    body: 'One shared host, one execution slot, one consensus slot — geth and nethermind side by side would contend for CPU, IO, and peers, so candidates run strictly one at a time.',
  },
  {
    lead: "It's easy to measure the wrong thing.",
    body: 'A client that "installed and followed the chain" can be silently broken (0 peers, frozen head); a datadir number means nothing if the client was running in archive mode; a footprint sampled mid-compaction over-counts.',
  },
  {
    lead: "It's destructive.",
    body: "Measuring the next client means wiping the last one's datadir on a shared box that also runs other people's work.",
  },
]

// What's actually implemented (test/bakeoff/lib.sh, run_candidate.sh) — no peer-count check
// anywhere; the stall-watchdog tracks one flat no-progress streak and is opt-in. STALLED is
// reachable only through RESTARTING, never directly from SYNCING — VerdictDiagram below renders
// it nested under RESTARTING (not as a same-level fan-out) to keep that chain honest.
const verdictOutcomes = [
  { name: 'SYNCED', trigger: '2 consecutive clean samples', variant: 'primary' as const },
  { name: 'CAPPED', trigger: 'window elapses, still not synced', variant: 'default' as const },
  { name: 'RESTARTING', trigger: 'no-progress streak hits threshold (opt-in watchdog) — loops back to SYNCING, or falls through to STALLED if the restart budget runs out', variant: 'default' as const },
]

// A real, distinct terminal state (docs/CLIENT_BAKEOFF_HARNESS.md §3.5): a `.stalled` marker
// file / `stall_failed=yes` once the bounded restart budget is exhausted. Nethermind's earlier
// 13.3h 0-peer stall predates this watchdog and motivated adding it.
const stalledOutcome = {
  name: 'STALLED',
  trigger: 'restart budget exhausted (opt-in stall-watchdog) after block number or head slot fails to advance; the harness flags the row instead of spinning to the 72-hour cap',
  variant: 'default' as const,
}

const durableStatePoints = [
  {
    lead: 'Push conclusions down to where the data lives.',
    body: 'Each sample collapses to a couple of flags in env.txt — fully_synced=yes after two consecutive clean samples, or (with the stall-watchdog armed) .stalled once bounded restarts are exhausted — so the agent reads a file, not a log.',
  },
  {
    lead: 'Keep durable state small and in files.',
    body: 'Results, governance rules, the queue, and a live self-handoff note live in a handful of markdown files — a mid-campaign context clear becomes a non-event.',
  },
  {
    lead: 'Keep transient investigation off the context path.',
    body: 'Logs, probes, and sample dumps are ephemeral: computed, summarized, dropped — never carried.',
  },
]

const governancePoints = [
  {
    lead: 'One candidate at a time. No batching.',
    body: 'Ever.',
  },
  {
    lead: '72-hour cap',
    body: "per candidate; footprint is the last sample before teardown — at sync for a synced client, at the cap for a capped one — never the peak. On-disk size oscillates during compaction: reth's max sample read 1.06 TiB against the ~0.98 TiB captured at the 72h cap.",
  },
  {
    lead: 'Destructive data-cleans are gated',
    body: 'behind explicit confirmation, and wiping the live shared node always required a fresh human go-ahead.',
  },
  {
    lead: 'Conventional Commits, new commits only,',
    body: 'never a force-push to master; secrets stayed in protected local files and were never committed or exposed to agent context.',
  },
  {
    lead: 'An agent cannot merge its own pull request.',
    body: 'A human does that.',
  },
]

const harnessPipelineSteps = [
  'Candidate manifest → run_bakeoff.sh (walks one candidate at a time)',
  'run_candidate.sh: hard-reset shared services → install → apply resource caps',
  'run_candidate.sh sampling loop → verdict (SYNCED / CAPPED / STALLED / install error)',
  'Snapshot disk, before teardown',
  'summarize.sh → results table',
]

const agentTiers = [
  {
    role: 'Orchestrator / reviewer',
    who: 'Claude Opus 4.8',
    what: 'Planned the queue, made the judgment calls, reviewed every diff, wrote the durable state. Did not hand-write most client code.',
  },
  {
    role: 'Builders',
    who: 'fresh Claude Sonnet subagents',
    what: "Implemented fixes against a written brief, reported a short summary back — keeping the bulk of the tokens out of the orchestrator's context.",
  },
  {
    role: 'Delegates',
    who: 'cheaper / sandboxed models',
    what: 'Cheap read-only research and review, and any sandboxed work, routed through wrapper binaries with auth, fallback, and telemetry.',
  },
]

const harnessScripts = [
  { name: 'run_bakeoff.sh', path: 'test/bakeoff/run_bakeoff.sh', desc: 'sequential orchestrator with a resume guard: a killed campaign restarts where it left off, never re-runs finished candidates.' },
  { name: 'run_candidate.sh', path: 'test/bakeoff/run_candidate.sh', desc: 'single-candidate runner: reset → install → cap → sample. Owns the observation loop and captures a final footprint on synced, capped, stalled, and install-error paths before teardown. Preflight aborts such as insufficient disk exit before sampling starts.' },
  { name: 'lib.sh', path: 'test/bakeoff/lib.sh', desc: 'shared probe/sample library: sync probes, the sample writer, the disk snapshotter, and the config-optimality gate.' },
  { name: 'apply_resource_caps.sh', path: 'test/bakeoff/apply_resource_caps.sh', desc: "systemd CPUQuota/MemoryMax caps so a heavy sync can't starve co-resident workloads on the shared host." },
  { name: 'summarize.sh', path: 'test/bakeoff/summarize.sh', desc: 'turns per-run artifacts into the results table, split by whether the config was verified optimal.' },
  { name: 'run_anchor_rotation.sh', path: 'test/bakeoff/run_anchor_rotation.sh', desc: 'the anchor-preserving mode used for the consensus-client sweep.' },
]

const anchorInstabilityPoints = [
  {
    lead: 'lodestar ↔ lighthouse flipped between anchors:',
    body: 'geth: lodestar < lighthouse; ethrex: lighthouse < lodestar.',
  },
  {
    lead: 'teku swung ~27% on the same anchor:',
    body: '~667 MiB, then ~848 MiB on a clean re-read of the nethermind anchor — enough to flip it from below grandine (~730 MiB) to above it.',
  },
]

const anchorCaveatPoints = [
  {
    lead: "lodestar's first run was a measurement artifact.",
    body: 'It started while the anchor EL was still closing an unrelated block gap, inflating its recorded sync time to ~76 minutes versus ~10 for the other four. We discarded it for a clean re-read (~7m36s, ~178 MiB).',
  },
  {
    lead: "teku's run tripped a false positive.",
    body: 'The watchdog flagged it anchor_synced=no even though the anchor was independently verified healthy — a false positive in the check, not in the anchor.',
  },
]

const harnessBugPoints = [
  {
    lead: 'The detached-shell landmine (SIGTTIN).',
    body: "An install step shelled out to geth version | head -1 to log the binary version. Run from a detached tmux session in a non-foreground process group, that read raised SIGTTIN against a tty it didn't own — which stops (not kills) the whole subtree — and hung a run for 90 minutes. Fix: redirect stdin from /dev/null on unattended invocations.",
  },
  {
    lead: 'The measurement that vanished at the cap.',
    body: "The disk snapshot was taken only on the synced success branch. When a slow client hit the 72-hour cap, the script fell through to teardown — which wiped the datadir — and snapshotted after. Fix: snapshot every terminal run path after installation and before teardown; preflight aborts still exit before sampling. The cap path is the one you forget, and it's the one a slow client actually takes.",
  },
]

const nextPersonPoints = [
  {
    lead: 'The third clock is the real limit.',
    body: 'Node wall-clock and agent wall-clock are solvable with infrastructure; agent context only scales if you push conclusions to the data and keep durable state in small files.',
  },
  {
    lead: 'Measure on every exit path, before you destroy anything.',
    body: 'Success is the easy path. The cap and the error paths are where your data quietly disappears.',
  },
  {
    lead: 'Gate your benchmark on config, not just on outcome.',
    body: 'Stamp every number with "was this the client’s best mode?" or you will eventually publish a measurement of your own mistake.',
  },
  {
    lead: 'Give an agent a job and a fence.',
    body: 'The agent owns the tedious, sustained correctness; the human owns the few irreversible levers.',
  },
]

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
    <div className="mt-4 flex flex-col items-stretch">
      {steps.map((step, index) => (
        <div key={step} className="flex flex-col items-center">
          <div className="w-full rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
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

function PhasedTimeline() {
  return (
    <div className="mt-4 space-y-4">
      {campaignPhases.map((phase) => (
        <div key={phase.name} className="rounded-lg border border-border bg-muted/20 p-4">
          <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
            <h4 className="font-medium text-foreground">{phase.name}</h4>
            <span className="font-mono text-xs text-primary">{phase.range}</span>
          </div>
          <p className="mt-1 text-sm text-muted-foreground">
            {phase.summary} <span className="text-foreground">({phase.note})</span>
          </p>
          <ol className="mt-3 space-y-1.5">
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
  )
}

function AgentHierarchy() {
  return (
    <div className="mt-4">
      <div className="mx-auto max-w-sm rounded-lg border border-primary/30 bg-primary/5 px-4 py-3 text-center text-sm text-foreground">
        Orchestrator / reviewer &mdash; Claude Opus 4.8
        <span className="block text-xs text-muted-foreground">plans, reviews every diff, writes durable state</span>
      </div>
      <ArrowDown className="mx-auto my-1.5 h-4 w-4 text-muted-foreground" aria-hidden="true" />
      <div className="grid gap-3 sm:grid-cols-3">
        <div className="rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
          Builder &mdash; fresh Sonnet subagent
          <span className="block text-xs text-muted-foreground">one task, reports a summary back</span>
        </div>
        <div className="rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
          Builder &mdash; fresh Sonnet subagent
          <span className="block text-xs text-muted-foreground">one task, reports a summary back</span>
        </div>
        <div className="rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
          Delegates &mdash; cheaper / sandboxed models
          <span className="block text-xs text-muted-foreground">cheap read-only work, routed via wrapper binaries</span>
        </div>
      </div>
      <div className="mx-auto mt-3 flex w-fit flex-col items-center gap-1 rounded-lg border border-dashed border-primary/40 bg-primary/5 px-3 py-1.5">
        <ArrowUp className="h-4 w-4 shrink-0 text-primary" aria-hidden="true" />
        <span className="text-xs text-muted-foreground">summary only, not full context &mdash; returns to the orchestrator</span>
      </div>
    </div>
  )
}

function VerdictDiagram() {
  return (
    <div className="mt-4">
      <div className="mx-auto max-w-xs rounded-lg border border-border bg-muted/30 px-4 py-2 text-center text-sm font-medium text-foreground">
        SYNCING
      </div>
      <ArrowDown className="mx-auto my-1.5 h-4 w-4 text-muted-foreground" aria-hidden="true" />
      <div className="grid gap-3 sm:grid-cols-3">
        {verdictOutcomes.map((outcome) => (
          <div key={outcome.name} className="flex flex-col items-center gap-1.5">
            <div className="w-full rounded-lg border border-border bg-muted/30 px-3 py-2 text-center">
              <Badge variant={outcome.variant}>{outcome.name}</Badge>
              <p className="mt-1.5 text-xs text-muted-foreground">{outcome.trigger}</p>
            </div>
            {outcome.name === 'RESTARTING' && (
              <>
                <ArrowDown className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden="true" />
                <div className="w-full rounded-lg border border-border bg-muted/30 px-3 py-2 text-center">
                  <Badge variant={stalledOutcome.variant}>{stalledOutcome.name}</Badge>
                  <p className="mt-1.5 text-xs text-muted-foreground">{stalledOutcome.trigger}</p>
                </div>
              </>
            )}
          </div>
        ))}
      </div>
    </div>
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
            The results post is about the clients. This one is about the machine that tested them: the
            agent orchestration model, the harness that kept us honest, and what actually breaks when a
            benchmark runs for six weeks on a shared host with an AI in the driver&apos;s seat.
          </p>
          <div className="mt-4 flex flex-wrap gap-3 sm:mt-6">
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
            This was AI-<em>driven</em>, not AI-<em>unsupervised</em>. Every destructive action against
            the live node was gated behind an explicit human confirmation, every result was committed
            under conventional-commit review, and no agent could merge its own pull request. The claim
            isn&apos;t &ldquo;the AI did it alone&rdquo; &mdash; it&apos;s that the right division of
            labor between an agent and an operator let a disk-and-timing-sensitive benchmark run to
            completion without a person watching it sync.
          </p>
        </Card>

        <ArticleToc links={tocLinks} />

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="tldr" className="text-lg sm:text-xl font-semibold text-foreground">TL;DR</AnchorHeading>
          <div className="mt-4 grid gap-3 sm:gap-4 md:grid-cols-2">
            {tldrPoints.map((point) => (
              <Card key={point.title} padding="sm" className="bg-muted/30">
                <h3 className="font-medium text-foreground">{point.title}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{point.body}</p>
              </Card>
            ))}
          </div>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="the-plan" className="text-lg sm:text-xl font-semibold text-foreground">The plan</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            One question, measured the same way for every client that finished &mdash; what, how, and
            when:
          </p>
          <div className="mt-4 grid gap-3 sm:gap-4 sm:grid-cols-3">
            {planCards.map((card) => (
              <Card key={card.title} padding="sm" className="bg-muted/30">
                <h3 className="font-medium text-foreground">{card.title}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{card.body}</p>
              </Card>
            ))}
          </div>

          <div className="mt-8">
            <AnchorHeading id="campaign-timeline" as="h3" className="font-medium text-foreground">
              Six weeks, in three phases
            </AnchorHeading>
            <p className="mt-2 text-sm text-muted-foreground">
              Phase 1 was the 23-day initial campaign; Phases 2 and 3 are the steady-state and
              restart-resume follow-ons that extended it to six weeks &mdash; on the same host, with no
              change to the orchestration model.
            </p>
            <PhasedTimeline />
            <p className="mt-2 text-xs text-muted-foreground">
              Every date is a shipped fix or a completed measurement run, sourced from{' '}
              <a href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`} target="_blank" rel="noopener noreferrer" className="text-primary underline underline-offset-2">CLIENT_BAKEOFF_RESULTS.md</a>
              {' '}and the repo&apos;s merged-PR history &mdash; not reconstructed from memory.
            </p>
          </div>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="at-a-glance" className="text-lg sm:text-xl font-semibold text-foreground">At a glance</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Four incidents changed a client&apos;s verdict. They are not the whole list &mdash; the issues
            log records fourteen client-level problems across triage and full sync &mdash; but these four
            are the ones that moved a status.
          </p>
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
                      <Badge variant={incident.variant}>{incident.status}</Badge>
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
                  <Badge variant={incident.variant}>{incident.status}</Badge>
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
            <FlowDiagram
              steps={controlLoopSteps}
              loopBackTo={controlLoopSteps[1]}
              loopLabel="fresh session recovers context"
            />
            <p className="mt-2 text-xs text-muted-foreground">
              The artifacts carry the campaign forward: a new orchestrating session reads the small durable
              state instead of reconstructing a run from raw logs.
            </p>
          </div>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="shape-of-the-problem" className="text-lg sm:text-xl font-semibold text-foreground">The shape of the problem</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">Benchmarking a sync client is deceptively expensive:</p>
          <LeadList items={shapePoints} />
          <p className="mt-4 text-sm text-muted-foreground">
            Multiply that across the whole supported field of clients, and the real difficulty isn&apos;t
            any single hard step &mdash; it&apos;s <em>sustained correctness</em>: the discipline to run
            the same careful protocol dozens of times, preserve the terminal measurement before teardown,
            and never let a shared-host quirk masquerade as a client property.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="orchestration-model" className="text-lg sm:text-xl font-semibold text-foreground">The orchestration model</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            The core design choice: decouple node wall-clock from agent wall-clock, and decouple durable
            state from agent context. Get those two right and a multi-week campaign stops needing a
            multi-week attention span &mdash; extending it to six weeks meant more durable-state entries,
            not a different design.
          </p>

          <AnchorHeading id="node-runs-agent-doesnt-watch" as="h3" className="mt-6 font-medium text-foreground">
            1. The node runs; the agent doesn&apos;t watch it run
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Every client runs as a native systemd service (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth1.service</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">cl.service</code>, no Docker) in a detached tmux session &mdash; a sync proceeds for 72 hours whether or not any Claude session is alive. The orchestrating session did die mid-run more than once (once to an out-of-memory event); the systemd unit and its sampler kept going, and a fresh session picked the campaign back up from durable state with nothing lost.
          </p>
          <p className="mt-2 text-sm text-muted-foreground">
            Instead of polling logs, the agent armed event-driven watchers that fire one notification on a terminal condition, so the orchestrator slept until something decision-worthy happened.
          </p>

          <AnchorHeading id="three-tiers-of-agent" as="h3" className="mt-6 font-medium text-foreground">
            2. Three tiers of agent, by cost and capability
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">Not every sub-task deserves the strongest, most expensive model:</p>
          <AgentHierarchy />
          <div
            className="mt-4 hidden overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary sm:block"
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
          <div className="mt-4 space-y-3 sm:hidden">
            {agentTiers.map((tier) => (
              <div key={tier.role} className="rounded-lg border border-border p-3">
                <p className="font-medium text-foreground">{tier.role}</p>
                <p className="mt-1 text-xs text-muted-foreground">{tier.who}</p>
                <p className="mt-2 text-sm text-muted-foreground">{tier.what}</p>
              </div>
            ))}
          </div>
          <p className="mt-3 text-sm text-muted-foreground">
            The point is context economy. A builder subagent reads the client source, produces the commit,
            and returns a summary; the orchestrator holds the diff, not the investigation. The reth
            archive-default fix and the six config-gate corrections were all implemented this way, under
            orchestrator review.
          </p>

          <AnchorHeading id="durable-state-backbone" as="h3" className="mt-6 font-medium text-foreground">
            3. Durable state is the backbone
          </AnchorHeading>
          <Card padding="sm" className="mt-2 border-primary/20 bg-primary/5">
            <p className="text-sm text-foreground">
              The orchestrating agent&apos;s context window &mdash; not node wall-clock &mdash; is the real
              scaling bottleneck of a long agent-driven campaign.
            </p>
          </Card>
          <p className="mt-3 text-sm text-muted-foreground">
            The harness had already solved node time. But every status check, every &ldquo;is it
            stalled?&rdquo; pulled raw <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">journalctl</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">du</code>, and RPC output into the context window, and that filled up in hours, not weeks. The fix was architectural:
          </p>
          <LeadList items={durableStatePoints} />
          <VerdictDiagram />
          <p className="mt-3 text-xs text-muted-foreground">
            This is what&apos;s actually implemented, not a peer-aware state machine: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_is_synced()</code> checks <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">sync_distance</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">is_optimistic</code>, and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">el_offline</code> together &mdash; already enough to avoid trusting <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_syncing=false</code> alone &mdash; but there&apos;s no peer-count check anywhere, and the stall-watchdog is opt-in.
          </p>
          <p className="mt-2 text-xs text-muted-foreground">
            nethermind&apos;s 13.3h loopback stall (see the table above) predates the watchdog: the harness correctly never reported it synced, but nothing flagged the run as <em>stuck</em> rather than <em>still syncing</em> &mdash; that gap is exactly what motivated building the watchdog afterward.
          </p>

          <AnchorHeading id="governance" as="h3" className="mt-6 font-medium text-foreground">
            4. Governance the agent could not override
          </AnchorHeading>
          <LeadList items={governancePoints} />
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="the-harness" className="text-lg sm:text-xl font-semibold text-foreground">The harness</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            The measurement machinery lives in{' '}
            <a href={`${SITE_CONFIG.github}/tree/master/test/bakeoff`} target="_blank" rel="noopener noreferrer" className="text-primary underline underline-offset-2">
              test/bakeoff
            </a>
            . It&apos;s plain bash (~1,550 lines across eight scripts) &mdash; deliberately, so it has no runtime that can drift out from under a systemd service. The core scripts:
          </p>
          <ul className="mt-4 space-y-2 text-sm text-muted-foreground">
            {harnessScripts.map((script) => (
              <li key={script.name}>
                <a href={`${SITE_CONFIG.github}/blob/master/${script.path}`} target="_blank" rel="noopener noreferrer" className="font-mono text-xs text-primary underline underline-offset-2">
                  {script.name}
                </a>
                {' '}&mdash; {script.desc}
              </li>
            ))}
          </ul>
          <p className="mt-3 text-sm text-muted-foreground">
            The function-by-function breakdown &mdash; every script, flag, and watchdog &mdash; lives in{' '}
            <a href="/blog/bakeoff-harness" className="text-primary underline underline-offset-2">the bake-off harness post</a>. This section keeps to the parts that shaped how the campaign ran.
          </p>

          <div className="mt-8">
            <AnchorHeading id="harness-pipeline" as="h3" className="font-medium text-foreground">
              The harness pipeline
            </AnchorHeading>
            <FlowDiagram steps={harnessPipelineSteps} />
          </div>

          <AnchorHeading id="config-optimality-gate" as="h3" className="mt-8 font-medium text-foreground">
            The config-optimality gate, and why it needed six bug-fixes
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Early on we corrupted our own results by recording a footprint before confirming the client was
            in its most disk-efficient mode: reth at its defaults runs a ~2.8 TiB archive node, and we
            nearly recorded that as &ldquo;reth&apos;s footprint&rdquo; when the pruned number
            (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--full</code>) is ~1.2 TiB. A benchmark that measures your own misconfiguration is worse than no benchmark &mdash; it just looks authoritative.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            So the harness grew a config-optimality gate: before trusting a footprint, it inspects the
            actually-running config and stamps every row <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=yes|no</code>; <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code> quarantines non-optimal rows in a &ldquo;superseded&rdquo; section.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            The gate needed six bug-fixes across three review rounds before we trusted it &mdash; every one the same species (&ldquo;the flag I asserted on doesn&apos;t match the real generated config&rdquo;). That&apos;s the exact failure mode the gate exists to catch, turned on itself.
          </p>

          <AnchorHeading id="anchor-preserving-mode" as="h3" className="mt-6 font-medium text-foreground">
            Anchor-preserving mode: don&apos;t re-sync the world five times
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            The consensus-client matrix holds the execution client constant and cycles the CL. Naively
            that&apos;s five full EL re-syncs. Anchor-preserving mode keeps one already-synced execution
            client running and cycles only the CL service per candidate, purging just the consensus
            datadir between runs: five CL candidates, one EL sync.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            We ran the sweep three times &mdash; against an ethrex anchor, a geth anchor, and a nethermind
            anchor &mdash; to prove the EL/CL decoupling empirically. The same three tiers reproduced on
            all three anchors: a lightweight pair (lodestar, lighthouse), a mid pair (teku, grandine), and
            nimbus alone at the heavy end.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Within-tier order is soft, though &mdash; and that instability is itself the finding:
          </p>
          <LeadList items={anchorInstabilityPoints} />
          <p className="mt-3 text-sm text-muted-foreground">
            Each client stayed inside its own tier; the ordering within a tier tracks the measurement
            window more than the client. The nethermind-anchor sweep also surfaced two harness-fidelity
            caveats worth carrying forward:
          </p>
          <LeadList items={anchorCaveatPoints} />

          <AnchorHeading id="two-harness-bugs" as="h3" className="mt-6 font-medium text-foreground">
            Two harness bugs that nearly cost us data
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Beyond the four client incidents above, two bugs lived in the harness itself &mdash; the kind
            you only meet once automation runs unattended:
          </p>
          <LeadList items={harnessBugPoints} />
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="next-person" className="text-lg sm:text-xl font-semibold text-foreground">What we&apos;d tell the next person</AnchorHeading>
          <LeadList items={nextPersonPoints} />
          <AnchorHeading id="honest-limitations" as="h3" className="mt-6 font-medium text-foreground">
            Honest limitations
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            This is a real benchmark, not a lab result. It ran on a shared, semi-production host (12 cores,
            ~62 GB RAM, co-resident workloads) &mdash; representative of how many people actually run
            nodes, but with contention the numbers can&apos;t fully isolate. Each client was measured on
            one run at a pinned version, so a single result is a data point, not a distribution.
          </p>
          <p className="mt-2 text-sm text-muted-foreground">
            An agent driving a shared host can also destroy the thing it is measuring: the wipe that
            precedes each candidate is one wrong argument away from the wrong datadir, and a number that is
            wrong is indistinguishable from a number that is right until someone checks it. That is why the
            fence above was non-negotiable rather than advisory.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6">
          <AnchorHeading id="bottom-line" className="text-lg sm:text-xl font-semibold text-foreground">Bottom line</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            An agent can run a multi-week, disk-and-timing-sensitive benchmark
            unattended, but only because the design put its constraints in the right place &mdash; node
            time decoupled from agent time, conclusions pushed down into small durable files instead of
            carried in context, and every destructive or mergeable step routed through a human.
          </p>
          <p className="mt-2 text-sm text-muted-foreground">
            None of that made the agent smarter about Ethereum clients; it made the campaign survive
            session deaths, context clears, and its own mistakes (the config-optimality gate&apos;s
            bug-fixes, the harness&apos;s SIGTTIN and cap-path landmines) without losing the measurements
            that mattered. The client verdicts in the results write-up hold up because the process that
            produced them did.
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
      </div>
    </div>
  )
}
