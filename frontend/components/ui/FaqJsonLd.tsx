import { FAQ_ITEMS } from '@/lib/constants'

/**
 * FAQPage JSON-LD mirroring the visible FAQ in components/sections/Faq.tsx.
 * Both read from the same `FAQ_ITEMS` array in lib/constants.ts so the
 * visible copy and the structured data can never drift apart.
 *
 * Framing (see docs/GEO_AEO_DISCOVERABILITY_PLAN.md, item B1): Google
 * curtailed FAQPage rich snippets to gov/health sites in 2023, so this is
 * not expected to produce a Google rich result. The value here is LLM
 * answer-extraction — a model reading this page can lift a clean,
 * self-contained Q&A pair instead of summarizing prose.
 */
export function FaqJsonLd() {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: FAQ_ITEMS.map((item) => ({
      '@type': 'Question',
      name: item.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: item.answer,
      },
    })),
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}
