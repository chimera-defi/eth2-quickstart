import { cn } from '@/lib/utils'
import { forwardRef } from 'react'

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode
  hover?: boolean
  padding?: 'sm' | 'md' | 'lg' | 'none'
  variant?: 'default' | 'subtle'
}

export const Card = forwardRef<HTMLDivElement, CardProps>(
  ({ className, children, hover = false, padding = 'md', variant = 'default', ...props }, ref) => {
    const paddingStyles = {
      none: '',
      sm: 'p-4',
      md: 'p-6',
      lg: 'p-8',
    }
    
    const variantStyles = {
      default: 'border border-border bg-card',
      subtle: 'bg-muted/50',
    }
    
    return (
      <div
        ref={ref}
        data-testid="card"
        className={cn(
          'rounded-xl',
          variantStyles[variant],
          paddingStyles[padding],
          hover && 'transition-colors duration-200 hover:border-primary/20 hover:bg-card/80',
          className
        )}
        {...props}
      >
        {children}
      </div>
    )
  }
)

Card.displayName = 'Card'
