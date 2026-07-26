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
  // Comparing a lookup's result against the registry it reads from is tautological,
  // so pin the flagship article's real values independently of the registry.
  it('returns the article identified by the slug, with its own values', () => {
    const article = getArticle('ethereum-client-bakeoff')
    expect(article.slug).toBe('ethereum-client-bakeoff')
    expect(article.ogImage).toBe('/og-bakeoff.png')
    expect(article.datePublished).toBe('2026-07-19')
    expect(article.navTitle).toBe('Ethereum client bake-off')
  })

  it('maps each slug to a distinct article, never a shared or default one', () => {
    for (const target of ARTICLES) {
      expect(getArticle(target.slug).slug).toBe(target.slug)
    }
    const images = ARTICLES.map((article) => getArticle(article.slug).ogImage)
    expect(new Set(images).size).toBe(ARTICLES.length)
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
