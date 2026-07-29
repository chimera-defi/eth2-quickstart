import sitemap from '@/app/sitemap'
import { ARTICLES } from '@/lib/articles'

describe('sitemap', () => {
  const entries = sitemap()

  it('has every url on the canonical (non-hyphenated) domain', () => {
    entries.forEach((entry) => {
      expect(entry.url.startsWith('https://eth2quickstart.com')).toBe(true)
      expect(entry.url).not.toContain('eth2-quickstart.com')
    })
  })

  it('includes a route for every article in the registry', () => {
    ARTICLES.forEach((article) => {
      const match = entries.find((entry) =>
        entry.url.endsWith(`/blog/${article.slug}`)
      )
      expect(match).toBeDefined()
    })
  })

  it('has exactly one sitemap entry per article slug (no missing, no stale)', () => {
    const blogEntries = entries.filter((entry) =>
      /\/blog\/[^/]+$/.test(entry.url)
    )
    expect(blogEntries.length).toBe(ARTICLES.length)
  })

  it('includes the core static routes', () => {
    const paths = entries.map((entry) => entry.url)
    expect(paths).toContain('https://eth2quickstart.com')
    expect(paths).toContain('https://eth2quickstart.com/quickstart')
    expect(paths).toContain('https://eth2quickstart.com/blog')
  })

  it('includes the agent-discoverability routes (/agents, /llms.txt, /llms-full.txt)', () => {
    const paths = entries.map((entry) => entry.url)
    expect(paths).toContain('https://eth2quickstart.com/agents')
    expect(paths).toContain('https://eth2quickstart.com/llms.txt')
    expect(paths).toContain('https://eth2quickstart.com/llms-full.txt')
  })
})
