import type { Metadata } from 'next'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { SITE_CONFIG } from '@/lib/constants'
import { ArrowDown, ArrowRight } from 'lucide-react'

export const metadata: Metadata = {
  title: 'How We Ran a 23-Day Ethereum Client Bake-off With Claude - ETH2 Quick Start',
  description:
    'The agent orchestration model, the harness, and what actually breaks when a benchmark runs for three weeks on a shared host with an AI in the driver’s seat.',
}

const tocLinks = [
  { label: 'TL;DR', href: '#tldr' },
  { label: 'At a glance', href: '#at-a-glance' },
  { label: 'The shape of the problem', href: '#shape-of-the-problem' },
  { label: 'The orchestration model', href: '#orchestration-model' },
  { label: 'The harness', href: '#the-harness' },
  { label: "What we'd tell the next person", href: '#next-person' },
  { label: 'Reproduce it', href: '#reproduce-it' },
]

const tldrPoints = [
  {
    title: 'Two clocks, then a third nobody expects',
    body: 'Node wall-clock (detached systemd) and agent wall-clock (event-driven wakeups) are the obvious bottlenecks. The real one is agent context — solved by pushing conclusions down to the data and keeping durable state in small files.',
  },
  {
    title: 'Three-tier agent hierarchy for context economy',
    body: 'Opus orchestrator (plans, reviews every diff) → fresh Sonnet builders (implement, report back a summary) → delegate models (cheap and sandboxed work).',
  },
  {
    title: 'Non-negotiable governance, not vibes',
    body: 'One candidate at a time, a 72-hour cap, destructive actions gated behind explicit human confirmation, only a human merges.',
  },
  {
    title: "Two clients aren't production-ready as measured here",
    body: 'ethrex is the fastest cold-sync in the field but re-syncs from scratch after any restart gap past ~25 minutes and its datadir grows unbounded; besu is fragile to a prolonged consensus-layer outage.',
  },
]

const clientIncidents = [
  {
    client: 'nethermind',
    whatHappened: '13.3h silent stall — head frozen at block 4,651, 0 peers, everything else looked healthy',
    rootCause: 'P2P bind pinned to loopback (Network.LocalIp=127.0.0.1)',
    resolution: 'Advertise the real external IP',
    status: 'Fixed',
    statusNote: 'production-viable',
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
    whatHappened: 'Restart with a gap past ~128 blocks (~24–25 min) discards all state, re-syncs from scratch (~2h); datadir also grows unbounded, un-pruned (~286 → ~467 GiB)',
    rootCause: 'Old head ages out of the ~128-block servable-state window; re-pivots to a full snap sync instead of importing the gap',
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

// Every date is a shipped fix or completed measurement run, cross-checked against
// CLIENT_BAKEOFF_RESULTS.md and the repo's merged-PR history — none invented or approximated.
const campaignTimeline = [
  { date: '2026-06-22', label: 'Campaign starts, Stage A triage begins' },
  { date: '2026-06-26', label: 'Stage-A installer fixes shipped' },
  { date: '2026-06-30', label: 'besu completes un-pruned sync' },
  { date: '2026-07-05', label: 'besu pruned re-run abandoned, deadlocked twice' },
  { date: '2026-07-06', label: 'CL sweep vs ethrex anchor, 5 CLs' },
  { date: '2026-07-08', label: 'CL cross-check vs geth anchor' },
  { date: '2026-07-10', label: 'ethrex restart-cliff bisected, geth 52h resume verified' },
  { date: '2026-07-12', label: 'Installer / config correctness fixes shipped' },
  { date: '2026-07-13', label: 'nimbus_eth1 72h capped run completes' },
  { date: '2026-07-14', label: 'Campaign ends, harness and results docs shipped' },
]

// What's actually implemented (test/bakeoff/lib.sh, run_candidate.sh) — no peer-count check
// anywhere; the stall-watchdog tracks one flat no-progress streak and is opt-in. STALLED is
// reachable only through RESTARTING, never directly from SYNCING — the component below reflects
// that chain rather than flattening it into a fan-out.
const verdictOutcomes = [
  { name: 'SYNCED', trigger: '2 consecutive clean samples', variant: 'primary' as const },
  { name: 'CAPPED', trigger: 'window elapses, still not synced', variant: 'default' as const },
  { name: 'RESTARTING', trigger: 'no-progress streak hits threshold (opt-in watchdog) — loops back to SYNCING, or falls through to STALLED if the restart budget runs out', variant: 'default' as const },
]

const harnessPipelineSteps = [
  'Candidate manifest → run_bakeoff.sh (walks one candidate at a time)',
  'run_candidate.sh: hard-reset shared services → install → apply resource caps',
  'lib.sh sampling loop → verdict (SYNCED / CAPPED / STALLED / error)',
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
  { name: 'run_candidate.sh', path: 'test/bakeoff/run_candidate.sh', desc: 'single-candidate runner: reset → install → cap → sample. Captures the measurement on every exit path — success, cap, error — always before the destructive teardown.' },
  { name: 'lib.sh', path: 'test/bakeoff/lib.sh', desc: 'shared probe/sample library: the sampling loop, the disk snapshotter, the config-optimality gate.' },
  { name: 'apply_resource_caps.sh', path: 'test/bakeoff/apply_resource_caps.sh', desc: "systemd CPUQuota/MemoryMax caps so a heavy sync can't starve co-resident workloads on the shared host." },
  { name: 'summarize.sh', path: 'test/bakeoff/summarize.sh', desc: 'turns per-run artifacts into the results table, split by whether the config was verified optimal.' },
  { name: 'run_anchor_rotation.sh', path: 'test/bakeoff/run_anchor_rotation.sh', desc: 'the anchor-preserving mode used for the consensus-client sweep.' },
]

const reproduceLinks = [
  { label: 'The harness', href: `${SITE_CONFIG.github}/tree/master/test/bakeoff` },
  { label: 'The harness, function-by-function', href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_HARNESS.md` },
  { label: 'The results', href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md` },
  { label: 'The narrative', href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_BLOG.md` },
  { label: 'The war stories', href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_ISSUES_LOG.md` },
  { label: 'Running a node for real', href: `${SITE_CONFIG.github}/blob/master/docs/blog/CLIENT_BAKEOFF_OPERATOR_GUIDE.md` },
]

function FlowDiagram({ steps }: { steps: string[] }) {
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
    </div>
  )
}

function AgentHierarchy() {
  return (
    <div className="mt-4">
      <div className="mx-auto max-w-sm rounded-lg border border-primary/30 bg-primary/5 px-4 py-3 text-center text-sm text-foreground">
        Orchestrator / reviewer — Claude Opus 4.8
        <span className="block text-xs text-muted-foreground">plans, reviews every diff, writes durable state</span>
      </div>
      <ArrowDown className="mx-auto my-1.5 h-4 w-4 text-muted-foreground" aria-hidden="true" />
      <div className="grid gap-3 sm:grid-cols-3">
        <div className="rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
          Builder — fresh Sonnet subagent
          <span className="block text-xs text-muted-foreground">one task, reports a summary back</span>
        </div>
        <div className="rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
          Builder — fresh Sonnet subagent
          <span className="block text-xs text-muted-foreground">one task, reports a summary back</span>
        </div>
        <div className="rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
          Delegates — cheaper / sandboxed models
          <span className="block text-xs text-muted-foreground">cheap read-only work, routed via wrapper binaries</span>
        </div>
      </div>
    </div>
  )
}

function CampaignTimeline() {
  return (
    <div className="mt-4 overflow-x-auto">
      <div className="flex gap-3 pb-2" style={{ minWidth: 'max-content' }}>
        {campaignTimeline.map((item) => (
          <div key={item.date} className="w-40 shrink-0 rounded-lg border border-border bg-muted/30 p-3">
            <p className="font-mono text-xs text-primary">{item.date}</p>
            <p className="mt-1 text-xs text-muted-foreground">{item.label}</p>
          </div>
        ))}
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
          <div key={outcome.name} className="rounded-lg border border-border bg-muted/30 px-3 py-2 text-center">
            <Badge variant={outcome.variant}>{outcome.name}</Badge>
            <p className="mt-1.5 text-xs text-muted-foreground">{outcome.trigger}</p>
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
        <header>
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Blog &middot; Companion to the bake-off writeup
          </p>
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            How we ran a 23-day Ethereum client bake-off with Claude
          </h1>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            That post was about the clients. This one is about the machine that tested them: the agent
            orchestration model, the harness we built to keep ourselves honest, and what actually breaks
            when a benchmark runs for three weeks on a shared host with an AI in the driver&apos;s seat.
          </p>
          <div className="mt-4 flex flex-wrap gap-3 sm:mt-6">
            <Button href="/blog/ethereum-client-bakeoff" variant="secondary" size="sm">
              Read the results writeup
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
          </div>
        </header>

        <Card padding="sm" className="mt-8 border-primary/20 bg-primary/5">
          <p className="text-sm text-foreground">
            <span className="font-medium">Up front, honestly:</span> this was AI-<em>driven</em>, not
            AI-<em>unsupervised</em>. Every destructive action against the live node was gated behind an
            explicit human confirmation, every result was committed under conventional-commit review, and
            no agent could merge its own pull request. The interesting claim here isn&apos;t &ldquo;the AI
            did it alone&rdquo; &mdash; it&apos;s that the right division of labor between an agent and an
            operator let a 23-day, disk-and-timing-sensitive benchmark run to completion without a person
            watching it sync.
          </p>
        </Card>

        <nav aria-label="Table of contents" className="mt-8 rounded-lg border border-border p-4 sm:p-5">
          <p className="font-mono text-xs text-muted-foreground uppercase tracking-wide">Contents</p>
          <ul className="mt-2 flex flex-wrap gap-x-5 gap-y-1.5 text-sm">
            {tocLinks.map((link) => (
              <li key={link.href}>
                <a href={link.href} className="text-primary hover:underline">
                  {link.label}
                </a>
              </li>
            ))}
          </ul>
        </nav>

        <section id="tldr" className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">TL;DR</h2>
          <div className="mt-4 grid gap-3 sm:gap-4 md:grid-cols-2">
            {tldrPoints.map((point) => (
              <Card key={point.title} padding="sm" className="bg-muted/30">
                <h3 className="font-medium text-foreground">{point.title}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{point.body}</p>
              </Card>
            ))}
          </div>
        </section>

        <section id="at-a-glance" className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">At a glance</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Four real incidents hit during the campaign, all fixed or explicitly documented.
          </p>
          <div className="mt-4 sm:mt-6 hidden sm:block overflow-x-auto">
            <table className="w-full text-sm">
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
            <h3 className="font-medium text-foreground">The durable control loop</h3>
            <FlowDiagram steps={controlLoopSteps} />
            <p className="mt-2 text-xs text-muted-foreground">
              The artifacts carry the campaign forward; a new orchestrating session reads the small
              durable state instead of reconstructing a run from raw logs &mdash; closing the loop back to
              the orchestrator.
            </p>
          </div>

          <div className="mt-8">
            <h3 className="font-medium text-foreground">23-day campaign — key dates</h3>
            <CampaignTimeline />
            <p className="mt-2 text-xs text-muted-foreground">
              Every date is a shipped fix or a completed measurement run, sourced from{' '}
              <a href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`} target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">CLIENT_BAKEOFF_RESULTS.md</a>
              {' '}and the repo&apos;s merged-PR history &mdash; not reconstructed from memory.
            </p>
          </div>
        </section>

        <section id="shape-of-the-problem" className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">The shape of the problem</h2>
          <p className="mt-2 text-sm text-muted-foreground">Benchmarking a sync client is deceptively expensive:</p>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
            <li><span className="font-medium text-foreground">It&apos;s slow.</span> A single mainnet sync ranges from ~2 hours (ethrex, snap) to never finishes in three days (the full-sync-only clients). Each candidate got a 72-hour cap.</li>
            <li><span className="font-medium text-foreground">It&apos;s sequential.</span> One shared host, one execution slot, one consensus slot &mdash; geth and nethermind side by side would contend for CPU, IO, and peers, so candidates run strictly one at a time.</li>
            <li><span className="font-medium text-foreground">It&apos;s easy to measure the wrong thing.</span> A client that &ldquo;installed and followed the chain&rdquo; can be silently broken (0 peers, frozen head); a datadir means nothing if it&apos;s running in archive mode; a footprint sampled mid-compaction over-counts.</li>
            <li><span className="font-medium text-foreground">It&apos;s destructive.</span> Measuring the next client means wiping the last one&apos;s datadir on a shared box that also runs other people&apos;s work.</li>
          </ul>
          <p className="mt-4 text-sm text-muted-foreground">
            Multiply that across the whole supported field of clients and three weeks and you have a task
            defined less by any single hard step than by <em>sustained correctness</em> &mdash; the
            discipline to run the same careful protocol dozens of times, capture the right sample on every
            exit path, and never let a shared-host quirk masquerade as a client property.
          </p>
        </section>

        <section id="orchestration-model" className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">The orchestration model</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            The core design choice: decouple node wall-clock from agent wall-clock, and decouple durable
            state from agent context. Get those two right and a three-week campaign stops needing a
            three-week attention span.
          </p>

          <h3 className="mt-6 font-medium text-foreground">1. The node runs; the agent doesn&apos;t watch it run</h3>
          <p className="mt-2 text-sm text-muted-foreground">
            Every client runs as a native systemd service (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth1.service</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">cl.service</code>, no Docker) in a detached tmux session &mdash; a sync proceeds for 72 hours whether or not any Claude session is alive. The orchestrating session did die mid-run more than once (once to an out-of-memory event); the systemd unit and its sampler kept going, and a fresh session picked the campaign back up from durable state with nothing lost. Instead of polling logs, the agent armed event-driven watchers that fire one notification on a terminal condition, so the orchestrator slept until something decision-worthy happened.
          </p>

          <h3 className="mt-6 font-medium text-foreground">2. Three tiers of agent, by cost and capability</h3>
          <p className="mt-2 text-sm text-muted-foreground">Not every sub-task deserves the strongest, most expensive model:</p>
          <AgentHierarchy />
          <div className="mt-4 hidden sm:block overflow-x-auto">
            <table className="w-full text-sm">
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
            The point is context economy. A builder subagent can read ten thousand lines of client source,
            produce a three-line commit, and return &ldquo;done, here&apos;s the diff&rdquo; &mdash; the
            orchestrator never has to hold those ten thousand lines. It reviews the diff, not the
            investigation.
          </p>

          <h3 className="mt-6 font-medium text-foreground">3. Durable state is the backbone</h3>
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
          <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
            <li><span className="font-medium text-foreground">Push conclusions down to where the data lives.</span> Each sample collapses to a couple of flags in <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">env.txt</code> &mdash; <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">fully_synced=yes</code> after two consecutive clean samples, or (with the stall-watchdog armed) <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.stalled</code> once bounded restarts are exhausted &mdash; so the agent reads a file, not a log.</li>
            <li><span className="font-medium text-foreground">Keep durable state small and in files.</span> Results, governance rules, the queue, and a live self-handoff note live in a handful of markdown files &mdash; a mid-campaign context clear becomes a non-event.</li>
            <li><span className="font-medium text-foreground">Keep transient investigation off the context path.</span> Logs, probes, and sample dumps are ephemeral: computed, summarized, dropped &mdash; never carried.</li>
          </ul>
          <VerdictDiagram />
          <p className="mt-3 text-xs text-muted-foreground">
            This is what&apos;s actually implemented, not a peer-aware state machine: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_is_synced()</code> checks <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">sync_distance</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">is_optimistic</code>, and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">el_offline</code> together &mdash; already enough to avoid trusting <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_syncing=false</code> alone &mdash; but there&apos;s no peer-count check anywhere, and the stall-watchdog is opt-in. nethermind&apos;s 13.3h loopback stall (see the table above) predates the watchdog: the harness correctly never reported it synced, but nothing flagged the run as <em>stuck</em> rather than <em>still syncing</em> &mdash; that gap is exactly what motivated building the watchdog afterward.
          </p>

          <h3 className="mt-6 font-medium text-foreground">4. Governance the agent could not override</h3>
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground">
            <li><span className="font-medium text-foreground">One candidate at a time. No batching.</span> Ever.</li>
            <li><span className="font-medium text-foreground">72-hour cap</span> per candidate; footprint is the last near-cap sample, never the peak.</li>
            <li><span className="font-medium text-foreground">Destructive data-cleans are gated</span> behind explicit confirmation, and wiping the live shared node always required a fresh human go-ahead.</li>
            <li><span className="font-medium text-foreground">Conventional Commits, new commits only</span>, never a force-push to master, secrets never written to disk or committed.</li>
            <li><span className="font-medium text-foreground">An agent cannot merge its own pull request.</span> A human does that.</li>
          </ul>
        </section>

        <section id="the-harness" className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">The harness</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            The measurement machinery lives in{' '}
            <a href={`${SITE_CONFIG.github}/tree/master/test/bakeoff`} target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">
              test/bakeoff
            </a>
            . It&apos;s plain bash &mdash; deliberately, so it has no runtime that can drift out from under a systemd service:
          </p>
          <ul className="mt-4 space-y-2 text-sm text-muted-foreground">
            {harnessScripts.map((script) => (
              <li key={script.name}>
                <a href={`${SITE_CONFIG.github}/blob/master/${script.path}`} target="_blank" rel="noopener noreferrer" className="font-mono text-xs text-primary hover:underline">
                  {script.name}
                </a>
                {' '}&mdash; {script.desc}
              </li>
            ))}
          </ul>

          <div className="mt-8">
            <h3 className="font-medium text-foreground">The harness pipeline</h3>
            <FlowDiagram steps={harnessPipelineSteps} />
          </div>

          <h3 className="mt-8 font-medium text-foreground">The config-optimality gate, and why it needed six bug-fixes</h3>
          <p className="mt-2 text-sm text-muted-foreground">
            Early on we corrupted our own results by recording a footprint before confirming the client was
            in its most disk-efficient mode: reth at its defaults runs a ~2.8 TiB archive node, and we
            nearly recorded that as &ldquo;reth&apos;s footprint&rdquo; when the pruned number
            (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--full</code>) is ~1.2 TiB. A benchmark that measures your own misconfiguration is worse than no benchmark &mdash; it just looks authoritative.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            So the harness grew a config-optimality gate: before trusting a footprint, it inspects the
            actually-running config and stamps every row <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=yes|no</code>; <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code> quarantines non-optimal rows in a &ldquo;superseded&rdquo; section. The gate needed six bug-fixes across three review rounds before we trusted it &mdash; every one the same species (&ldquo;the flag I asserted on doesn&apos;t match the real generated config&rdquo;) &mdash; the exact failure mode the gate exists to catch, turned on itself.
          </p>

          <h3 className="mt-6 font-medium text-foreground">Anchor-preserving mode: don&apos;t re-sync the world five times</h3>
          <p className="mt-2 text-sm text-muted-foreground">
            The consensus-client matrix holds the execution client constant and cycles the CL. Naively
            that&apos;s five full EL re-syncs. Anchor-preserving mode keeps one already-synced execution
            client running and cycles only the CL service per candidate, purging just the consensus
            datadir between runs: five CL candidates, one EL sync. We ran the sweep twice &mdash; against
            an ethrex anchor and a geth anchor &mdash; to prove the EL/CL decoupling empirically. The
            ranking reproduced.
          </p>

          <h3 className="mt-6 font-medium text-foreground">Two harness bugs that nearly cost us data</h3>
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground">
            <li><span className="font-medium text-foreground">The detached-shell landmine (SIGTTIN).</span> An install step shelled out to a version-check command. Run from a detached tmux session in a non-foreground process group, that read raised SIGTTIN against a tty it didn&apos;t own &mdash; which stops (not kills) the whole subtree &mdash; and hung a run for 90 minutes. Fix: redirect stdin from /dev/null on unattended invocations.</li>
            <li><span className="font-medium text-foreground">The measurement that vanished at the cap.</span> The disk snapshot was taken only on the synced success branch. When a slow client hit the 72-hour cap, the script fell through to teardown &mdash; which wiped the datadir &mdash; and snapshotted after. Fix: snapshot on every exit path, before teardown. The cap path is the one you forget, and it&apos;s the one a slow client actually takes.</li>
          </ul>
        </section>

        <section id="next-person" className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">What we&apos;d tell the next person</h2>
          <ul className="mt-4 space-y-2 text-sm text-muted-foreground">
            <li><span className="font-medium text-foreground">The third clock is the real limit.</span> Node wall-clock and agent wall-clock are solvable with infrastructure; agent context only scales if you push conclusions to the data and keep durable state in small files.</li>
            <li><span className="font-medium text-foreground">Measure on every exit path, before you destroy anything.</span> Success is the easy path. The cap and the error paths are where your data quietly disappears.</li>
            <li><span className="font-medium text-foreground">Gate your benchmark on config, not just on outcome.</span> Stamp every number with &ldquo;was this the client&apos;s best mode?&rdquo; or you will eventually publish a measurement of your own mistake.</li>
            <li><span className="font-medium text-foreground">Give an agent a job and a fence.</span> The agent owns the tedious, sustained correctness; the human owns the few irreversible levers.</li>
          </ul>
          <h3 className="mt-6 font-medium text-foreground">Honest limitations</h3>
          <p className="mt-2 text-sm text-muted-foreground">
            This is a real benchmark, not a lab result. It ran on a shared, semi-production host (12 cores,
            ~62 GB RAM, co-resident workloads) &mdash; representative of how many people actually run
            nodes, but with contention the numbers can&apos;t fully isolate. Each client was measured on
            one run at a pinned version, so a single result is a data point, not a distribution. An
            AI-in-the-loop campaign also carries its own risk surface, which is exactly why the governance
            fence above was non-negotiable rather than advisory.
          </p>
        </section>

        <section id="reproduce-it" className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">Reproduce it</h2>
          <p className="mt-2 text-sm text-muted-foreground">The harness is in the repo and the data is committed:</p>
          <div className="mt-4 flex flex-wrap gap-3">
            {reproduceLinks.map((link) => (
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
