import { render } from '@testing-library/react'
import { SiteJsonLd } from '@/components/ui/SiteJsonLd'
import { SITE_CONFIG } from '@/lib/constants'

function renderJsonLd() {
  const { container } = render(<SiteJsonLd />)
  const script = container.querySelector('script[type="application/ld+json"]')
  expect(script).not.toBeNull()
  return JSON.parse(script!.innerHTML)
}

describe('SiteJsonLd', () => {
  it('emits valid JSON-LD (does not throw parsing)', () => {
    expect(() => renderJsonLd()).not.toThrow()
  })

  it('includes an Organization and a WebSite node', () => {
    const schema = renderJsonLd()
    expect(schema['@context']).toBe('https://schema.org')

    const org = schema['@graph'].find((node: any) => node['@type'] === 'Organization')
    expect(org).toBeDefined()
    expect(org.url).toBe(SITE_CONFIG.url)
    expect(org.sameAs).toContain(SITE_CONFIG.github)

    const site = schema['@graph'].find((node: any) => node['@type'] === 'WebSite')
    expect(site).toBeDefined()
    expect(site.url).toBe(SITE_CONFIG.url)
  })

  it('does not fabricate a SearchAction (no real site search exists)', () => {
    const schema = renderJsonLd()
    const site = schema['@graph'].find((node: any) => node['@type'] === 'WebSite')
    expect(site.potentialAction).toBeUndefined()
  })
})
