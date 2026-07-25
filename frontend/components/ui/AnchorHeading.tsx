'use client'

import { useState } from 'react'
import { Check, Link as LinkIcon } from 'lucide-react'
import { cn, copyToClipboard } from '@/lib/utils'

export interface AnchorHeadingProps {
  /** The id used both as the DOM anchor target and the URL hash. */
  id: string
  /** Heading level to render. Defaults to 'h2'. */
  as?: 'h2' | 'h3'
  className?: string
  children: React.ReactNode
}

/**
 * A section heading that is deep-linkable: hovering, focusing, or (on touch)
 * tapping reveals a copy-link button that updates the URL hash and copies the
 * absolute, shareable URL to the clipboard — "here's the paragraph/chart I mean".
 *
 * The button is a SIBLING of the heading (not a child) so it doesn't bleed into
 * the heading's accessible name, and the "copied" state is only shown when the
 * clipboard write actually succeeds.
 */
export function AnchorHeading({ id, as = 'h2', className, children }: AnchorHeadingProps) {
  const [copied, setCopied] = useState(false)
  const Tag = as

  const handleCopy = async () => {
    window.history.replaceState(null, '', `#${id}`)
    const url = `${window.location.origin}${window.location.pathname}#${id}`
    const ok = await copyToClipboard(url)
    if (ok) {
      setCopied(true)
      setTimeout(() => setCopied(false), 1500)
    }
  }

  const label = copied ? 'Link copied' : 'Copy link to this section'

  return (
    <div className={cn('group flex items-start gap-2', className)}>
      <Tag id={id} className="min-w-0 scroll-mt-24">
        {children}
      </Tag>
      <button
        type="button"
        onClick={handleCopy}
        aria-label={label}
        title={label}
        className="mt-1 shrink-0 rounded text-muted-foreground opacity-0 transition-opacity hover:text-primary group-hover:opacity-100 focus-visible:opacity-100 [@media(hover:none)]:opacity-60"
      >
        {copied ? (
          <Check className="h-4 w-4" aria-hidden="true" />
        ) : (
          <LinkIcon className="h-4 w-4" aria-hidden="true" />
        )}
      </button>
    </div>
  )
}
