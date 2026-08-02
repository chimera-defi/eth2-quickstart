import { getArticle } from '@/lib/articles'
import { SITE_CONFIG } from '@/lib/constants'

const ORGANIZATION = {
  '@type': 'Organization',
  name: SITE_CONFIG.shortName,
  url: SITE_CONFIG.url,
} as const

export interface ArticleJsonLdProps {
  /** Blog post slug, e.g. 'ethereum-client-bakeoff' — all other fields are resolved from the article registry. */
  slug: string
}

/**
 * Renders schema.org JSON-LD for a blog article: a BlogPosting plus a
 * Home → Blog → Article BreadcrumbList, as a single `@graph`. Organization-only
 * attribution (author + publisher) — no invented person byline.
 */
export function ArticleJsonLd({ slug }: ArticleJsonLdProps) {
  const article = getArticle(slug)
  const url = `${SITE_CONFIG.url}/blog/${article.slug}`

  const schema = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'BlogPosting',
        headline: article.headline,
        description: article.pageDescription,
        image: `${SITE_CONFIG.url}${article.ogImage}`,
        datePublished: article.datePublished,
        dateModified: article.dateModified,
        mainEntityOfPage: url,
        url,
        author: ORGANIZATION,
        publisher: ORGANIZATION,
      },
      {
        '@type': 'BreadcrumbList',
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: 'Home', item: SITE_CONFIG.url },
          { '@type': 'ListItem', position: 2, name: 'Blog', item: `${SITE_CONFIG.url}/blog` },
          { '@type': 'ListItem', position: 3, name: article.navTitle, item: url },
        ],
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
