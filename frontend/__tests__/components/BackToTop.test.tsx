import { render, screen, fireEvent, act } from '@testing-library/react'
import { BackToTop } from '@/components/ui/BackToTop'

function setScrollY(value: number) {
  Object.defineProperty(window, 'scrollY', { value, configurable: true })
}

function mockMatchMedia(reducedMotion: boolean) {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: reducedMotion,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  }))
}

describe('BackToTop', () => {
  const originalMatchMedia = window.matchMedia
  const originalScrollY = window.scrollY
  const originalScrollTo = window.scrollTo
  const originalIntersectionObserver = (window as any).IntersectionObserver

  beforeEach(() => {
    setScrollY(0)
    window.scrollTo = jest.fn()
  })

  afterEach(() => {
    window.matchMedia = originalMatchMedia
    setScrollY(originalScrollY ?? 0)
    window.scrollTo = originalScrollTo
    ;(window as any).IntersectionObserver = originalIntersectionObserver
  })

  it('is hidden before the page has scrolled past the threshold', () => {
    render(<BackToTop />)
    expect(screen.queryByRole('button', { name: 'Back to top' })).not.toBeInTheDocument()
  })

  it('appears once scrolled past 600px', () => {
    render(<BackToTop />)
    setScrollY(601)
    fireEvent.scroll(window)
    expect(screen.getByRole('button', { name: 'Back to top' })).toBeInTheDocument()
  })

  it('hides again if scrolling back above the threshold', () => {
    render(<BackToTop />)
    setScrollY(601)
    fireEvent.scroll(window)
    expect(screen.getByRole('button', { name: 'Back to top' })).toBeInTheDocument()

    setScrollY(0)
    fireEvent.scroll(window)
    expect(screen.queryByRole('button', { name: 'Back to top' })).not.toBeInTheDocument()
  })

  it('scrolls smoothly on click when the user has no reduced-motion preference', () => {
    mockMatchMedia(false)
    render(<BackToTop />)
    setScrollY(601)
    fireEvent.scroll(window)

    fireEvent.click(screen.getByRole('button', { name: 'Back to top' }))

    expect(window.scrollTo).toHaveBeenCalledWith({ top: 0, behavior: 'smooth' })
  })

  it('scrolls instantly on click when the user prefers reduced motion', () => {
    mockMatchMedia(true)
    render(<BackToTop />)
    setScrollY(601)
    fireEvent.scroll(window)

    fireEvent.click(screen.getByRole('button', { name: 'Back to top' }))

    expect(window.scrollTo).toHaveBeenCalledWith({ top: 0, behavior: 'auto' })
  })

  // The component hides itself once the page footer scrolls into view (so it
  // never overlaps the footer's own links). jsdom has no real layout/viewport
  // intersection, so this only proves the component wires up an
  // IntersectionObserver against the footer and reacts to its callback —
  // it does not exercise real browser intersection geometry.
  it('hides when the (mocked) footer-intersection observer reports the footer is in view', () => {
    mockMatchMedia(false)
    let observedCallback: IntersectionObserverCallback | undefined
    const observe = jest.fn()
    const disconnect = jest.fn()
    ;(window as any).IntersectionObserver = jest.fn().mockImplementation((callback) => {
      observedCallback = callback
      return { observe, disconnect, unobserve: jest.fn() }
    })

    const footer = document.createElement('footer')
    document.body.appendChild(footer)

    try {
      render(<BackToTop />)
      setScrollY(601)
      fireEvent.scroll(window)
      expect(screen.getByRole('button', { name: 'Back to top' })).toBeInTheDocument()
      expect(observe).toHaveBeenCalledWith(footer)

      // Simulate the footer scrolling into view.
      act(() => {
        observedCallback?.(
          [{ isIntersecting: true } as IntersectionObserverEntry],
          {} as IntersectionObserver
        )
      })

      expect(screen.queryByRole('button', { name: 'Back to top' })).not.toBeInTheDocument()
    } finally {
      document.body.removeChild(footer)
    }
  })
})
