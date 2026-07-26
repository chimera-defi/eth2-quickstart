import { render } from '@testing-library/react'
import { ArticleJsonLd } from '@/components/ui/ArticleJsonLd'
import { ARTICLES, getArticle } from '@/lib/articles'
import { SITE_CONFIG } from '@/lib/constants'

function renderJsonLd(slug: string) {
  const { container } = render(<ArticleJsonLd slug={slug} />)
  const script = container.querySelector('script[type="application/ld+json"]')
  expect(script).not.toBeNull()
  return JSON.parse(script!.innerHTML)
}

describe('ArticleJsonLd', () => {
  const slug = ARTICLES[0].slug
  const article = getArticle(slug)

  it('emits valid JSON-LD (does not throw parsing)', () => {
    expect(() => renderJsonLd(slug)).not.toThrow()
  })

  it('includes a BlogPosting with absolute url/image on the site domain', () => {
    const schema = renderJsonLd(slug)
    const blogPosting = schema['@graph'].find(
      (node: any) => node['@type'] === 'BlogPosting'
    )
    expect(blogPosting).toBeDefined()
    expect(blogPosting.url).toBe(`${SITE_CONFIG.url}/blog/${slug}`)
    expect(blogPosting.url.startsWith(SITE_CONFIG.url)).toBe(true)
    expect(blogPosting.image).toBe(`${SITE_CONFIG.url}${article.ogImage}`)
    expect(blogPosting.image.startsWith(SITE_CONFIG.url)).toBe(true)
  })

  it('sets datePublished and dateModified', () => {
    const schema = renderJsonLd(slug)
    const blogPosting = schema['@graph'].find(
      (node: any) => node['@type'] === 'BlogPosting'
    )
    expect(blogPosting.datePublished).toBeTruthy()
    expect(blogPosting.dateModified).toBeTruthy()
  })

  it('strips the site-name suffix from headline', () => {
    const schema = renderJsonLd(slug)
    const blogPosting = schema['@graph'].find(
      (node: any) => node['@type'] === 'BlogPosting'
    )
    expect(blogPosting.headline).not.toContain('ETH2 Quick Start')
  })

  it('attributes author and publisher to the Organization, not a person', () => {
    const schema = renderJsonLd(slug)
    const blogPosting = schema['@graph'].find(
      (node: any) => node['@type'] === 'BlogPosting'
    )
    expect(blogPosting.author['@type']).toBe('Organization')
    expect(blogPosting.publisher['@type']).toBe('Organization')
  })

  it('has a Home -> Blog -> Article BreadcrumbList', () => {
    const schema = renderJsonLd(slug)
    const breadcrumb = schema['@graph'].find(
      (node: any) => node['@type'] === 'BreadcrumbList'
    )
    expect(breadcrumb).toBeDefined()
    const items = breadcrumb.itemListElement
    expect(items).toHaveLength(3)
    expect(items[0]).toMatchObject({ position: 1, name: 'Home', item: SITE_CONFIG.url })
    expect(items[1]).toMatchObject({
      position: 2,
      name: 'Blog',
      item: `${SITE_CONFIG.url}/blog`,
    })
    expect(items[2]).toMatchObject({
      position: 3,
      name: article.navTitle,
      item: `${SITE_CONFIG.url}/blog/${slug}`,
    })
  })
})
