'use client'

import { useEffect, useState } from 'react'
import { ArrowUp } from 'lucide-react'

const SHOW_AFTER_PX = 600

/**
 * Fixed bottom-right "back to top" button. Appears once the user has scrolled
 * past SHOW_AFTER_PX and smooth-scrolls to the top of the page on click,
 * falling back to an instant jump when the user prefers reduced motion.
 *
 * Hides again once the page footer scrolls into view so the button never sits
 * on top of the footer's links (which share the bottom-right column at
 * tablet / unmaximized widths).
 */
export function BackToTop() {
  const [scrolled, setScrolled] = useState(false)
  const [footerInView, setFooterInView] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > SHOW_AFTER_PX)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  useEffect(() => {
    const footer = document.querySelector('footer')
    if (!footer) return
    const observer = new IntersectionObserver(
      ([entry]) => setFooterInView(entry.isIntersecting),
      // Grow the root's bottom edge so the button clears out a little before
      // the footer actually reaches it.
      { rootMargin: '0px 0px 80px 0px' }
    )
    observer.observe(footer)
    return () => observer.disconnect()
  }, [])

  const visible = scrolled && !footerInView

  const handleClick = () => {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    document.getElementById('article-top')?.focus({ preventScroll: true })
    window.scrollTo({ top: 0, behavior: prefersReducedMotion ? 'auto' : 'smooth' })
  }

  if (!visible) {
    return null
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      aria-label="Back to top"
      className="fixed bottom-6 right-4 sm:right-6 z-40 flex h-10 w-10 items-center justify-center rounded-full border border-border bg-background/90 text-foreground shadow-md backdrop-blur transition-colors duration-200 hover:bg-muted focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-primary"
    >
      <ArrowUp className="h-4 w-4" aria-hidden="true" />
    </button>
  )
}
