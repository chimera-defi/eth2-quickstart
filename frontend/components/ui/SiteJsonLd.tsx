import { SITE_CONFIG } from '@/lib/constants'

/**
 * WebSite + Organization JSON-LD, rendered once in the root layout so it's
 * present on every page. Deliberately no `potentialAction` SearchAction —
 * there is no real site search to point it at, and a search action for a
 * search box that doesn't exist would be a false structured-data claim, not
 * a harmless omission.
 */
export function SiteJsonLd() {
  const schema = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'Organization',
        name: SITE_CONFIG.shortName,
        url: SITE_CONFIG.url,
        sameAs: [SITE_CONFIG.github],
      },
      {
        '@type': 'WebSite',
        name: SITE_CONFIG.shortName,
        url: SITE_CONFIG.url,
      },
    ],
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}
