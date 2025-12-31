import { cn } from '@/lib/utils'

/**
 * Badge component props
 */
export interface BadgeProps {
  /** Badge content */
  children: React.ReactNode
  /** Color variant */
  variant?: 'primary' | 'secondary' | 'success' | 'muted'
  /** Size variant */
  size?: 'sm' | 'md'
  /** Additional CSS classes */
  className?: string
}

/**
 * Badge component for displaying labels, tags, and status indicators.
 * 
 * @example
 * ```tsx
 * <Badge variant="primary">Geth</Badge>
 * <Badge variant="success" size="sm">Active</Badge>
 * ```
 */
export function Badge({ children, variant = 'primary', size = 'md', className }: BadgeProps) {
  const variants = {
    primary: 'bg-primary/10 border-primary/30 text-primary',
    secondary: 'bg-secondary/10 border-secondary/30 text-secondary',
    success: 'bg-green-500/10 border-green-500/30 text-green-400',
    muted: 'bg-muted/50 border-border/50 text-muted-foreground',
  }
  
  const sizes = {
    sm: 'px-3 py-1 text-xs',
    md: 'px-4 py-1.5 text-sm',
  }
  
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full border font-medium',
        variants[variant],
        sizes[size],
        className
      )}
    >
      {children}
    </span>
  )
}
