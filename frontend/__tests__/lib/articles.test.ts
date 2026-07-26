import { ARTICLES, getArticle, buildArticleMetadata } from '@/lib/articles'

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/

describe('ARTICLES registry', () => {
  it('has at least one article', () => {
    expect(ARTICLES.length).toBeGreaterThan(0)
  })

  it.each(ARTICLES.map((article) => [article.slug, article]))(
    '%s has all required non-empty fields',
    (_slug, article) => {
      expect(article.slug).toBeTruthy()
      expect(article.pageTitle).toBeTruthy()
      expect(article.pageDescription).toBeTruthy()
      expect(article.navTitle).toBeTruthy()
      expect(article.indexDescription).toBeTruthy()
      expect(article.ogImage).toBeTruthy()
      expect(article.ogAlt).toBeTruthy()
      expect(article.datePublished).toBeTruthy()
    }
  )

  it('has unique slugs', () => {
    const slugs = ARTICLES.map((a) => a.slug)
    expect(new Set(slugs).size).toBe(slugs.length)
  })

  it('has datePublished matching YYYY-MM-DD for every article', () => {
    ARTICLES.forEach((article) => {
      expect(article.datePublished).toMatch(DATE_RE)
    })
  })

  it('has ogImage paths that are site-relative PNGs', () => {
    ARTICLES.forEach((article) => {
      expect(article.ogImage.startsWith('/')).toBe(true)
      expect(article.ogImage.endsWith('.png')).toBe(true)
    })
  })

  // SEO length guards: these caught real bugs (a title or description that
  // silently grew past what search engines display in full).
  it('has pageTitle no longer than 60 characters', () => {
    ARTICLES.forEach((article) => {
      expect(article.pageTitle.length).toBeLessThanOrEqual(60)
    })
  })

  it('has pageDescription between 120 and 165 characters', () => {
    ARTICLES.forEach((article) => {
      expect(article.pageDescription.length).toBeGreaterThanOrEqual(120)
      expect(article.pageDescription.length).toBeLessThanOrEqual(165)
    })
  })
})

describe('getArticle', () => {
  it('returns the matching article for a known slug', () => {
    const target = ARTICLES[0]
    expect(getArticle(target.slug)).toEqual(target)
  })

  it('throws on an unknown slug', () => {
    expect(() => getArticle('not-a-real-slug')).toThrow(
      /unknown article slug/i
    )
  })
})

describe('buildArticleMetadata', () => {
  it('builds the canonical url as /blog/<slug>', () => {
    const article = ARTICLES[0]
    const metadata = buildArticleMetadata(article.slug)
    expect(metadata.alternates?.canonical).toBe(`/blog/${article.slug}`)
  })

  it('sets openGraph.type to article', () => {
    const article = ARTICLES[0]
    const metadata = buildArticleMetadata(article.slug)
    expect((metadata.openGraph as any)?.type).toBe('article')
  })

  it('provides an image with 1200x630 dimensions and non-empty alt', () => {
    const article = ARTICLES[0]
    const metadata = buildArticleMetadata(article.slug)
    const images = metadata.openGraph?.images
    expect(Array.isArray(images)).toBe(true)
    const image = (images as any[])[0]
    expect(image.width).toBe(1200)
    expect(image.height).toBe(630)
    expect(image.alt).toBeTruthy()
  })

  it('sets twitter.card to summary_large_image', () => {
    const article = ARTICLES[0]
    const metadata = buildArticleMetadata(article.slug)
    expect((metadata.twitter as any)?.card).toBe('summary_large_image')
  })

  it('throws when built for an unknown slug', () => {
    expect(() => buildArticleMetadata('nope')).toThrow(/unknown article slug/i)
  })
})
