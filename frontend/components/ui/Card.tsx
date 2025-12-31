import { cn } from '@/lib/utils'
import { forwardRef } from 'react'

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode
  hover?: boolean
  padding?: 'sm' | 'md' | 'lg' | 'none'
}

export const Card = forwardRef<HTMLDivElement, CardProps>(
  ({ className, children, hover = false, padding = 'md', ...props }, ref) => {
    const paddingStyles = {
      none: '',
      sm: 'p-4',
      md: 'p-6',
      lg: 'p-8',
    }
    
    return (
      <div
        ref={ref}
        className={cn(
          'rounded-xl border border-border/30 bg-card/30 backdrop-blur-sm',
          paddingStyles[padding],
          hover && 'transition-all duration-300 hover:scale-[1.02] hover:border-primary/40 hover:bg-card/50',
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
