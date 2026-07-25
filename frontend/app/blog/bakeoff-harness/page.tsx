import type { Metadata } from 'next'
import { AnchorHeading } from '@/components/ui/AnchorHeading'
import { ArticleJsonLd } from '@/components/ui/ArticleJsonLd'
import { BackToTop } from '@/components/ui/BackToTop'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { CodeBlock } from '@/components/ui/CodeBlock'
import { ReadNext } from '@/components/ui/ReadNext'
import { SITE_CONFIG } from '@/lib/constants'
import { ArrowDown, ArrowRight } from 'lucide-react'

const PAGE_TITLE = 'The Bake-off Harness — ETH2 Quick Start'
const PAGE_DESCRIPTION =
  'A function-level engineering reference for the bake-off harness: every script under test/bakeoff/, every function it calls, every flag it reads, and the data files it produces.'
const PAGE_OG_ALT = 'The bake-off harness — a function-level engineering reference'

export const metadata: Metadata = {
  title: PAGE_TITLE,
  description: PAGE_DESCRIPTION,
  alternates: { canonical: '/blog/bakeoff-harness' },
  openGraph: {
    type: 'article',
    siteName: 'ETH2 Quick Start',
    images: [{ url: '/og-harness.png', width: 1200, height: 630, alt: PAGE_OG_ALT }],
    url: '/blog/bakeoff-harness',
    title: PAGE_TITLE,
    description: PAGE_DESCRIPTION,
  },
  twitter: {
    card: 'summary_large_image',
    images: [{ url: '/og-harness.png', width: 1200, height: 630, alt: PAGE_OG_ALT }],
    title: PAGE_TITLE,
    description: PAGE_DESCRIPTION,
  },
}

const tocLinks = [
  { label: '1. Layout', href: '#layout' },
  { label: '2. run_bakeoff.sh', href: '#run-bakeoff' },
  { label: '3. run_candidate.sh', href: '#run-candidate' },
  { label: '4. apply_resource_caps.sh', href: '#apply-resource-caps' },
  { label: '5. lib.sh', href: '#lib-sh' },
  { label: '6. run_anchor_rotation.sh', href: '#run-anchor-rotation' },
  { label: '7. summarize.sh', href: '#summarize' },
  { label: '8. Data model reference', href: '#data-model' },
  { label: '9. Hardening fixes', href: '#hardening-fixes' },
  { label: 'See also', href: '#see-also' },
]

const seeAlsoLinks = [
  {
    file: 'HOW_WE_TESTED_WITH_CLAUDE.md',
    desc: 'the agent-orchestration model, the 23-day timeline, and the war stories behind the hardening fixes above.',
    href: `${SITE_CONFIG.github}/blob/master/docs/HOW_WE_TESTED_WITH_CLAUDE.md`,
  },
  {
    file: 'CLIENT_BAKEOFF_RESULTS.md',
    desc: 'the numbers, source-of-truth.',
    href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md`,
  },
  {
    file: 'CLIENT_BAKEOFF_BLOG.md',
    desc: 'the narrative writeup of the findings.',
    href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_BLOG.md`,
  },
  {
    file: 'CLIENT_BAKEOFF_ISSUES_LOG.md',
    desc: 'the incident log that motivated several of the hardening fixes above.',
    href: `${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_ISSUES_LOG.md`,
  },
]

const layoutTree = `test/bakeoff/
├── run_bakeoff.sh          # sequential multi-candidate orchestrator + resume guard
├── run_candidate.sh        # single-candidate driver: reset → install → caps → sample-to-verdict
├── run_anchor_rotation.sh  # multi-EL anchor-rotation driver (establish EL once, sweep CLs against it)
├── apply_resource_caps.sh  # systemd CPUQuota/MemoryMax/IOWeight apply|clear
├── lib.sh                  # shared probe/sample/config-gate library (sourced, never executed)
├── summarize.sh            # aggregates artifacts/ into summary.csv, report.md, a results skeleton
├── candidates.tsv          # the manifest: <execution>\\t<consensus> pairs to run
└── test_data_dirs_sync.sh  # CI guard: BAKEOFF_DATA_DIRS must match purge_ethereum_data.sh`

const installSnippet = `timeout "$install_timeout" /usr/bin/time -v -o "$out/install-time.txt" \\
  ./scripts/eth2qs.sh phase2 --execution="$execution" --consensus="$consensus" --mev=none \\
  </dev/null > "$out/install.log" 2>&1`

const summaryCsvColumns = `pair,execution,consensus,install_exit_code,crash,sample_count,last_doctor_status,
last_disk_bytes,residual_bytes,config_optimal,config_optimal_detail,fully_synced,
sync_duration,sync_only,last_el_block,el_bytes,cl_bytes,anchor_synced`

const configTokenRows: { client: string; token: React.ReactNode }[] = [
  { client: 'geth', token: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">history.chain</code> present</> },
  {
    client: 'nethermind',
    token: (
      <>
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">AncientBodiesBarrier</code> present <strong>and</strong>{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">PivotNumber</code> extracted and{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'> 0'}</code> (a zero pivot means snap sync is inert) — the pivot regex handles
        Nethermind&apos;s quoted-JSON form (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'"PivotNumber": 15900000,'}</code>) with an
        optional closing quote between the key and the separator
      </>
    ),
  },
  {
    client: 'erigon',
    token: (
      <>
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">prune.mode</code> set to <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">full</code>, matching both YAML-colon
        (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'prune.mode: "full"'}</code>) and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">=</code> separator styles, quotes optional
      </>
    ),
  },
  {
    client: 'reth',
    token: (
      <>
        both <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--prune.bodies.pre-merge</code> <strong>and</strong>{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--prune.receipts.pre-merge</code> present
      </>
    ),
  },
  { client: 'besu', token: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">history-expiry-prune=true</code></> },
  { client: 'nimbus_eth1', token: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">prune = true</code></> },
  {
    client: 'ethrex',
    token: (
      <>
        no history-prune lever exists, so &ldquo;optimal&rdquo; is redefined as <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--syncmode snap</code> being
        present
      </>
    ),
  },
  { client: 'prysm', token: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">beacon-db-pruning</code> (flag or config-key form)</> },
  { client: 'lighthouse', token: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">checkpoint-sync-url</code> present (default pruning behavior is already fine)</> },
  {
    client: 'teku',
    token: (
      <>
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">data-storage-mode</code> set to <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">minimal</code> or{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">prune</code> (leading letter either case)
      </>
    ),
  },
  {
    client: 'nimbus (CL)',
    token: (
      <>
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">history = prune</code> in the persistent config — deliberately <strong>not</strong> checking{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">trustedNodeSync</code>/<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--trusted-node-url</code>, because those only
        appear in the one-shot bootstrap subcommand that runs <em>before</em> the service starts, never in the persistent{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ExecStart</code> or <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">nimbus.toml</code>, so they&apos;re unobservable
        here and out of scope for this &ldquo;is the running config optimal&rdquo; gate
      </>
    ),
  },
  { client: 'lodestar', token: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">pruneHistory=true</code> (or <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">chain.pruneHistory</code>)</> },
  { client: 'grandine', token: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--prune-storage</code> present</> },
]

const dataModelRows: { file: string; writtenBy: React.ReactNode; contents: React.ReactNode }[] = [
  {
    file: 'env.txt',
    writtenBy: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code> (append-only through the run)</>,
    contents: (
      <>
        Key-value run metadata: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">execution=</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">consensus=</code>,{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">mev=</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">started_at_utc=</code>,{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">sync_window_seconds=</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">sample_interval_seconds=</code>,{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">install_timeout=</code>,{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'harness_mode=full|establish|anchor'}</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">anchor_el=</code> (if set),{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">install_exit_code=</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'config_optimal=yes|no'}</code>,{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal_detail=</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'fully_synced=yes|no'}</code>,{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">synced_at_utc=</code> (if synced), <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">service_crash_observed=</code>,{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">stall_restarts=</code>/<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">stall_failed=yes</code> (if the stall watchdog
        fired), <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'anchor_synced=yes|no'}</code> (anchor mode only), <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ended_at_utc=</code>
      </>
    ),
  },
  {
    file: 'samples.jsonl',
    writtenBy: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_write_sample</code> (one JSON line per tick)</>,
    contents: (
      <>
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">timestamp_utc</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">services_alive</code>,{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">disk_tsv</code> (raw TSV text), <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">execution_sync</code>,{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">beacon_sync</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">processes</code>,{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">doctor</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">stats</code>
      </>
    ),
  },
  {
    file: 'disk-before.tsv / disk-synced.tsv / disk-final.tsv / disk-after-cleanup.tsv',
    writtenBy: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_snapshot_disk</code> at four checkpoints</>,
    contents: (
      <>
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">path\tbytes\thuman</code> rows per <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">BAKEOFF_DATA_DIRS</code> entry that
        exists, plus a <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">filesystem:/</code> row
      </>
    ),
  },
  {
    file: 'candidates.tsv',
    writtenBy: 'manifest (hand-edited)',
    contents: (
      <>
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'<execution>\\t<consensus>'}</code> rows — the source list <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_bakeoff.sh</code> expands
        into <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">el__cl</code> pair ids
      </>
    ),
  },
  {
    file: 'install.log / install-time.txt',
    writtenBy: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code> install step</>,
    contents: (
      <>
        stdout+stderr of <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">phase2</code>, and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">/usr/bin/time -v</code> resource/wall-clock
        accounting
      </>
    ),
  },
  {
    file: 'findings.md',
    writtenBy: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code> teardown (seeded, human-completed)</>,
    contents: 'Install/crash verdict skeleton for reviewer sign-off',
  },
  {
    file: '.done / .anchor-poisoned / .config-not-optimal / .stalled',
    writtenBy: 'marker files',
    contents: 'Resume guard, anchor-invalidation flag, config-gate miss flag, stall-watchdog exhaustion flag — all checked by filename existence, never by content',
  },
  {
    file: 'summary.csv / process-summary.csv / report.md / CLIENT_BAKEOFF_RESULTS.generated.md',
    writtenBy: <><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code></>,
    contents: (
      <>
        Aggregated, gitignored — inputs for a human to curate into the committed <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">CLIENT_BAKEOFF_RESULTS.md</code>
      </>
    ),
  },
]

// Renders the same edges as the source flowchart (kept in git history):
//   candidates.tsv --> run_bakeoff.sh --> run_candidate.sh
//   run_anchor_rotation.sh --> run_candidate.sh
//   run_candidate.sh --> systemd EL/CL services
//   run_candidate.sh --> artifacts/run-id/ --> summarize.sh --> summary.csv & report.md
function DataFlowDiagram() {
  return (
    <div className="mt-3">
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="flex flex-col items-center">
          <div className="w-full rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
            <span className="font-mono text-xs">candidates.tsv</span>
            <span className="block text-xs text-muted-foreground">manifest</span>
          </div>
          <ArrowDown className="my-1.5 h-4 w-4 shrink-0 text-muted-foreground" aria-hidden="true" />
          <div className="w-full rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
            <span className="font-mono text-xs">run_bakeoff.sh</span>
            <span className="block text-xs text-muted-foreground">sequential multi-candidate sweep</span>
          </div>
        </div>
        <div className="flex flex-col items-center justify-end">
          <div className="w-full rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
            <span className="font-mono text-xs">run_anchor_rotation.sh</span>
            <span className="block text-xs text-muted-foreground">anchor-preserving CL sweep (separate entry point)</span>
          </div>
        </div>
      </div>
      <ArrowDown className="mx-auto my-1.5 h-4 w-4 shrink-0 text-muted-foreground" aria-hidden="true" />
      <div className="mx-auto max-w-sm rounded-lg border border-primary/30 bg-primary/5 px-4 py-3 text-center text-sm text-foreground">
        <span className="font-mono text-xs text-primary">run_candidate.sh</span>
        <span className="block text-xs text-muted-foreground">single-candidate driver: reset → install → cap → sample</span>
      </div>
      <ArrowDown className="mx-auto my-1.5 h-4 w-4 shrink-0 text-muted-foreground" aria-hidden="true" />
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
          <span className="font-mono text-xs">systemd EL &amp; CL services</span>
          <span className="block text-xs text-muted-foreground">the running node</span>
        </div>
        <div className="flex flex-col items-center">
          <div className="w-full rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
            <span className="font-mono text-xs">artifacts/run-id/</span>
            <span className="block text-xs text-muted-foreground">env.txt, samples.jsonl, disk snapshots</span>
          </div>
          <ArrowDown className="my-1.5 h-4 w-4 shrink-0 text-muted-foreground" aria-hidden="true" />
          <div className="w-full rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
            <span className="font-mono text-xs">summarize.sh</span>
            <span className="block text-xs text-muted-foreground">aggregation</span>
          </div>
          <ArrowDown className="my-1.5 h-4 w-4 shrink-0 text-muted-foreground" aria-hidden="true" />
          <div className="w-full rounded-lg border border-border bg-muted/30 px-4 py-3 text-center text-sm text-foreground">
            <span className="font-mono text-xs">summary.csv &amp; report.md</span>
          </div>
        </div>
      </div>
    </div>
  )
}

export default function BakeoffHarnessPage() {
  return (
    <div className="min-h-screen py-12 sm:py-16 md:py-24">
      <div className="mx-auto max-w-5xl px-4 sm:px-6">
        <ArticleJsonLd
          title={PAGE_TITLE}
          description={PAGE_DESCRIPTION}
          slug="bakeoff-harness"
          image="/og-harness.png"
          datePublished="2026-07-21"
        />
        <header>
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Engineering &middot; Companion to the bake-off writeup
          </p>
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            The Bake-off Harness — Function-Level Engineering Reference
          </h1>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            This is the deep, function-level reference for the bake-off harness. Where the results and narrative
            writeups cover the measurements, orchestration model, and war stories, this document covers every
            script under <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">test/bakeoff/</code>, every function it calls, every flag it reads, and the data
            files it produces. Read it alongside the scripts themselves — line numbers below refer to the harness as of
            this writing and will drift as the code evolves; the function/flag <em>names</em> are the stable
            contract.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Results and methodology are documented in{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">CLIENT_BAKEOFF_RESULTS.md</code> (the source of truth for every number) and{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">CLIENT_BAKEOFF_BLOG.md</code> (the narrative writeup). This doc is about the <em>harness</em>,
            not the findings.
          </p>
          <div className="mt-4 flex flex-wrap gap-3 sm:mt-6">
            <Button href="/blog/ethereum-client-bakeoff" variant="secondary" size="sm">
              Read the results writeup
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
            <Button href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_HARNESS.md`} external variant="ghost" size="sm">
              View source on GitHub
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
          </div>
        </header>

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

        {/* 1. Layout */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="layout" className="text-lg sm:text-xl font-semibold text-foreground">1. Layout</AnchorHeading>
          <CodeBlock language="text" code={layoutTree} className="mt-4" />
          <p className="mt-4 text-sm text-muted-foreground">
            The executable driver scripts (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_bakeoff.sh</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code>,{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_anchor_rotation.sh</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">apply_resource_caps.sh</code>,{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code>) each set <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">set -Eeuo pipefail</code> and source{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">lib/common_functions.sh</code> for logging (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">log_info</code>/
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">log_warn</code>/<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">log_error</code>). <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">lib.sh</code> is
            the exception noted in the layout above: it&apos;s a sourced library, never executed on its own, that
            inherits strict mode from whichever script sources it and does not source{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">common_functions.sh</code> itself — its <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">log_*</code> calls resolve at runtime
            because every caller (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_anchor_rotation.sh</code>)
            already sourced <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">common_functions.sh</code> first.
          </p>

          <AnchorHeading id="data-flow" as="h3" className="mt-6 font-medium text-foreground">
            Data flow at a glance
          </AnchorHeading>
          <DataFlowDiagram />
          <p className="mt-3 text-sm text-muted-foreground">
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_bakeoff.sh</code> owns the ordinary sequential sweep; <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_anchor_rotation.sh</code>{' '}
            reuses one synced execution-layer anchor while cycling consensus clients. Both paths produce the same
            per-candidate artifacts, so <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code> has one source of truth.
          </p>
        </section>

        {/* 2. run_bakeoff.sh */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="run-bakeoff" className="text-lg sm:text-xl font-semibold text-foreground">
            2. <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_bakeoff.sh</code> — the sequential orchestrator
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Usage: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'run_bakeoff.sh --stage=triage|full [--only=el__cl,el__cl,...] [--force]'}</code>
          </p>
          <p className="mt-3 text-sm text-muted-foreground">What it does, in order:</p>
          <ol className="mt-3 space-y-3 text-sm text-muted-foreground list-decimal list-inside">
            <li>
              <span className="font-medium text-foreground">Stage-dependent windows.</span>{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--stage=triage</code> sets a 5400s (90 min) sync window with 120s sampling (
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS</code>,{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS</code>); <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--stage=full</code> sets a
              259200s (72h) window with 600s sampling. Both are overridable via env (the script only supplies the
              default with <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'${VAR:-default}'}</code>).
            </li>
            <li>
              <span className="font-medium text-foreground">Config swap with restore-on-exit.</span> It backs up the
              current <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config/user_config.env</code> to{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config/user_config.env.bakeoff-backup</code>, installs{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config/bakeoff.env</code> in its place, and registers{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">trap restore_cfg EXIT</code> so the operator&apos;s real config is always restored — even
              on Ctrl-C or a crash mid-run.
            </li>
            <li>
              <span className="font-medium text-foreground">Candidate selection from <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">candidates.tsv</code>.</span> The manifest is{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'<execution>\\t<consensus>'}</code> pairs; <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_bakeoff.sh</code> turns each row
              into an <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">el__cl</code> pair id with{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{`awk -F'\\t' 'NF>=2{print $1"__"$2}'`}</code>.
              <ul className="mt-2 list-disc list-inside space-y-1.5">
                <li>
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--only=a__b,c__d</code> explicitly overrides the manifest.
                </li>
                <li>
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--stage=full</code> <strong>without</strong>{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--only</code> auto-selects only candidates whose triage{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">env.txt</code> already recorded <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">install_exit_code=0</code> — this
                  is the resume guard: a full run only re-attempts candidates that passed triage, and running{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--stage=full</code> twice is safe (it re-derives the same selection from disk, it
                  doesn&apos;t remember state in the orchestrator itself).
                </li>
                <li>
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--stage=triage</code> with no <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--only</code> runs every manifest row.
                </li>
              </ul>
            </li>
            <li>
              <span className="font-medium text-foreground">Sequential dispatch, tolerant of failure.</span> For each
              selected pair it calls <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'run_candidate.sh "$execution" "$consensus"'}</code> with{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">set +e</code> around the call, so one candidate&apos;s non-zero exit does not abort the
              sweep; the exit code is appended to <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'artifacts/<run-id>/orchestrator-<stage>.log'}</code>.
            </li>
            <li>
              <span className="font-medium text-foreground">Always calls <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code></span> at the end (
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">|| log_warn</code>, non-fatal if it errors).
            </li>
          </ol>
          <p className="mt-4 text-sm text-muted-foreground">
            Artifact root:{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'artifacts/${ETH2QS_BAKEOFF_RUN_ID:-client-bakeoff-2026-06-22}/'}</code>. Every subsequent
            script keys off the same env var, so a fresh campaign is just a new{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_RUN_ID</code>.
          </p>
        </section>

        {/* 3. run_candidate.sh */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="run-candidate" className="text-lg sm:text-xl font-semibold text-foreground">
            3. <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code> — the single-candidate state machine
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Usage: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'run_candidate.sh <execution> <consensus>'}</code>. This is the workhorse; every
            candidate row in the results tables is one invocation of this script. It refuses to run at all unless{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_CONFIRMED=yes</code> is set (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">log_error … exit 2</code>) — a
            deliberate manual safety gate because the script purges data directories and stops/disables services.
          </p>

          <AnchorHeading id="modes" as="h3" className="mt-6 font-medium text-foreground">
            3.1 Modes
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            The script has three modes, selected by env vars, all mutually aware of each other:
          </p>
          <div className="mt-4 sm:mt-6 hidden sm:block overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">Mode</th>
                  <th className="pb-3 font-medium text-muted-foreground">Trigger</th>
                  <th className="pb-3 font-medium text-muted-foreground">Behavior</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr>
                  <td className="py-3 align-top font-medium text-foreground">
                    <Badge>full (default)</Badge>
                  </td>
                  <td className="py-3 align-top text-muted-foreground">neither var set</td>
                  <td className="py-3 align-top text-muted-foreground">stop+disable+purge both EL and CL, install both, sync both</td>
                </tr>
                <tr>
                  <td className="py-3 align-top font-medium text-foreground">
                    <Badge variant="primary">establish</Badge>
                  </td>
                  <td className="py-3 align-top text-muted-foreground">
                    <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_KEEP_EL=yes</code>
                  </td>
                  <td className="py-3 align-top text-muted-foreground">
                    same as full, but on teardown only the CL datadir is purged — the EL is left running and synced,
                    to become the next anchor
                  </td>
                </tr>
                <tr>
                  <td className="py-3 align-top font-medium text-foreground">
                    <Badge variant="primary">anchor</Badge>
                  </td>
                  <td className="py-3 align-top text-muted-foreground">
                    <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'ETH2QS_BAKEOFF_ANCHOR_EL=<el>'}</code>
                  </td>
                  <td className="py-3 align-top text-muted-foreground">
                    only stop/disable/purge the CL; the EL must already be active and synced; only the CL is
                    installed and cycled
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-3 sm:hidden">
            <div className="rounded-lg border border-border p-3">
              <Badge>full (default)</Badge>
              <p className="mt-2 text-xs text-muted-foreground"><span className="font-medium">Trigger:</span> neither var set</p>
              <p className="mt-1 text-sm text-muted-foreground">stop+disable+purge both EL and CL, install both, sync both</p>
            </div>
            <div className="rounded-lg border border-border p-3">
              <Badge variant="primary">establish</Badge>
              <p className="mt-2 text-xs text-muted-foreground"><span className="font-medium">Trigger:</span> <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_KEEP_EL=yes</code></p>
              <p className="mt-1 text-sm text-muted-foreground">same as full, but on teardown only the CL datadir is purged — the EL is left running and synced, to become the next anchor</p>
            </div>
            <div className="rounded-lg border border-border p-3">
              <Badge variant="primary">anchor</Badge>
              <p className="mt-2 text-xs text-muted-foreground"><span className="font-medium">Trigger:</span> <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">{'ETH2QS_BAKEOFF_ANCHOR_EL=<el>'}</code></p>
              <p className="mt-1 text-sm text-muted-foreground">only stop/disable/purge the CL; the EL must already be active and synced; only the CL is installed and cycled</p>
            </div>
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            Anchor mode has its own precondition gate before touching anything: the{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">$execution</code> arg must equal <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">$ETH2QS_BAKEOFF_ANCHOR_EL</code> (mismatch
            → <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">exit 3</code>), <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth1.service</code> must be{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">systemctl is-active</code>, Engine API port 8551 must answer with an HTTP-shaped code (
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'^[1-5][0-9]{2}$'}</code>, since 401 auth-required counts as &ldquo;responding&rdquo;), and a
            bounded 5-retry/2s-sleep loop must observe <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_syncing</code> resolve to &ldquo;caught up&rdquo; (
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">result == false</code>, or a progress object where{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">currentBlock == highestBlock</code> and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">highestBlock != &quot;0x0&quot;</code>) before
            the CL sweep is allowed to start.
          </p>

          <AnchorHeading id="resume-guard" as="h3" className="mt-6 font-medium text-foreground">
            3.2 Resume guard
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            If <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">$out/.done</code> exists and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_FORCE</code> isn&apos;t{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">yes</code>, the candidate is skipped entirely (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">exit 0</code>). Setting{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_FORCE=yes</code> also clears <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.anchor-poisoned</code> and{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.done</code> so a forced rerun doesn&apos;t inherit a stale poison marker from a previous
            attempt — without that clear, the anchor watchdog guard later in the script would bypass itself and
            finalize <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">anchor_synced=no</code> for what is actually a clean rerun.
          </p>

          <AnchorHeading id="pre-install-sequence" as="h3" className="mt-6 font-medium text-foreground">
            3.3 Pre-install sequence
          </AnchorHeading>
          <ol className="mt-2 space-y-3 text-sm text-muted-foreground list-decimal list-inside">
            <li>
              Stop+disable the relevant services (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth1.service cl.service validator.service</code>, or just{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">cl.service validator.service</code> in anchor mode) — <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'2>/dev/null || true'}</code>,
              tolerant of units that don&apos;t exist yet.
            </li>
            <li>
              Purge datadirs via <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">./scripts/eth2qs.sh clean-data</code> — <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--dry-run</code> first
              (logged, non-fatal), then <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--confirm</code> (must succeed). Anchor mode passes{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--scope=consensus</code> so the EL anchor is never touched.{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'< /dev/null'}</code> on every <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">clean-data</code> and install call
              prevents <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">SIGTTIN</code> when the harness runs detached (backgrounded/tmux) — a non-interactive
              process group reading from a controlling TTY gets stopped by the kernel, not an error the script can
              catch.
            </li>
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'bakeoff_snapshot_disk "$out/disk-before.tsv"'}</code> — baseline footprint.
            </li>
            <li>
              <strong>Disk-floor guard</strong>, checked via <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">df -B1 --output=avail /</code>: anchor mode requires{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_MIN_DISK_BYTES:-429496729600</code> (400 GiB — CL-only, since the EL already
              occupies disk), full mode requires <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">:-1717986918400</code> (1.6 TiB — full EL+CL). Below the
              floor, the script aborts with <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">exit 3</code> <em>before</em> starting an install that would fail
              hours later from <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ENOSPC</code>.
            </li>
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">./scripts/eth2qs.sh plan|doctor|stats --json</code> snapshots, best-effort (
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">|| true</code>).
            </li>
            <li>
              Opportunistic <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">GITHUB_TOKEN</code> export from <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">gh auth token</code> if
              neither <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">GITHUB_TOKEN</code> nor <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">GH_TOKEN</code> is already set — avoids the
              60/hr unauthenticated GitHub API rate limit during client-version lookups inside the install scripts.
            </li>
          </ol>

          <AnchorHeading id="install-step" as="h3" className="mt-6 font-medium text-foreground">
            3.4 Install
          </AnchorHeading>
          <CodeBlock language="bash" code={installSnippet} className="mt-3" />
          <p className="mt-3 text-sm text-muted-foreground">
            (Anchor mode omits <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--execution=</code> since only the CL installs.){' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">install_timeout</code> defaults to <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">90m</code> (
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_INSTALL_TIMEOUT</code>). <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">/usr/bin/time -v</code> is what{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code> later parses for install wall-clock (see §6). The exit code is
            captured with <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">set +e</code>/<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">set -e</code> bracketing and written to{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">env.txt</code> as <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">install_exit_code=</code>.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Immediately after install: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">apply_resource_caps.sh apply</code> (§4), then a battery of
            post-install snapshots (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">doctor</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">stats</code>,{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">monitor export</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">debug --service eth1</code>,{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">debug --service cl</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">systemctl status eth1 cl validator</code>), then
            the config-optimality gate, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_check_config_optimal</code> (§5.5) — non-blocking, it
            stamps <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'config_optimal=yes|no'}</code> into <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">env.txt</code> and never aborts the run.
          </p>

          <AnchorHeading id="observation-window" as="h3" className="mt-6 font-medium text-foreground">
            3.5 Observation window
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Skipped entirely if <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">install_rc != 0</code>. Otherwise a <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">while</code> loop runs
            until <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'$(date +%s) >= end_at'}</code> (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">end_at = now + window</code>),
            sleeping <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">interval</code> seconds between iterations. Each iteration:
          </p>
          <ol className="mt-3 space-y-3 text-sm text-muted-foreground list-decimal list-inside">
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'bakeoff_write_sample "$out" "$REPO_ROOT"'}</code> — the sampling primitive (§5.4).
            </li>
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_services_alive</code> check — sets <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">crashed=yes</code> if either
              service unit is no longer active (this becomes <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">service_crash_observed</code> in{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">env.txt</code>, a hard fail signal downstream).
            </li>
            <li>
              <strong>Anchor watchdog</strong> (anchor mode only, and only while <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.anchor-poisoned</code> doesn&apos;t
              already exist): detects if the anchor EL silently dropped out of sync (service down, or{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_syncing</code> no longer reporting caught-up). Two consecutive misses (
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">anchor_miss_streak -ge 2</code>) touches <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.anchor-poisoned</code> and logs
              an error — <strong>detection only, it never restarts or kills anything</strong>, because the anchor EL
              is shared state across the whole CL sweep and killing it would invalidate every remaining candidate in
              the rotation.
            </li>
            <li>
              <strong>Stall watchdog</strong> (opt-in via <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_STALL_RESTART=yes</code>, inert otherwise):
              tracks <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">no_progress_streak</code> — the CL&apos;s <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">head_slot</code> (or, if
              absent, a <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">sync_distance</code>-derived proxy) in anchor mode, or the EL&apos;s{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">currentBlock</code> (hex-decoded) otherwise. <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">stall_samples</code> (default
              10) consecutive non-advancing samples triggers <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">sudo systemctl restart</code> on the stalled unit,
              up to <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">stall_max_restarts</code> (default 3) times; exceeding that touches{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.stalled</code>, writes <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">stall_restarts=</code>/
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">stall_failed=yes</code> to <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">env.txt</code>, and breaks the loop — the row
              is invalid past that point but the harness still finalizes cleanly rather than hanging forever on a
              genuinely dead node.
            </li>
            <li>
              <strong>Synced-streak check</strong>: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_is_synced</code> (§5.3) must return true on{' '}
              <strong>two consecutive</strong> samples (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">synced_streak -ge 2</code>) before the row is accepted
              as synced — a single true reading can be a race between the EL and CL heads. On that streak, it
              snapshots <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">disk-synced.tsv</code>, writes <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">synced_at_utc=</code>/
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">fully_synced=yes</code>, and breaks out of the window early (no need to wait for the full
              72h cap once synced).
            </li>
          </ol>
          <p className="mt-3 text-sm text-muted-foreground">
            After the loop (whether by break or timeout), one final <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_write_sample</code> call captures
            the end state, then <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">env.txt</code> gets <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">fully_synced=no</code> if nothing set
            it, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">service_crash_observed=</code>, and (anchor mode only){' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'anchor_synced=yes|no'}</code> depending on whether <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.anchor-poisoned</code> exists.
          </p>

          <AnchorHeading id="teardown" as="h3" className="mt-6 font-medium text-foreground">
            3.6 Teardown
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">journalctl</code> tails (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">-u eth1 -n 700</code>,{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">-u cl -n 700</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">-u validator -n 300</code>) and{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">./scripts/eth2qs.sh repair</code> preview are captured regardless of outcome. A{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">findings.md</code> skeleton is seeded with the install/crash verdict for a human reviewer
            to fill in (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">Result: TBD-by-reviewer</code>).{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'bakeoff_snapshot_disk "$out/disk-final.tsv"'}</code> captures the footprint pre-cleanup
            (synced or capped — this is what <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code> falls back to when{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">disk-synced.tsv</code> doesn&apos;t exist). Then <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">apply_resource_caps.sh clear</code>,
            then <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">clean-data</code> again (scoped the same way as pre-install), then a final{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">disk-after-cleanup.tsv</code> snapshot, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ended_at_utc</code>,{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">touch .done</code>, and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'exit "$install_rc"'}</code>.
          </p>
        </section>

        {/* 4. apply_resource_caps.sh */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="apply-resource-caps" className="text-lg sm:text-xl font-semibold text-foreground">
            4. <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">apply_resource_caps.sh</code> — systemd runtime caps
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Usage: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'apply_resource_caps.sh <apply|clear>'}</code>. Purpose: keep the bake-off from
            starving co-resident work on a shared host by capping the node stack to roughly 8 cores / 36G total.
          </p>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground list-disc list-inside">
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'cap_unit <unit> <prop...>'}</code> guards on <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'systemctl cat "$unit"'}</code>{' '}
              existing (skips with a warning if the unit isn&apos;t defined yet) and applies each property with{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'sudo systemctl set-property --runtime <unit> <prop>'}</code> — <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--runtime</code>{' '}
              means these are transient, gone on reboot, never written into the unit file.
            </li>
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">apply</code>: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth1.service</code> gets{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">CPUQuota=600% MemoryMax=24G MemoryHigh=22G IOWeight=50</code>;{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">cl.service</code> gets{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">CPUQuota=200% MemoryMax=12G MemoryHigh=11G IOWeight=50</code>.
            </li>
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">clear</code>: resets both units&apos; <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">CPUQuota</code>/
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">MemoryMax</code>/<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">MemoryHigh</code>/<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">IOWeight</code> back
              to infinity/infinity/infinity/100 — deliberately <strong>not</strong>{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">systemctl revert</code>, because these are custom units and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">revert</code> can
              strip unit overrides/definitions entirely, not just the runtime properties this script set. In anchor
              mode, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">clear</code> explicitly skips reverting <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth1.service</code> (
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_ANCHOR_EL</code> set) so the anchor&apos;s caps stay consistent for the rest
              of the CL sweep; only <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">cl.service</code> reverts.
            </li>
          </ul>
        </section>

        {/* 5. lib.sh */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="lib-sh" className="text-lg sm:text-xl font-semibold text-foreground">
            5. <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">lib.sh</code> — the shared probe/sample/gate library
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Sourced by <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code> and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_anchor_rotation.sh</code>. Never
            executed directly.
          </p>

          <AnchorHeading id="bakeoff-data-dirs" as="h3" className="mt-6 font-medium text-foreground">
            5.1 <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">BAKEOFF_DATA_DIRS</code>
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            The canonical list of every client datadir the harness knows about (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">$HOME/.ethereum</code>,{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">$HOME/.local/share/nethermind</code>, … through <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">$HOME/ethgas</code>). This
            array <strong>must</strong> stay in sync with the <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">DATA_DIRS</code> arrays in{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">install/utils/purge_ethereum_data.sh</code> — <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">test_data_dirs_sync.sh</code> is a
            CI guard that fails the build if they drift (it diffs the two lists rather than sourcing{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">purge_ethereum_data.sh</code>, since sourcing it would invoke <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">main</code> and run
            the actual purge).
          </p>

          <AnchorHeading id="snapshot-probe-primitives" as="h3" className="mt-6 font-medium text-foreground">
            5.2 Snapshot/probe primitives
          </AnchorHeading>
          <ul className="mt-2 space-y-3 text-sm text-muted-foreground list-disc list-inside">
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'bakeoff_snapshot_disk <outfile>'}</code> — for every path in{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">BAKEOFF_DATA_DIRS</code> that exists, writes{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">path\tbytes\thuman</code> using <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">du -sb</code>/
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">du -sh</code>, then a final <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">filesystem:/</code> row from{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">df -B1 /</code>. The <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">du</code> calls are{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'2>/dev/null'}</code> with <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">|| true</code> after the{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">awk</code> — <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">du</code> can exit non-zero on a file that vanishes
              mid-walk (a live datadir churning during snapshot), and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">|| true</code> keeps the number that{' '}
              <em>was</em> printed instead of letting <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">pipefail</code> propagate a fatal exit into an unguarded
              caller.
            </li>
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_probe_execution_sync</code> — <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">curl -sS --max-time 5</code> to{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">http://127.0.0.1:8545</code> with an <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_syncing</code> JSON-RPC payload; on a
              curl connection failure, prints{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'{"error":"execution_rpc_unavailable"}'}</code> instead of failing. There&apos;s no{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--fail</code> flag, so an HTTP-error response with a non-JSON body (e.g. an HTML error
              page) is <em>not</em> caught by this fallback — the actual guard against malformed output downstream is{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_write_sample</code>&apos;s <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'fromjson? // {raw: ...}'}</code> fallback
              (§5.4).
            </li>
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_probe_beacon_sync</code> — tries four ports in order (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">3500</code>,{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">5051</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">5052</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">9596</code> — the different
              consensus clients&apos; REST API defaults) against <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">/eth/v1/node/syncing</code>, returns the first
              non-empty body; falls back to <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'{"error":"beacon_rest_unavailable"}'}</code>.
            </li>
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_snapshot_processes</code> — <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ps -eo pid=,comm=,%cpu=,%mem=,rss=,vsz=,etime=,args=</code>{' '}
              piped to an <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">awk</code> regex over known client names; the pattern matches against the{' '}
              <strong>whole formatted <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ps</code> row</strong> (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">comm</code> <em>and</em>{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">args</code> columns together), not just the <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">comm</code> field — so any
              process whose <em>arguments</em> happen to contain one of those tokens is picked up too, not only ones
              named after a client binary. Matching lines are converted to a JSON array via{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{`jq -R -s 'split("\\n")[:-1]'`}</code>.
            </li>
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_services_alive</code> — <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">systemctl is-active --quiet eth1.service &amp;&amp; systemctl is-active --quiet cl.service</code>.
            </li>
          </ul>

          <AnchorHeading id="bakeoff-is-synced" as="h3" className="mt-6 font-medium text-foreground">
            5.3 <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_is_synced</code>
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">Returns 0 only when <strong>both</strong> layers report caught-up:</p>
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground list-disc list-inside">
            <li>
              Beacon: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.data</code> present, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'sync_distance <= 4'}</code>,{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">is_optimistic == false</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">el_offline == false</code>.
            </li>
            <li>
              Execution: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">eth_syncing</code> result is boolean <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">false</code>, OR a
              progress object where <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">currentBlock == highestBlock</code> <strong>and</strong>{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">highestBlock != &quot;0x0&quot;</code> (the <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">!= &quot;0x0&quot;</code> guard rejects
              the pre-sync zero state, where an EL that hasn&apos;t started downloading anything yet would otherwise
              read as trivially &ldquo;caught up&rdquo;).
            </li>
          </ul>

          <AnchorHeading id="bakeoff-write-sample" as="h3" className="mt-6 font-medium text-foreground">
            5.4 <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'bakeoff_write_sample <out_dir> <repo_root>'}</code>
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            The per-tick sampling routine. Writes disk/execution-sync/beacon-sync/process snapshots plus{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">./scripts/eth2qs.sh doctor --json</code> and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">stats --json</code> (each{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">timeout 30</code>, best-effort) into a <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">tmp/</code> scratch dir, determines{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">alive=&quot;up&quot;/&quot;down&quot;</code> via <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_services_alive</code>, and assembles one JSON
            object per call with <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">jq -cn --rawfile</code> (each raw file parsed with{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'fromjson?  // {raw: ...}'}</code> so a malformed sub-output degrades to a raw-string field
            instead of aborting the whole sample — with one exception: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">processes</code> degrades to an empty
            array <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'(($processes | fromjson?) // [])'}</code>, not a{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'{raw: ...}'}</code> object, since it&apos;s already expected to be a JSON array) appended
            as one line to <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">samples.jsonl</code>. A <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">jq</code> failure on the whole assembly is
            caught and logged (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">log_warn</code>) rather than propagated — one bad sample should never kill
            the observation loop.
          </p>

          <AnchorHeading id="bakeoff-check-config-optimal" as="h3" className="mt-6 font-medium text-foreground">
            5.5 <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'bakeoff_check_config_optimal <el> <cl> <out_dir>'}</code>
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            The config-optimality gate — arguably the harness&apos;s most important correctness mechanism, since a
            disk-footprint benchmark is meaningless if you can&apos;t prove the client was actually running in its
            most disk-efficient mode. Non-blocking (always returns 0), but stamps a verdict that later filters the
            results tables.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">Mechanism:</p>
          <ol className="mt-2 space-y-3 text-sm text-muted-foreground list-decimal list-inside">
            <li>
              Pull the configured <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ExecStart</code> line from each systemd unit:{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">systemctl cat eth1.service | grep -i ExecStart</code> (same for{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">cl.service</code>). <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">systemctl cat</code> reads the unit{' '}
              <strong>file</strong> text (what the service is configured to run, including drop-ins) — not the live
              process&apos;s actual command line — so this reflects the configuration, not a runtime introspection of
              the running process.
            </li>
            <li>
              Extract the first config file path referenced on that line — the extraction pipes through{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">grep -oP | head -1</code>, so only the first match is kept even if more than one flag
              appears on the line. Three flag styles are matched in one <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">grep -oP</code> alternation:{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--config-file=</code>/<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--config-file </code>,{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--rcConfig=</code>/<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--rcConfig </code> (lodestar), and{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--config=</code>/<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--config </code> (erigon). The comment in the source
              notes why the <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--config</code> alternative doesn&apos;t falsely match a{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--config-file=x</code> line: PCRE lookbehind is position-anchored, so{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'(?<=--config[= ])'}</code> only fires when the character immediately after{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--config</code> is <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">=</code> or a space — for{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--config-file=x</code> that character is <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">-</code>, so the lookbehind never
              fires there.
            </li>
            <li>
              If the extracted path exists as a file, its contents are appended to the &ldquo;combined&rdquo;
              haystack alongside the <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ExecStart</code> line — so tokens can live in either the command line
              or the config file.
            </li>
            <li>
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'_has_token <label> <pattern> <haystack>'}</code> runs{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'grep -qP -- "$pattern" "$haystack"'}</code>; the <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--</code> before the
              pattern is required because several patterns start with a dash (e.g.{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--prune-storage</code>) and without <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--</code> those would be parsed as a{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">grep</code> option and silently swallowed by the <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">2&gt;/dev/null</code> as a false
              &ldquo;miss.&rdquo;
            </li>
            <li>
              Per-client token table (kept current with what the install scripts actually emit):
              <div className="mt-3 overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-border text-left">
                      <th className="pb-3 font-medium text-muted-foreground">Client</th>
                      <th className="pb-3 font-medium text-muted-foreground">Token checked</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {configTokenRows.map((row) => (
                      <tr key={row.client}>
                        <td className="py-3 align-top font-medium text-foreground whitespace-nowrap">{row.client}</td>
                        <td className="py-3 align-top text-muted-foreground">{row.token}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </li>
            <li>
              Any client not in the table falls through to <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">unchecked</code> (counted as found, not a
              miss) — the gate is additive; adding a new client without a token entry doesn&apos;t silently fail
              existing runs.
            </li>
            <li>
              Writes <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'config_optimal=yes|no'}</code> and{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal_detail=found=...;missed=...</code> into{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">$out_dir/env.txt</code>. On a miss, also{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">touch $out_dir/.config-not-optimal</code> and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">log_error</code>.
            </li>
          </ol>
          <p className="mt-3 text-sm text-muted-foreground">
            This is the mechanism behind the &ldquo;Superseded — non-optimal config&rdquo; and &ldquo;optimal config
            only&rdquo; table split in <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code>&apos;s generated results skeleton (§6) — a row only
            counts toward the ranked results if every applicable token for its EL and CL was found.
          </p>
        </section>

        {/* 6. run_anchor_rotation.sh */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="run-anchor-rotation" className="text-lg sm:text-xl font-semibold text-foreground">
            6. <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_anchor_rotation.sh</code> — multi-EL anchor rotation
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Usage: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'run_anchor_rotation.sh <anchors_csv> [<cls_csv>]'}</code> (CLs default to{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">lighthouse,teku,nimbus,lodestar,grandine</code>). This is how the CL matrix gets measured against more than one EL anchor without re-syncing every EL from scratch for every
            CL.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Per anchor in <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'<anchors_csv>'}</code>:
          </p>
          <ol className="mt-2 space-y-3 text-sm text-muted-foreground list-decimal list-inside">
            <li>
              <strong>Establish</strong>: unset <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_ANCHOR_EL</code>, set{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_KEEP_EL=yes</code>, call{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'run_candidate.sh <anchor> prysm'}</code> — a normal full-mode candidate run (wipes any
              prior EL, installs fresh, syncs to tip) except that teardown preserves the EL datadir instead of
              purging it. The script also overrides <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS</code> to{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">259200</code> (72h) by default even for what looks like a &ldquo;just establish
              it&rdquo; step — the source comment explains why: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code>&apos;s own default window
              is 5400s (a 90-minute smoke-test default), which would make a genuine multi-hour EL sync report{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">fully_synced=no</code> and silently skip the entire CL sweep for that anchor.
            </li>
            <li>
              <strong>Tip check</strong>: reads <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'artifacts/<run-id>/<anchor>__prysm/env.txt'}</code> and
              requires <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">fully_synced=yes</code>. If missing or not <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">yes</code>, logs a
              warning and <strong>skips the CL sweep for this anchor entirely</strong> (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">continue</code>)
              rather than running a CL sweep against an EL that never reached head.
            </li>
            <li>
              <strong>CL sweep</strong>: exports <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'ETH2QS_BAKEOFF_ANCHOR_EL=<anchor>'}</code>, then calls{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'run_candidate.sh <anchor> <cl>'}</code> for every CL in{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'<cls_csv>'}</code> — each invocation runs in anchor mode (§3.1), purging only the CL
              datadir between candidates and reusing the live, already-synced EL.
            </li>
            <li>
              Unsets <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_ANCHOR_EL</code> and moves to the next anchor in the list —
              establishing the next anchor&apos;s <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code> call will purge the{' '}
              <em>previous</em> anchor&apos;s EL datadir as part of its own normal pre-install cleanup, which is the
              &ldquo;rotation.&rdquo;
            </li>
          </ol>
          <p className="mt-3 text-sm text-muted-foreground">
            Same <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_CONFIRMED=yes</code> gate as <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code>. All
            results land in the same <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'artifacts/<run-id>/<el>__<cl>/'}</code> layout as a direct{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code> call, so <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code> needs no
            special-casing for anchor-mode rows. Ends by calling <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code> itself.
          </p>
        </section>

        {/* 7. summarize.sh */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="summarize" className="text-lg sm:text-xl font-semibold text-foreground">
            7. <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summarize.sh</code> — aggregation
          </AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            Reads every <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'artifacts/<run-id>/<el>__<cl>/'}</code> directory and produces three outputs,
            none of which overwrite the hand-curated <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">docs/CLIENT_BAKEOFF_RESULTS.md</code> (that file is
            the blog&apos;s source of truth and this script never touches it):
          </p>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground list-disc list-inside">
            <li>
              <strong><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summary.csv</code></strong> — one row per candidate:
              <CodeBlock language="text" code={summaryCsvColumns} className="mt-2 mb-2" />
              <ul className="mt-2 space-y-2 list-disc list-inside">
                <li>
                  <strong className="text-foreground">Sync-time derivation</strong>: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">_epoch</code> converts{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">started_at_utc</code>/<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">synced_at_utc</code> ISO-8601 stamps to epoch
                  seconds (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">date -u -d ... +%s</code>); their difference is <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">total_s</code>.{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">_install_wall_s</code> parses the <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">Elapsed (wall clock)</code> line
                  out of <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">/usr/bin/time -v</code>&apos;s <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">install-time.txt</code> (handles both{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">h:mm:ss</code> and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">m:ss.dd</code> forms).{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">sync_only_s = total_s - install_s</code> isolates sync time from install time;
                  negative results are discarded (clamped to empty) rather than shown as a nonsense negative
                  duration. <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">_fmt_hm</code> renders seconds as <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">XhYYm</code>.
                </li>
                <li>
                  <strong className="text-foreground">Last EL block</strong>: hex-decodes{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">execution_sync.result.currentBlock</code> from the last <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">samples.jsonl</code>{' '}
                  line — a progress proxy even for candidates that hit the 72h cap without finishing.
                </li>
                <li>
                  <strong className="text-foreground">Per-layer disk split</strong>:{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">el_bytes</code>/<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">cl_bytes</code> partition the chosen disk TSV (
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">disk-synced.tsv</code> if synced, else <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">disk-final.tsv</code>) by basename
                  match against EL/CL basenames extracted from{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">install/utils/purge_ethereum_data.sh</code>&apos;s <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">EL_DATA_DIRS</code>/
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">CL_DATA_DIRS</code> arrays via <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">awk</code>+<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">gensub</code> — exact
                  basename matching so e.g. <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">nimbus-eth1</code> and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">nimbus</code> are never
                  confused.
                </li>
              </ul>
            </li>
            <li>
              <strong><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">process-summary.csv</code></strong> — per-pair count of process-telemetry rows
              captured across the run (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{"jq -r '.processes[]?'"}</code> count from{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">samples.jsonl</code>).
            </li>
            <li>
              <strong><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">report.md</code></strong> — a human-readable dump: the{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">summary.csv</code> table (via <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">column -s, -t</code>) plus every
              candidate&apos;s <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">findings.md</code>, concatenated.
            </li>
            <li>
              <strong>A generated results skeleton</strong> at{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">$artifact_root/CLIENT_BAKEOFF_RESULTS.generated.md</code> (gitignored — never the
              committed <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">docs/CLIENT_BAKEOFF_RESULTS.md</code>), row-split into three sections by the{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal</code> column:
              <ul className="mt-2 space-y-1.5 list-disc list-inside">
                <li>
                  <strong className="text-foreground">&ldquo;Results (optimal config only)&rdquo;</strong> —{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=yes</code> and <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">anchor_synced != no</code>.
                </li>
                <li>
                  <strong className="text-foreground">&ldquo;Superseded — non-optimal config&rdquo;</strong> —{' '}
                  <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">config_optimal=no</code>, explicitly excluded from ranking with a note that
                  footprints aren&apos;t comparable.
                </li>
                <li>
                  <strong className="text-foreground">&ldquo;Pre-gate — unknown config&rdquo;</strong> — no verdict
                  recorded at all (pre-gate or triage-only rows).
                </li>
              </ul>
              <p className="mt-2">
                Plus placeholder <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">## Recommendation</code> /{' '}
                <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">## Final synced disk footprint</code> /{' '}
                <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">## Changes driven by this bake-off</code> sections with HTML comments telling the
                human reviewer what to fill in — this file is a <em>skeleton</em> for the curated doc, not a
                replacement for it.
              </p>
            </li>
          </ul>
        </section>

        {/* 8. Data model reference */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="data-model" className="text-lg sm:text-xl font-semibold text-foreground">8. Data model reference</AnchorHeading>
          <div className="mt-4 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-3 font-medium text-muted-foreground">File</th>
                  <th className="pb-3 font-medium text-muted-foreground">Written by</th>
                  <th className="pb-3 font-medium text-muted-foreground">Contents</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {dataModelRows.map((row) => (
                  <tr key={row.file}>
                    <td className="py-3 align-top font-medium text-foreground">
                      <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{row.file}</code>
                    </td>
                    <td className="py-3 align-top text-muted-foreground">{row.writtenBy}</td>
                    <td className="py-3 align-top text-muted-foreground">{row.contents}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        {/* 9. Hardening fixes */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="hardening-fixes" className="text-lg sm:text-xl font-semibold text-foreground">9. Hardening fixes visible in the code</AnchorHeading>
          <p className="mt-2 text-sm text-muted-foreground">
            These are defensive patterns baked into the harness as a result of real failures during the campaign
            (see <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">CLIENT_BAKEOFF_ISSUES_LOG.md</code> for the incidents that motivated them):
          </p>
          <ul className="mt-4 space-y-3 text-sm text-muted-foreground list-disc list-inside">
            <li>
              <strong className="text-foreground"><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">du</code>/pipefail resilience</strong> (
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_snapshot_disk</code>): <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">du -sb ... || true</code> survives a
              datadir file vanishing mid-walk during a live sync.
            </li>
            <li>
              <strong className="text-foreground">Capped-path capture</strong> (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">_has_token</code> in{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">bakeoff_check_config_optimal</code>): the <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--</code> before
              dash-prefixed patterns prevents <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">grep</code> from misparsing a pattern like{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">--prune-storage</code> as an option flag, which would otherwise exit 2 and get
              silently absorbed by <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'2>/dev/null'}</code> into a false &ldquo;miss.&rdquo;
            </li>
            <li>
              <strong className="text-foreground"><code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{'</dev/null'}</code> on every non-interactive command</strong> (
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">clean-data</code>, <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">phase2</code> install): prevents{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">SIGTTIN</code> when the harness runs detached from a controlling terminal
              (background process group).
            </li>
            <li>
              <strong className="text-foreground">Stall watchdog</strong> (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_STALL_RESTART</code>):
              entirely opt-in and inert by default; bounded restart count so a genuinely dead client still
              terminates the observation loop with a <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.stalled</code> marker rather than looping until the
              window cap.
            </li>
            <li>
              <strong className="text-foreground">Anchor-poison detection is read-only</strong>: the watchdog that
              guards a shared anchor EL during a CL sweep only ever marks state (
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.anchor-poisoned</code>) and logs — it never intervenes, because restarting or killing
              a shared anchor would invalidate every remaining candidate in the rotation, not just the current one.
            </li>
            <li>
              <strong className="text-foreground">FORCE-rerun poison-marker clear</strong>:{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ETH2QS_BAKEOFF_FORCE=yes</code> clears <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.anchor-poisoned</code> and{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">.done</code> together — without this, a stale poison marker from a previous attempt
              would silently survive a forced rerun and falsely finalize <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">anchor_synced=no</code> for an
              otherwise clean run.
            </li>
            <li>
              <strong className="text-foreground">Two-consecutive-sample sync confirmation</strong> (
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">synced_streak -ge 2</code> in <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">run_candidate.sh</code>,{' '}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">synced_streak</code> local to the observation loop): guards against a single racy
              sample where the EL and CL heads transiently appear caught up.
            </li>
          </ul>
        </section>

        {/* See also */}
        <section className="mt-10 sm:mt-16">
          <AnchorHeading id="see-also" className="text-lg sm:text-xl font-semibold text-foreground">See also</AnchorHeading>
          <ul className="mt-4 space-y-2 text-sm text-muted-foreground">
            {seeAlsoLinks.map((link) => (
              <li key={link.href}>
                <a href={link.href} target="_blank" rel="noopener noreferrer" className="font-mono text-xs text-primary hover:underline">
                  {link.file}
                </a>
                {' '}&mdash; {link.desc}
              </li>
            ))}
          </ul>
        </section>

        <ReadNext currentSlug="bakeoff-harness" />

        <Card padding="sm" className="mt-10 sm:mt-16 bg-muted/30">
          <p className="text-xs text-muted-foreground">
            <span className="font-medium text-foreground">Sources:</span> this page renders{' '}
            <a
              href={`${SITE_CONFIG.github}/blob/master/docs/CLIENT_BAKEOFF_HARNESS.md`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary hover:underline"
            >
              docs/CLIENT_BAKEOFF_HARNESS.md
            </a>{' '}
            on GitHub. See also the{' '}
            <a href="/blog/ethereum-client-bakeoff" className="text-primary hover:underline">
              bake-off results writeup
            </a>
            .
          </p>
        </Card>
      </div>
      <BackToTop />
    </div>
  )
}
