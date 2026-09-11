import { ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'

export interface DetailsProps extends Omit<React.HTMLAttributes<HTMLDetailsElement>, 'id'> {
  summary: React.ReactNode
  children: React.ReactNode
  defaultOpen?: boolean
  /** Anchor id for deep-linking. Placed on the heading inside <summary>, not on
   * <details> itself: an id on <details> is the fragment-nav *target*, not a
   * descendant of the hidden content, so the browser's auto-open-on-navigate
   * behavior never fires for it and a deep link lands on a collapsed section. */
  id?: string
  /** Heading level for the summary text, so collapsed sections keep a real
   * heading-outline entry for screen readers/keyboard nav instead of being
   * reduced to plain <summary> text with no heading semantics. */
  headingLevel?: 'h3' | 'h4' | 'h5'
}

export function Details({
  summary,
  children,
  defaultOpen = false,
  id,
  headingLevel = 'h3',
  className,
  ...props
}: DetailsProps) {
  const Heading = headingLevel
  return (
    <details
      open={defaultOpen}
      className={cn('group rounded-lg border border-border', className)}
      {...props}
    >
      <summary className="flex cursor-pointer list-none items-center justify-between gap-3 px-4 py-3 text-sm font-medium text-foreground marker:content-none [&::-webkit-details-marker]:hidden">
        <Heading id={id} className="m-0 text-sm font-medium text-foreground">
          {summary}
        </Heading>
        <ChevronDown className="h-4 w-4 shrink-0 text-muted-foreground transition-transform group-open:rotate-180" aria-hidden="true" />
      </summary>
      <div className="border-t border-border px-4 py-4">{children}</div>
    </details>
  )
}
