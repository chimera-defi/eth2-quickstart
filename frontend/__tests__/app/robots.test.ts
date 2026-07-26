import robots from '@/app/robots'
import { SITE_CONFIG } from '@/lib/constants'

describe('robots', () => {
  const result = robots()

  it('allows all crawling for every user agent', () => {
    expect(result.rules).toEqual({ userAgent: '*', allow: '/' })
  })

  it('points sitemap and host at the same domain as SITE_CONFIG.url', () => {
    expect(result.sitemap).toBe(`${SITE_CONFIG.url}/sitemap.xml`)
    expect(result.host).toBe(SITE_CONFIG.url)
  })

  it('uses the canonical non-hyphenated domain literally (guards a wrong constant)', () => {
    expect(result.host).toBe('https://eth2quickstart.com')
    expect(result.sitemap).toBe('https://eth2quickstart.com/sitemap.xml')
  })
})
