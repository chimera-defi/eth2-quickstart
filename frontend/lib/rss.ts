import { ARTICLES } from './articles'
import { SITE_CONFIG } from './constants'

/**
 * RSS 2.0 feed builder for the blog. Lives in lib/ (not the route file) because
 * a Next.js route module may only export the framework's reserved names
 * (GET, dynamic, ...) — exporting a helper from route.ts fails `next build`.
 *
 * BUILD SAFETY (incident 2026-07-29): the route pre-renders this at build time,
 * and a throw would fail `next build` — a failed publish is invisible (the site
 * keeps serving the old build and answering 200). So `renderFeed()` can never
 * throw: any error falls back to a valid item-less feed.
 */

export const RSS_CONTENT_TYPE = 'application/rss+xml; charset=utf-8'

const FEED_TITLE = 'ETH2 Quick Start — Field notes & benchmarks'
const FEED_DESCRIPTION =
  'Real results from a six-week Ethereum client bake-off: disk footprints, sync times, restart resilience, and the harness behind them.'

function escapeXml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
}

/** Article dates are `YYYY-MM-DD`; pin to UTC midnight for a stable RFC-822 string. */
function toRfc822(iso: string): string {
  const date = new Date(`${iso}T00:00:00Z`)
  return Number.isNaN(date.getTime()) ? new Date(0).toUTCString() : date.toUTCString()
}

function buildFeed(): string {
  const base = SITE_CONFIG.url
  const items = [...ARTICLES]
    // Newest first — the order a reader expects in a feed.
    .sort((a, b) => (a.datePublished < b.datePublished ? 1 : -1))
    .map((article) => {
      const url = `${base}/blog/${article.slug}`
      return [
        '    <item>',
        `      <title>${escapeXml(article.navTitle)}</title>`,
        `      <link>${url}</link>`,
        `      <guid isPermaLink="true">${url}</guid>`,
        `      <description>${escapeXml(article.indexDescription)}</description>`,
        `      <pubDate>${toRfc822(article.datePublished)}</pubDate>`,
        '    </item>',
      ].join('\n')
    })
    .join('\n')

  // Deterministic lastBuildDate: the most recent article edit, not the wall
  // clock — so an unchanged corpus produces a byte-identical feed each build.
  const lastBuild = ARTICLES.reduce(
    (latest, a) => (a.dateModified > latest ? a.dateModified : latest),
    ARTICLES[0]?.dateModified ?? '1970-01-01',
  )

  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">',
    '  <channel>',
    `    <title>${escapeXml(FEED_TITLE)}</title>`,
    `    <link>${base}/blog</link>`,
    `    <description>${escapeXml(FEED_DESCRIPTION)}</description>`,
    '    <language>en-us</language>',
    `    <atom:link href="${base}/rss.xml" rel="self" type="application/rss+xml" />`,
    `    <lastBuildDate>${toRfc822(lastBuild)}</lastBuildDate>`,
    items,
    '  </channel>',
    '</rss>',
    '',
  ].join('\n')
}

/** Valid, item-less feed used only if buildFeed() ever throws — never fail the build. */
function fallbackFeed(): string {
  const base = SITE_CONFIG.url
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">',
    '  <channel>',
    `    <title>${escapeXml(FEED_TITLE)}</title>`,
    `    <link>${base}/blog</link>`,
    `    <description>${escapeXml(FEED_DESCRIPTION)}</description>`,
    '    <language>en-us</language>',
    `    <atom:link href="${base}/rss.xml" rel="self" type="application/rss+xml" />`,
    '  </channel>',
    '</rss>',
    '',
  ].join('\n')
}

/**
 * The feed body as a string. The try/catch is the build-safety guarantee: any
 * error yields a valid item-less feed rather than throwing.
 */
export function renderFeed(): string {
  try {
    return buildFeed()
  } catch {
    return fallbackFeed()
  }
}
