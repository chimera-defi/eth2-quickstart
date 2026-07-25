'use client'

import { useEffect, useState } from 'react'
import { ArrowUp } from 'lucide-react'
import { cn } from '@/lib/utils'

const SHOW_AFTER_PX = 600

/**
 * Fixed bottom-right "back to top" button. Appears once the user has scrolled
 * past SHOW_AFTER_PX and smooth-scrolls to the top of the page on click,
 * falling back to an instant jump when the user prefers reduced motion.
 */
export function BackToTop() {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const onScroll = () => setVisible(window.scrollY > SHOW_AFTER_PX)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  const handleClick = () => {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    window.scrollTo({ top: 0, behavior: prefersReducedMotion ? 'auto' : 'smooth' })
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      aria-label="Back to top"
      tabIndex={visible ? 0 : -1}
      className={cn(
        'fixed bottom-6 right-4 sm:right-6 z-40 flex h-10 w-10 items-center justify-center rounded-full border border-border bg-background/90 text-foreground shadow-md backdrop-blur transition-all duration-200 hover:bg-muted focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-primary',
        visible ? 'opacity-100 translate-y-0 pointer-events-auto' : 'opacity-0 translate-y-2 pointer-events-none'
      )}
    >
      <ArrowUp className="h-4 w-4" aria-hidden="true" />
    </button>
  )
}
