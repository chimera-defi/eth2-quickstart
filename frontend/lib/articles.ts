import type { Metadata } from 'next'
import { SITE_CONFIG } from './constants'

/**
 * Single source of truth for per-article identity: everything that used to be
 * duplicated across each article's page.tsx, ArticleJsonLd, ReadNext, the blog
 * index, and the sitemap.
 *
 * `pageTitle`/`pageDescription` (full SEO <title>/OG copy) and `navTitle`/
 * `indexDescription` (short display copy for ReadNext + the blog index/homepage
 * card) are separately authored strings — do not derive one from the other.
 */
export interface Article {
  slug: string
  /** Full SEO <title> / OG title, e.g. 'Ethereum Client Bake-off - ETH2 Quick Start'. */
  pageTitle: string
  /** Full SEO meta description / OG description. */
  pageDescription: string
  /** Short display title used by ReadNext and the blog index. */
  navTitle: string
  /** Blog-index + homepage card description. */
  indexDescription: string
  eyebrow: string
  /** Site-relative OG/twitter image path, e.g. '/og-bakeoff.png'. */
  ogImage: string
  ogAlt: string
  /** JSON-LD headline — pageTitle with the trailing site-name suffix stripped. */
  headline: string
  datePublished: string
  /** Last date the article's content was materially edited (data corrections, new findings, etc.). */
  dateModified: string
  sitemapPriority: number
}

export const ARTICLES: Article[] = [
  {
    slug: 'ethereum-client-bakeoff',
    pageTitle: 'Ethereum Client Bake-off - ETH2 Quick Start',
    pageDescription:
      'Results from a six-week Ethereum execution and consensus client sync campaign, including the restart-resilience findings the headline numbers hide.',
    navTitle: 'Ethereum client bake-off',
    indexDescription:
      'Results from a six-week execution and consensus client sync campaign: disk, speed, and restart resilience across the full client roster.',
    eyebrow: 'Client research',
    ogImage: '/og-bakeoff.png',
    ogAlt: 'The fastest Ethereum client is one almost nobody runs — a six-week client bake-off',
    headline: 'Ethereum Client Bake-off',
    datePublished: '2026-07-19',
    dateModified: '2026-08-06',
    sitemapPriority: 0.9,
  },
  {
    slug: 'how-we-tested-with-claude',
    pageTitle: 'How We Ran a 6-Week Bake-off With Claude - ETH2 Quick Start',
    pageDescription:
      "The agent orchestration model, the harness, and what actually breaks when a six-week benchmark runs on a shared host with an AI in the driver's seat.",
    navTitle: 'How we tested with Claude',
    indexDescription:
      'The orchestration model and harness behind the six-week campaign — how a fleet of agents ran, sampled, and gated every client sync.',
    eyebrow: 'Methodology',
    ogImage: '/og-how-we-tested.png',
    ogAlt: 'How we ran a six-week Ethereum client bake-off with Claude',
    headline: 'How We Ran a 6-Week Bake-off With Claude',
    datePublished: '2026-07-22',
    dateModified: '2026-08-06',
    sitemapPriority: 0.8,
  },
  {
    slug: 'bakeoff-harness',
    pageTitle: 'The Bake-off Harness — ETH2 Quick Start',
    pageDescription:
      'A function-level engineering reference for the bake-off harness: every script under test/bakeoff/, every function it calls, every flag, and data file.',
    navTitle: 'The bake-off harness',
    indexDescription:
      'A function-level engineering reference for the harness: the orchestrator, the per-candidate state machine, resource caps, and the probe/sample/gate library.',
    eyebrow: 'Engineering',
    ogImage: '/og-harness.png',
    ogAlt: 'The bake-off harness — a function-level engineering reference',
    headline: 'The Bake-off Harness',
    datePublished: '2026-07-21',
    dateModified: '2026-08-01',
    sitemapPriority: 0.8,
  },
  {
    slug: 'bakeoff-results',
    pageTitle: 'Bake-off Results — ETH2 Quick Start',
    pageDescription:
      'The raw results from the six-week Ethereum client bake-off — every triage row, footprint measurement, and gotcha — verbatim from CLIENT_BAKEOFF_RESULTS.md.',
    navTitle: 'Bake-off results',
    indexDescription:
      'The raw results: Stage A pass matrix, final synced disk footprints, the consensus-client matrices, and operational-viability notes.',
    eyebrow: 'Data',
    ogImage: '/og-results.png',
    ogAlt: 'Bake-off results — the raw data',
    headline: 'Bake-off Results',
    datePublished: '2026-07-21',
    dateModified: '2026-08-06',
    sitemapPriority: 0.8,
  },
]

/** Formats a `YYYY-MM-DD` article date as e.g. "Aug 1, 2026", pinned to UTC so
 * server and client render the same string regardless of local timezone. */
export function formatArticleDate(iso: string): string {
  return new Date(`${iso}T00:00:00Z`).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    timeZone: 'UTC',
  })
}

export function getArticle(slug: string): Article {
  const article = ARTICLES.find((a) => a.slug === slug)
  if (!article) {
    throw new Error(`getArticle: unknown article slug "${slug}"`)
  }
  return article
}

/** Builds the exact metadata shape every article page.tsx previously hand-wrote. */
export function buildArticleMetadata(slug: string): Metadata {
  const article = getArticle(slug)
  const url = `/blog/${article.slug}`
  const images = [{ url: article.ogImage, width: 1200, height: 630, alt: article.ogAlt }]

  return {
    title: article.pageTitle,
    description: article.pageDescription,
    alternates: { canonical: url },
    openGraph: {
      type: 'article',
      siteName: SITE_CONFIG.shortName,
      images,
      url,
      title: article.pageTitle,
      description: article.pageDescription,
    },
    twitter: {
      card: 'summary_large_image',
      images,
      title: article.pageTitle,
      description: article.pageDescription,
    },
  }
}
