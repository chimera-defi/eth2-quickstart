import { ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'

export interface DetailsProps extends React.HTMLAttributes<HTMLDetailsElement> {
  summary: React.ReactNode
  children: React.ReactNode
  defaultOpen?: boolean
}

// Native <details>/<summary> so anchor links to an id inside stay reachable —
// browsers auto-open a closed <details> when the fragment-navigation target is
// a descendant of it (long-standing behavior; no JS needed here).
export function Details({ summary, children, defaultOpen = false, className, ...props }: DetailsProps) {
  return (
    <details
      open={defaultOpen}
      className={cn('group rounded-lg border border-border', className)}
      {...props}
    >
      <summary className="flex cursor-pointer list-none items-center justify-between gap-3 px-4 py-3 text-sm font-medium text-foreground marker:content-none [&::-webkit-details-marker]:hidden">
        <span>{summary}</span>
        <ChevronDown className="h-4 w-4 shrink-0 text-muted-foreground transition-transform group-open:rotate-180" aria-hidden="true" />
      </summary>
      <div className="border-t border-border px-4 py-4">{children}</div>
    </details>
  )
}
