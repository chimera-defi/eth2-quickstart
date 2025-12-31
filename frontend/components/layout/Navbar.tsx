'use client'

import Link from 'next/link'
import { useState } from 'react'
import { Button } from '@/components/ui/Button'
import { SITE_CONFIG, NAV_LINKS } from '@/lib/constants'
import { Menu, X, Github } from 'lucide-react'
import { cn } from '@/lib/utils'

/**
 * Navigation bar component with responsive mobile menu.
 * Displays logo, navigation links, and CTA button.
 */
export function Navbar() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  
  return (
    <nav className="sticky top-0 z-50 border-b border-border/30 bg-background/80 backdrop-blur-md">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex h-16 items-center justify-between">
          {/* Logo */}
          <Link 
            href="/" 
            className="flex items-center gap-2 font-mono text-lg font-bold text-foreground transition-colors hover:text-primary"
          >
            <span className="text-gradient">{SITE_CONFIG.shortName}</span>
          </Link>
          
          {/* Desktop navigation */}
          <div className="hidden items-center gap-6 md:flex">
            {NAV_LINKS.map((link) => (
              link.external ? (
                <a
                  key={link.label}
                  href={link.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-1 text-sm text-muted-foreground transition-colors hover:text-foreground"
                >
                  {link.label === 'GitHub' && <Github className="h-4 w-4" />}
                  {link.label}
                </a>
              ) : (
                <Link
                  key={link.label}
                  href={link.href}
                  className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                >
                  {link.label}
                </Link>
              )
            ))}
            <Button href="/quickstart" size="sm">
              Get Started
            </Button>
          </div>
          
          {/* Mobile menu button */}
          <button
            type="button"
            className="inline-flex items-center justify-center rounded-md p-2 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground md:hidden"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            aria-label={mobileMenuOpen ? 'Close menu' : 'Open menu'}
          >
            {mobileMenuOpen ? (
              <X className="h-6 w-6" />
            ) : (
              <Menu className="h-6 w-6" />
            )}
          </button>
        </div>
      </div>
      
      {/* Mobile menu */}
      <div
        className={cn(
          'border-t border-border/30 bg-background md:hidden',
          mobileMenuOpen ? 'block' : 'hidden'
        )}
      >
        <div className="space-y-1 px-4 py-4">
          {NAV_LINKS.map((link) => (
            link.external ? (
              <a
                key={link.label}
                href={link.href}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 rounded-lg px-3 py-2 text-base text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                onClick={() => setMobileMenuOpen(false)}
              >
                {link.label === 'GitHub' && <Github className="h-4 w-4" />}
                {link.label}
              </a>
            ) : (
              <Link
                key={link.label}
                href={link.href}
                className="block rounded-lg px-3 py-2 text-base text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                onClick={() => setMobileMenuOpen(false)}
              >
                {link.label}
              </Link>
            )
          ))}
          <div className="px-3 pt-2">
            <Button href="/quickstart" className="w-full" onClick={() => setMobileMenuOpen(false)}>
              Get Started
            </Button>
          </div>
        </div>
      </div>
    </nav>
  )
}
