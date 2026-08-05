import { renderFeed } from '@/lib/rss'
import { ARTICLES } from '@/lib/articles'
import { SITE_CONFIG } from '@/lib/constants'

describe('rss.xml feed', () => {
  const body = renderFeed()

  it('is a well-formed RSS 2.0 body with a self link', () => {
    expect(body.startsWith('<?xml version="1.0" encoding="UTF-8"?>')).toBe(true)
    expect(body).toContain('<rss version="2.0"')
    expect(body).toContain(`<atom:link href="${SITE_CONFIG.url}/rss.xml" rel="self"`)
    expect(body.trimEnd().endsWith('</rss>')).toBe(true)
  })

  it('includes every article, newest first, with canonical links', () => {
    expect(body.match(/<item>/g)?.length).toBe(ARTICLES.length)
    for (const article of ARTICLES) {
      expect(body).toContain(`<link>${SITE_CONFIG.url}/blog/${article.slug}</link>`)
    }
    const newest = [...ARTICLES].sort((a, b) => (a.datePublished < b.datePublished ? 1 : -1))[0]
    const oldest = [...ARTICLES].sort((a, b) => (a.datePublished > b.datePublished ? 1 : -1))[0]
    expect(body.indexOf(newest.slug)).toBeLessThan(body.indexOf(oldest.slug))
  })

  it('escapes XML metacharacters so the feed can never be malformed', () => {
    // The channel title contains an ampersand ("Field notes & benchmarks"); it
    // must be entity-encoded, and no raw " & " may survive anywhere in the body.
    expect(body).toContain('Field notes &amp; benchmarks')
    expect(body).not.toMatch(/ & /)
  })

  it('uses a deterministic lastBuildDate (newest dateModified, not the wall clock)', () => {
    const newestModified = ARTICLES.reduce(
      (latest, a) => (a.dateModified > latest ? a.dateModified : latest),
      ARTICLES[0].dateModified,
    )
    const expected = new Date(`${newestModified}T00:00:00Z`).toUTCString()
    expect(body).toContain(`<lastBuildDate>${expected}</lastBuildDate>`)
  })
})
