import { render } from '@testing-library/react'
import { SoftwareAppJsonLd } from '@/components/ui/SoftwareAppJsonLd'
import { SITE_CONFIG, EXECUTION_CLIENTS, CONSENSUS_CLIENTS } from '@/lib/constants'

function renderJsonLd() {
  const { container } = render(<SoftwareAppJsonLd />)
  const script = container.querySelector('script[type="application/ld+json"]')
  expect(script).not.toBeNull()
  return JSON.parse(script!.innerHTML)
}

describe('SoftwareAppJsonLd', () => {
  it('emits valid JSON-LD (does not throw parsing)', () => {
    expect(() => renderJsonLd()).not.toThrow()
  })

  it('is a SoftwareApplication with the site identity', () => {
    const schema = renderJsonLd()
    expect(schema['@context']).toBe('https://schema.org')
    expect(schema['@type']).toBe('SoftwareApplication')
    expect(schema.name).toBe(SITE_CONFIG.name)
    expect(schema.description).toBe(SITE_CONFIG.description)
    expect(schema.url).toBe(SITE_CONFIG.url)
    expect(schema.sameAs).toContain(SITE_CONFIG.github)
  })

  it('declares a defensible, non-overclaiming category and free pricing', () => {
    const schema = renderJsonLd()
    expect(schema.applicationCategory).toBe('DeveloperApplication')
    expect(schema.operatingSystem).toMatch(/Linux/)
    expect(schema.isAccessibleForFree).toBe(true)
    expect(schema.offers).toMatchObject({
      '@type': 'Offer',
      price: '0',
      priceCurrency: 'USD',
    })
  })

  it('derives softwareRequirements and featureList from constants (no hardcoded duplicates)', () => {
    const schema = renderJsonLd()
    expect(typeof schema.softwareRequirements).toBe('string')
    expect(schema.softwareRequirements).toMatch(/Storage/)
    expect(schema.softwareRequirements).toMatch(/Memory/)
    expect(schema.softwareRequirements).toMatch(/CPU/)

    expect(Array.isArray(schema.featureList)).toBe(true)
    expect(schema.featureList.length).toBeGreaterThan(0)

    const executionEntry = schema.featureList.find((f: string) => f.includes('execution clients'))
    expect(executionEntry).toContain(String(EXECUTION_CLIENTS.length))
    EXECUTION_CLIENTS.forEach((c) => expect(executionEntry).toContain(c.name))

    const consensusEntry = schema.featureList.find((f: string) => f.includes('consensus clients'))
    expect(consensusEntry).toContain(String(CONSENSUS_CLIENTS.length))
    CONSENSUS_CLIENTS.forEach((c) => expect(consensusEntry).toContain(c.name))
  })
})
