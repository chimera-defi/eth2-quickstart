'use client'

import { cn } from '@/lib/utils'
import Link from 'next/link'
import { forwardRef } from 'react'

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary'
  size?: 'sm' | 'md' | 'lg'
  href?: string
  external?: boolean
  children: React.ReactNode
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'primary', size = 'md', href, external, children, disabled, ...props }, ref) => {
    const baseStyles = 'inline-flex items-center justify-center font-medium rounded-lg transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:pointer-events-none disabled:opacity-50'
    
    const variants = {
      primary: 'bg-gradient-to-r from-primary to-purple-600 text-white hover:scale-105 hover:shadow-lg hover:shadow-primary/25 active:scale-100',
      secondary: 'bg-transparent border-2 border-primary/30 text-foreground hover:border-primary/60 hover:bg-primary/10 active:bg-primary/20',
    }
    
    const sizes = {
      sm: 'h-9 px-4 text-sm',
      md: 'h-11 px-5 text-base',
      lg: 'h-12 px-6 text-base',
    }
    
    const classes = cn(baseStyles, variants[variant], sizes[size], className)
    
    if (href) {
      if (external) {
        return (
          <a href={href} target="_blank" rel="noopener noreferrer" className={classes}>
            {children}
          </a>
        )
      }
      return (
        <Link href={href} className={classes}>
          {children}
        </Link>
      )
    }
    
    return (
      <button ref={ref} className={classes} disabled={disabled} {...props}>
        {children}
      </button>
    )
  }
)

Button.displayName = 'Button'
