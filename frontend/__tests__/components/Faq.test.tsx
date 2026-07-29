import { render, screen } from '@testing-library/react'
import { Faq } from '@/components/sections/Faq'
import { FAQ_ITEMS } from '@/lib/constants'

describe('Faq', () => {
  it('renders every question and answer from FAQ_ITEMS server-side (no JS required)', () => {
    render(<Faq />)
    FAQ_ITEMS.forEach((item) => {
      expect(screen.getByText(item.question)).toBeInTheDocument()
      expect(screen.getByText(item.answer)).toBeInTheDocument()
    })
  })

  it('uses native <details>/<summary> so content is present without client JS', () => {
    const { container } = render(<Faq />)
    expect(container.querySelectorAll('details')).toHaveLength(FAQ_ITEMS.length)
    expect(container.querySelectorAll('summary')).toHaveLength(FAQ_ITEMS.length)
  })
})
