import type { Metadata } from 'next'
import Link from 'next/link'
import { AnchorHeading } from '@/components/ui/AnchorHeading'
import { ArticleJsonLd } from '@/components/ui/ArticleJsonLd'
import { ArticleToc } from '@/components/ui/ArticleToc'
import { BackToTop } from '@/components/ui/BackToTop'
import { ReadNext } from '@/components/ui/ReadNext'
import { ArticleByline } from '@/components/ui/ArticleByline'
import { buildArticleMetadata } from '@/lib/articles'

export const metadata: Metadata = buildArticleMetadata('ethereum-client-bakeoff')

const tocLinks = [
  { label: 'The short answer', href: '#the-short-answer' },
  { label: 'How we tested', href: '#how-we-tested' },
  { label: 'Speed: one client wins by hours', href: '#speed' },
  { label: 'Disk: no winner, because the setting decides', href: '#the-disk-story' },
  { label: 'Restarts: the test that matters', href: '#restart-resilience' },
  { label: 'Consensus clients: pick on disk and familiarity', href: '#consensus-layer' },
  { label: "What we'd tell a friend", href: '#recommendations' },
]

export default function EthereumClientBakeoffPage() {
  return (
    <div className="min-h-screen py-12 sm:py-16 md:py-24">
      <div className="mx-auto max-w-5xl px-4 sm:px-6">
        <ArticleJsonLd slug="ethereum-client-bakeoff" />
        <header id="article-top" tabIndex={-1} className="focus:outline-none">
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">Blog</p>
          <ArticleByline slug="ethereum-client-bakeoff" />
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            Which Ethereum Client Should You Run at Home? Watch What Happens When You Restart It
          </h1>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            If you run, or are about to run, an Ethereum validator at home, this is for you: we tried to sync seven execution clients and six consensus clients on the same machine to see which ones are worth running. The short answer is geth or nethermind, with lighthouse as the consensus client. The longer answer is more interesting: the fastest client we tested is also the one most likely to ruin your afternoon, and the reason isn&apos;t in the numbers benchmarks usually publish.
          </p>
        </header>

        <ArticleToc links={tocLinks} />
        <section className="mt-10 sm:mt-16 border-t border-border pt-6" aria-labelledby="the-short-answer">
          <AnchorHeading id="the-short-answer" className="text-lg sm:text-xl font-semibold text-foreground">
            The short answer
          </AnchorHeading>
          <div className="mt-4 sm:mt-6 max-w-full overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary" role="region" aria-label="The short answer table" tabIndex={0}>
            <table className="w-full sm:min-w-[42rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">If you want…</th>
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">Run</th>
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">Why</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr>
                  <td className="py-3 align-top text-muted-foreground">The safe default</td>
                  <td className="py-3 align-top text-muted-foreground"><strong className="text-foreground">geth</strong></td>
                  <td className="py-3 align-top text-muted-foreground">Synced cleanly in ~8h28m and picked up where it left off after a ~52-hour shutdown.</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">A less common client, or a smaller disk</td>
                  <td className="py-3 align-top text-muted-foreground"><strong className="text-foreground">nethermind</strong></td>
                  <td className="py-3 align-top text-muted-foreground">Recovered from every restart gap we tried (with full history on). The installer&apos;s default setup is ~250–280 GiB right after sync.</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">A consensus client</td>
                  <td className="py-3 align-top text-muted-foreground"><strong className="text-foreground">lighthouse</strong> (or any of the five we compared)</td>
                  <td className="py-3 align-top text-muted-foreground">All five synced in minutes without crashing. They differ mainly in disk use.</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">The fastest sync</td>
                  <td className="py-3 align-top text-muted-foreground">ethrex, but not yet</td>
                  <td className="py-3 align-top text-muted-foreground">Synced in ~2h16m, then stalled after a 26-minute stop and started over after a ~2-hour one.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6" aria-labelledby="how-we-tested">
          <AnchorHeading id="how-we-tested" className="text-lg sm:text-xl font-semibold text-foreground">
            How we tested
          </AnchorHeading>
          <p className="mt-3 text-sm text-muted-foreground">
            We ran one client at a time on a single test server (no validator keys) and gave each up to 72 hours to reach the head of mainnet, the newest block. Each client was installed with the open-source eth2-quickstart installer.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            An Ethereum node is two programs. The <strong className="text-foreground">execution client</strong> (geth, nethermind, besu, …) holds the chain&apos;s state and runs transactions. The <strong className="text-foreground">consensus client</strong> (prysm, lighthouse, …) follows the proof-of-stake chain and tells the execution client which block is current. To compare execution clients fairly, we paired every one with the same consensus client, prysm. Then we tested the other five consensus clients against a fixed execution client.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            For each client we recorded how long it took to sync and how much disk it used. Disk use keeps changing after a sync, so each figure below says when it was taken.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6" aria-labelledby="speed">
          <AnchorHeading id="speed" className="text-lg sm:text-xl font-semibold text-foreground">
            Speed: one client wins by hours
          </AnchorHeading>
          <p className="mt-3 text-sm text-muted-foreground">
            Time to a fully synced, validating node:
          </p>
          <div className="mt-4 sm:mt-6 max-w-full overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary" role="region" aria-label="Speed: one client wins by hours table" tabIndex={0}>
            <table className="w-full sm:min-w-[42rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">Execution client</th>
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">Sync time</th>
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">Result</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr>
                  <td className="py-3 align-top text-muted-foreground">ethrex</td>
                  <td className="py-3 align-top text-muted-foreground">~2h16m (v19)</td>
                  <td className="py-3 align-top text-muted-foreground">synced</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">geth</td>
                  <td className="py-3 align-top text-muted-foreground">~8h28m</td>
                  <td className="py-3 align-top text-muted-foreground">synced</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">nethermind</td>
                  <td className="py-3 align-top text-muted-foreground">~14.5h</td>
                  <td className="py-3 align-top text-muted-foreground">synced</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">besu</td>
                  <td className="py-3 align-top text-muted-foreground">~19h18m</td>
                  <td className="py-3 align-top text-muted-foreground">synced</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">reth</td>
                  <td className="py-3 align-top text-muted-foreground">—</td>
                  <td className="py-3 align-top text-muted-foreground">~47% of blocks (~21% of the work) when the 72h cap hit</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">nimbus_eth1</td>
                  <td className="py-3 align-top text-muted-foreground">—</td>
                  <td className="py-3 align-top text-muted-foreground">~21.6% when the 72h cap hit</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">erigon</td>
                  <td className="py-3 align-top text-muted-foreground">—</td>
                  <td className="py-3 align-top text-muted-foreground">stuck, never synced</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-sm text-muted-foreground">
            ethrex finished nearly 4× faster than geth, ahead of every established client by hours.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            reth and nimbus_eth1, as we ran them, don&apos;t <strong className="text-foreground">snap sync</strong>, where a client downloads a recent copy of the state instead of replaying every block since 2015. That&apos;s a design choice, not a bug, and reth is widely run elsewhere. Plan on days, not hours, for the first sync if you pick one.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            erigon (version 3) never synced. Paired with prysm started from a recent trusted snapshot (a checkpoint), each side waited for the other to make the next move, and neither did. Avoid that combination for now.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6" aria-labelledby="the-disk-story">
          <AnchorHeading id="the-disk-story" className="text-lg sm:text-xl font-semibold text-foreground">
            Disk: no winner, because the setting decides
          </AnchorHeading>
          <p className="mt-3 text-sm text-muted-foreground">
            Disk use for the clients that finished, once it stopped growing unless noted:
          </p>
          <div className="mt-4 sm:mt-6 max-w-full overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary" role="region" aria-label="Disk: no winner, because the setting decides table" tabIndex={0}>
            <table className="w-full sm:min-w-[42rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">Execution client</th>
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">Disk</th>
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">What it keeps</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr>
                  <td className="py-3 align-top text-muted-foreground">geth</td>
                  <td className="py-3 align-top text-muted-foreground">~1.13 TiB</td>
                  <td className="py-3 align-top text-muted-foreground">blocks and receipts since the Merge</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">besu</td>
                  <td className="py-3 align-top text-muted-foreground">~1.08 TiB</td>
                  <td className="py-3 align-top text-muted-foreground">full block history</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">nethermind, full history</td>
                  <td className="py-3 align-top text-muted-foreground">~1.06 TiB</td>
                  <td className="py-3 align-top text-muted-foreground">blocks and receipts since the Merge</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">ethrex (a later re-sync)</td>
                  <td className="py-3 align-top text-muted-foreground">~470–476 GiB</td>
                  <td className="py-3 align-top text-muted-foreground">almost no history</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">nethermind, minimal history (installer default)</td>
                  <td className="py-3 align-top text-muted-foreground">~250–280 GiB right after sync</td>
                  <td className="py-3 align-top text-muted-foreground">no old blocks or receipts</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-sm text-muted-foreground">
            The three clients that keep block history (since the Merge, Ethereum&apos;s 2022 switch to proof of stake, or longer) all land around 1.1 TiB. Disk size comes from how much history you keep, not from which client you run.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            So the useful question is: <strong className="text-foreground">do you need old history at all?</strong> A validator doesn&apos;t. It needs current state and new blocks. History only matters if other people query your node over RPC (the API wallets and apps use to read the chain) for past transactions: indexers, block explorers, tax tools.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            That&apos;s why the installer sets nethermind to minimal history by default (<code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">NETHERMIND_FULL_HISTORY=false</code>): a fraction of the full-history size, but it can&apos;t serve old blocks, logs or receipts. If you&apos;ll serve public RPC, set <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">NETHERMIND_FULL_HISTORY=true</code> before the first sync; switching later means rebuilding the data directory. ethrex makes the same trade without asking: it serves nothing older than where its sync started, so it can&apos;t stand in for a geth RPC endpoint.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            One trap when reading anyone&apos;s disk numbers, ours included: with full history on, nethermind measured ~251 GiB right after its sync finished and ~1.06 TiB once it had downloaded the post-Merge history in the background. A disk figure without its timing can be off by 4×.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6" aria-labelledby="restart-resilience">
          <AnchorHeading id="restart-resilience" className="text-lg sm:text-xl font-semibold text-foreground">
            Restarts: the test that matters
          </AnchorHeading>
          <p className="mt-3 text-sm text-muted-foreground">
            You will restart your node: client upgrades, OS updates, power cuts. What the client does next matters more day to day than how fast it synced the first time.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            One fact explains the results. Peers only serve the chain&apos;s <em>current state</em> for roughly the last 128 blocks, about 25 minutes. A client that catches up by importing the blocks it missed doesn&apos;t need that state. A client that needs peers to hand it state or headers from before it stopped gets stuck once those are older than the window.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <strong className="text-foreground">1. Picks up where it left off: geth and nethermind.</strong> We stopped geth for ~52 hours (~15,400 blocks); on restart it imported the missed blocks and got back to the head. With full history on, we stopped nethermind for 12 minutes up to 4 hours: a 12-minute gap took ~2 minutes to close, a 4-hour gap ~8 minutes. Separately, a consensus-client restart left it ~35 hours behind, and it caught up in ~35 minutes. No gap broke it. We didn&apos;t restart-test the installer&apos;s minimal-history default, so its restart behaviour is likely the same but unmeasured.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <strong className="text-foreground">2. Falls off a cliff: ethrex.</strong> We stopped ethrex for longer and longer gaps:
          </p>
          <div className="mt-4 sm:mt-6 max-w-full overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary" role="region" aria-label="Restarts: the test that matters table" tabIndex={0}>
            <table className="w-full sm:min-w-[42rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">Stopped for</th>
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">Blocks missed</th>
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">What happened</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr>
                  <td className="py-3 align-top text-muted-foreground">12 min</td>
                  <td className="py-3 align-top text-muted-foreground">68</td>
                  <td className="py-3 align-top text-muted-foreground">resumed</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">20 min</td>
                  <td className="py-3 align-top text-muted-foreground">108</td>
                  <td className="py-3 align-top text-muted-foreground">resumed</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">23 min</td>
                  <td className="py-3 align-top text-muted-foreground">124</td>
                  <td className="py-3 align-top text-muted-foreground">resumed</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">26 min</td>
                  <td className="py-3 align-top text-muted-foreground">132</td>
                  <td className="py-3 align-top text-muted-foreground">stuck: head frozen, couldn&apos;t fetch the missing headers</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-sm text-muted-foreground">
            After a routine 1.5–2 hour stop it went further: it threw away its fully synced data directory and started over, a re-sync that took 2h11m. That was v19.0.0, and ethrex moves fast, so newer versions may do better. But a node that can wipe itself after a two-hour maintenance window is a hard sell for something meant to run unattended.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            <strong className="text-foreground">3. Can break mid-sync: besu.</strong> besu&apos;s first sync was fine. On a later re-sync, our consensus client (an outdated prysm release) stalled for ~28 hours. With nothing telling it which block was current, besu&apos;s sync fell outside that ~25-minute window and its sync thread died, while the process kept running and answering RPC. It <em>looked</em> healthy. Restarting got stuck the same way. Two lessons: keep your consensus client up to date and healthy while besu syncs, and don&apos;t take a node that answers requests as proof that it&apos;s still syncing.
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6" aria-labelledby="consensus-layer">
          <AnchorHeading id="consensus-layer" className="text-lg sm:text-xl font-semibold text-foreground">
            Consensus clients: pick on disk and familiarity
          </AnchorHeading>
          <p className="mt-3 text-sm text-muted-foreground">
            All five consensus clients we tried (lighthouse, lodestar, grandine, teku, nimbus) started from a recent checkpoint and reached a validating head in 6–9 minutes with geth, without crashing. Disk use, measured minutes after sync:
          </p>
          <div className="mt-4 sm:mt-6 max-w-full overflow-x-auto rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary" role="region" aria-label="Consensus clients: pick on disk and familiarity table" tabIndex={0}>
            <table className="w-full sm:min-w-[42rem] text-sm [&_th]:px-3 [&_td]:px-3 [&_th:first-child]:pl-0 [&_td:first-child]:pl-0 [&_th:last-child]:pr-0 [&_td:last-child]:pr-0">
              <thead>
                <tr className="border-b border-border text-left">
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">Consensus client</th>
                  <th scope="col" className="pb-3 font-medium text-muted-foreground">Disk after sync</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr>
                  <td className="py-3 align-top text-muted-foreground">lodestar</td>
                  <td className="py-3 align-top text-muted-foreground">~177 MiB</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">lighthouse</td>
                  <td className="py-3 align-top text-muted-foreground">~518 MiB</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">grandine</td>
                  <td className="py-3 align-top text-muted-foreground">~725 MiB</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">teku</td>
                  <td className="py-3 align-top text-muted-foreground">~936 MiB</td>
                </tr>
                <tr>
                  <td className="py-3 align-top text-muted-foreground">nimbus</td>
                  <td className="py-3 align-top text-muted-foreground">~1.2 GiB</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-sm text-muted-foreground">
            These grow as the client runs, but the same three groups held when we repeated the test with nethermind and ethrex: lodestar and lighthouse lightest, teku and grandine in the middle, nimbus heaviest. Any of them is fine; lighthouse is a lean, safe default. (On the consensus side we only restart-tested prysm. It resumed from its own database each time, back in sync ~2m44s after a 30-minute stop.)
          </p>
        </section>

        <section className="mt-10 sm:mt-16 border-t border-border pt-6" aria-labelledby="recommendations">
          <AnchorHeading id="recommendations" className="text-lg sm:text-xl font-semibold text-foreground">
            What we&apos;d tell a friend
          </AnchorHeading>
          <ul className="mt-4 list-disc space-y-3 pl-5 text-sm text-muted-foreground">
            <li>Run <strong className="text-foreground">geth</strong> with <strong className="text-foreground">lighthouse</strong> unless you have a reason not to.</li>
            <li>For client diversity, or a much smaller disk, run <strong className="text-foreground">nethermind</strong> at its minimal-history default. Switch to full history before the first sync only if you&apos;ll serve public RPC.</li>
            <li>Size your disk for steady state, not for the number a client shows the moment it syncs.</li>
            <li>Test what happens when you restart, not just how fast the first sync goes.</li>
            <li>Keep an eye on <strong className="text-foreground">ethrex</strong>, but check its restart behaviour on a current release first.</li>
            <li>As we ran them, <strong className="text-foreground">reth</strong> and <strong className="text-foreground">nimbus_eth1</strong> need days for a first sync; don&apos;t pair <strong className="text-foreground">erigon 3</strong> with a checkpoint-synced prysm yet.</li>
          </ul>
          <hr className="my-6 border-border" />
          <p className="mt-3 text-sm text-muted-foreground">
            Every measured number here, with per-run detail and the full incident log, is on the <Link href="/blog/bakeoff-results" className="text-primary underline underline-offset-2">raw results page</Link>.
          </p>
        </section>

        <ReadNext currentSlug="ethereum-client-bakeoff" />
      </div>
      <BackToTop />
    </div>
  )
}
