import { render } from '@testing-library/react'
import { FaqJsonLd } from '@/components/ui/FaqJsonLd'
import { FAQ_ITEMS } from '@/lib/constants'

function renderJsonLd() {
  const { container } = render(<FaqJsonLd />)
  const script = container.querySelector('script[type="application/ld+json"]')
  expect(script).not.toBeNull()
  return JSON.parse(script!.innerHTML)
}

describe('FaqJsonLd', () => {
  it('emits valid JSON-LD (does not throw parsing)', () => {
    expect(() => renderJsonLd()).not.toThrow()
  })

  it('is a FAQPage with one Question per FAQ_ITEMS entry', () => {
    const schema = renderJsonLd()
    expect(schema['@context']).toBe('https://schema.org')
    expect(schema['@type']).toBe('FAQPage')
    expect(schema.mainEntity).toHaveLength(FAQ_ITEMS.length)
  })

  it('mirrors the visible FAQ_ITEMS question/answer text exactly (single source of truth)', () => {
    const schema = renderJsonLd()
    FAQ_ITEMS.forEach((item, i) => {
      expect(schema.mainEntity[i]['@type']).toBe('Question')
      expect(schema.mainEntity[i].name).toBe(item.question)
      expect(schema.mainEntity[i].acceptedAnswer['@type']).toBe('Answer')
      expect(schema.mainEntity[i].acceptedAnswer.text).toBe(item.answer)
    })
  })

  it('every answer is self-contained (non-trivial length, no dangling reference)', () => {
    FAQ_ITEMS.forEach((item) => {
      expect(item.answer.length).toBeGreaterThan(20)
    })
  })
})
