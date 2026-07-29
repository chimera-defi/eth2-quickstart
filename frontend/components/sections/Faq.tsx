import { FAQ_ITEMS } from '@/lib/constants'

/**
 * Plain server component (no 'use client', no JS needed) — the disclosure
 * behavior is native <details>/<summary>, styled with Tailwind's `open:`
 * variant. Content mirrors FaqJsonLd.tsx exactly (same FAQ_ITEMS source), so
 * it stays fully present in the server-rendered HTML for both human readers
 * and LLM crawlers regardless of whether JS runs.
 */
export function Faq() {
  return (
    <section id="faq" className="py-12 sm:py-16 md:py-20 lg:py-24">
      <div className="mx-auto max-w-3xl px-4 sm:px-6">
        <div className="max-w-2xl">
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            FAQ
          </p>
          <h2 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            Frequently asked questions
          </h2>
        </div>

        <div className="mt-8 sm:mt-10 divide-y divide-border rounded-xl border border-border">
          {FAQ_ITEMS.map((item) => (
            <details key={item.question} className="group p-4 sm:p-6 open:bg-muted/20">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-4 font-medium text-foreground [&::-webkit-details-marker]:hidden">
                {item.question}
                <span
                  aria-hidden="true"
                  className="shrink-0 text-lg leading-none text-muted-foreground transition-transform duration-200 group-open:rotate-45"
                >
                  +
                </span>
              </summary>
              <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
                {item.answer}
              </p>
            </details>
          ))}
        </div>
      </div>
    </section>
  )
}
