const SITE_URL = 'https://eth2quickstart.com'

const ORGANIZATION = {
  '@type': 'Organization',
  name: 'ETH2 Quick Start',
  url: SITE_URL,
} as const

export interface ArticleJsonLdProps {
  title: string
  description: string
  /** Blog post slug, e.g. 'ethereum-client-bakeoff' — used to build the canonical URL. */
  slug: string
  /** Site-relative image path, e.g. '/og-bakeoff.png' — resolved to an absolute URL. */
  image: string
  /** ISO date string, e.g. '2026-07-19'. */
  datePublished: string
}

/**
 * Renders a schema.org BlogPosting JSON-LD block for a blog article. Organization-only
 * attribution (author + publisher) — no invented person byline.
 */
export function ArticleJsonLd({ title, description, slug, image, datePublished }: ArticleJsonLdProps) {
  const url = `${SITE_URL}/blog/${slug}`

  const schema = {
    '@context': 'https://schema.org',
    '@type': 'BlogPosting',
    headline: title,
    description,
    image: `${SITE_URL}${image}`,
    datePublished,
    mainEntityOfPage: url,
    url,
    author: ORGANIZATION,
    publisher: ORGANIZATION,
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}
