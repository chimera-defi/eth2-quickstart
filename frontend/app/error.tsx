'use client'

import { useEffect } from 'react'
import { Button } from '@/components/ui/Button'
import { AlertTriangle, RefreshCcw, Github } from 'lucide-react'
import { SITE_CONFIG } from '@/lib/constants'

interface ErrorProps {
  error: Error & { digest?: string }
  reset: () => void
}

/**
 * Error boundary component for handling runtime errors
 */
export default function Error({ error, reset }: ErrorProps) {
  useEffect(() => {
    // Log error to console for debugging
    console.error('Application error:', error)
  }, [error])

  return (
    <div className="flex min-h-[50vh] items-center justify-center px-4">
      <div className="max-w-md text-center">
        <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-red-500/10">
          <AlertTriangle className="h-8 w-8 text-red-500" />
        </div>
        
        <h2 className="mt-6 font-mono text-2xl font-bold text-foreground">
          Something went wrong
        </h2>
        
        <p className="mt-3 text-muted-foreground">
          An unexpected error occurred. Please try again or report this issue if it persists.
        </p>
        
        {error.digest && (
          <p className="mt-2 text-sm text-muted-foreground">
            Error ID: <code className="rounded bg-muted px-1 py-0.5">{error.digest}</code>
          </p>
        )}
        
        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <Button onClick={reset} size="sm">
            <RefreshCcw className="mr-2 h-4 w-4" />
            Try Again
          </Button>
          <Button 
            href={`${SITE_CONFIG.github}/issues/new`}
            external
            variant="secondary" 
            size="sm"
          >
            <Github className="mr-2 h-4 w-4" />
            Report Issue
          </Button>
        </div>
      </div>
    </div>
  )
}
