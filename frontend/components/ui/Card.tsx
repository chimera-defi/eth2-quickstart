import { cn } from '@/lib/utils'
import { forwardRef } from 'react'

/**
 * Card component props
 */
export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Card content */
  children: React.ReactNode
  /** Enable hover effects */
  hover?: boolean
  /** Padding size */
  padding?: 'sm' | 'md' | 'lg' | 'none'
}

/**
 * Card component with glassmorphism effect.
 * Used for feature cards, content sections, and grouped content.
 * 
 * @example
 * ```tsx
 * <Card hover padding="lg">
 *   <h3>Feature Title</h3>
 *   <p>Feature description</p>
 * </Card>
 * ```
 */
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
