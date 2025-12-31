import { Button } from '@/components/ui/Button'
import { Home, ArrowLeft } from 'lucide-react'

/**
 * Custom 404 page
 */
export default function NotFound() {
  return (
    <div className="flex min-h-[50vh] items-center justify-center px-4">
      <div className="max-w-md text-center">
        <h1 className="font-mono text-7xl font-bold text-gradient">404</h1>
        
        <h2 className="mt-4 font-mono text-2xl font-bold text-foreground">
          Page Not Found
        </h2>
        
        <p className="mt-3 text-muted-foreground">
          The page you&apos;re looking for doesn&apos;t exist or has been moved.
        </p>
        
        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <Button href="/" size="sm">
            <Home className="mr-2 h-4 w-4" />
            Go Home
          </Button>
          <Button href="/quickstart" variant="secondary" size="sm">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Quick Start
          </Button>
        </div>
      </div>
    </div>
  )
}
