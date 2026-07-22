'use client'

import { useState } from 'react'
import { Check, Link as LinkIcon } from 'lucide-react'
import { cn } from '@/lib/utils'

export interface AnchorHeadingProps {
  /** The id used both as the DOM anchor target and the URL hash. */
  id: string
  /** Heading level to render. Defaults to 'h2'. */
  as?: 'h2' | 'h3'
  className?: string
  children: React.ReactNode
}

/**
 * A section heading that is deep-linkable: hovering (or focusing) reveals a
 * copy-link button that updates the URL hash and copies the absolute,
 * shareable URL to the clipboard — "here's the paragraph/chart I mean".
 */
export function AnchorHeading({ id, as = 'h2', className, children }: AnchorHeadingProps) {
  const [copied, setCopied] = useState(false)
  const Tag = as

  const handleCopy = () => {
    window.history.replaceState(null, '', `#${id}`)
    const url = `${window.location.origin}${window.location.pathname}#${id}`
    navigator.clipboard?.writeText(url)?.catch(() => {})
    setCopied(true)
    setTimeout(() => setCopied(false), 1500)
  }

  return (
    <Tag id={id} className={cn('group scroll-mt-24 flex items-center gap-2', className)}>
      <span>{children}</span>
      <button
        type="button"
        onClick={handleCopy}
        aria-label="Copy link to this section"
        title={copied ? 'Link copied' : 'Copy link to this section'}
        className="shrink-0 rounded opacity-0 transition-opacity group-hover:opacity-100 focus-visible:opacity-100 [@media(hover:none)]:opacity-60 text-muted-foreground hover:text-primary"
      >
        {copied ? (
          <Check className="h-4 w-4" aria-hidden="true" />
        ) : (
          <LinkIcon className="h-4 w-4" aria-hidden="true" />
        )}
      </button>
    </Tag>
  )
}
