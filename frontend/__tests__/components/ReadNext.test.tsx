import { render, screen } from '@testing-library/react'
import { ReadNext } from '@/components/ui/ReadNext'
import { ARTICLES } from '@/lib/articles'

describe('ReadNext', () => {
  it.each(ARTICLES.map((article) => [article.slug]))(
    'for slug %s: renders exactly 3 links, never itself, each pointing at /blog/<slug>',
    (slug) => {
      render(<ReadNext currentSlug={slug} />)
      const links = screen.getAllByRole('link')
      expect(links).toHaveLength(ARTICLES.length - 1)

      const hrefs = links.map((link) => link.getAttribute('href'))
      expect(hrefs).not.toContain(`/blog/${slug}`)

      hrefs.forEach((href) => {
        expect(href).toMatch(/^\/blog\/[^/]+$/)
      })

      const otherSlugs = ARTICLES.filter((a) => a.slug !== slug).map(
        (a) => `/blog/${a.slug}`
      )
      expect(new Set(hrefs)).toEqual(new Set(otherSlugs))
    }
  )
})
