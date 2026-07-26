import { render, screen, fireEvent, act } from '@testing-library/react'
import { AnchorHeading } from '@/components/ui/AnchorHeading'
import { copyToClipboard } from '@/lib/utils'

jest.mock('@/lib/utils', () => ({
  ...jest.requireActual('@/lib/utils'),
  copyToClipboard: jest.fn(),
}))

const mockedCopyToClipboard = copyToClipboard as jest.Mock

describe('AnchorHeading', () => {
  beforeEach(() => {
    mockedCopyToClipboard.mockReset()
    window.history.replaceState(null, '', '/some/page')
  })

  it('renders the requested heading tag with its children', () => {
    render(
      <AnchorHeading id="section-one" as="h3">
        Section One
      </AnchorHeading>
    )
    const heading = screen.getByRole('heading', { level: 3, name: 'Section One' })
    expect(heading.tagName).toBe('H3')
    expect(heading).toHaveAttribute('id', 'section-one')
  })

  it('defaults to h2 when `as` is omitted', () => {
    render(<AnchorHeading id="default-heading">Default</AnchorHeading>)
    expect(screen.getByRole('heading', { level: 2, name: 'Default' })).toBeInTheDocument()
  })

  it('clicking copy sets the url hash and calls copyToClipboard with the absolute url', async () => {
    mockedCopyToClipboard.mockResolvedValue(true)
    render(<AnchorHeading id="my-section">My Section</AnchorHeading>)

    await act(async () => {
      fireEvent.click(screen.getByRole('button', { name: /copy link/i }))
      await Promise.resolve()
    })

    expect(window.location.hash).toBe('#my-section')
    expect(mockedCopyToClipboard).toHaveBeenCalledWith(
      `${window.location.origin}${window.location.pathname}#my-section`
    )
  })

  it('shows the copied state only when copyToClipboard resolves true', async () => {
    mockedCopyToClipboard.mockResolvedValue(true)
    render(<AnchorHeading id="succeeds">Succeeds</AnchorHeading>)

    fireEvent.click(screen.getByRole('button', { name: /copy link/i }))

    expect(await screen.findByRole('button', { name: /link copied/i })).toBeInTheDocument()
  })

  it('does NOT show the copied state when copyToClipboard resolves false', async () => {
    mockedCopyToClipboard.mockResolvedValue(false)
    render(<AnchorHeading id="fails">Fails</AnchorHeading>)

    await act(async () => {
      fireEvent.click(screen.getByRole('button', { name: /copy link/i }))
      // Let the pending promise settle within act() so React flushes any
      // (absent) state update before we assert.
      await Promise.resolve()
    })

    expect(screen.queryByRole('button', { name: /link copied/i })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: /copy link/i })).toBeInTheDocument()
  })
})
