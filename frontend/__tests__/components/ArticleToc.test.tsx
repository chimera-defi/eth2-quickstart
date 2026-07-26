import { render, screen } from '@testing-library/react'
import { ArticleToc } from '@/components/ui/ArticleToc'

describe('ArticleToc', () => {
  const links = [
    { label: 'Intro', href: '#intro' },
    { label: 'Methodology', href: '#methodology' },
    { label: 'Results', href: '#results' },
  ]

  it('renders a labeled nav', () => {
    render(<ArticleToc links={links} />)
    expect(screen.getByRole('navigation', { name: 'Table of contents' })).toBeInTheDocument()
  })

  it('renders exactly one link per item, pointing at the right hrefs', () => {
    render(<ArticleToc links={links} />)
    const renderedLinks = screen.getAllByRole('link')
    expect(renderedLinks).toHaveLength(links.length)

    links.forEach((link) => {
      const rendered = screen.getByRole('link', { name: link.label })
      expect(rendered).toHaveAttribute('href', link.href)
    })
  })

  it('renders no links when given an empty list', () => {
    render(<ArticleToc links={[]} />)
    expect(screen.queryAllByRole('link')).toHaveLength(0)
  })
})
