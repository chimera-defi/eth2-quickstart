import Link from 'next/link'
import { SITE_CONFIG } from '@/lib/constants'
import { Github, FileText, MessageSquare, Bug } from 'lucide-react'

const footerLinks = [
  { label: 'GitHub', href: SITE_CONFIG.github, icon: Github },
  { label: 'Documentation', href: '/learn', icon: FileText, internal: true },
  { label: 'Issues', href: `${SITE_CONFIG.github}/issues`, icon: Bug },
  { label: 'Discussions', href: `${SITE_CONFIG.github}/discussions`, icon: MessageSquare },
]

/**
 * Footer component with copyright and useful links.
 */
export function Footer() {
  const currentYear = new Date().getFullYear()
  
  return (
    <footer className="border-t border-border/30 bg-background">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-col items-center justify-between gap-4 md:flex-row">
          {/* Copyright */}
          <p className="text-sm text-muted-foreground">
            © {currentYear} {SITE_CONFIG.name}. Open source under MIT License.
          </p>
          
          {/* Links */}
          <div className="flex flex-wrap items-center justify-center gap-6">
            {footerLinks.map((link) => {
              const Icon = link.icon
              if (link.internal) {
                return (
                  <Link
                    key={link.label}
                    href={link.href}
                    className="flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    <Icon className="h-4 w-4" />
                    {link.label}
                  </Link>
                )
              }
              return (
                <a
                  key={link.label}
                  href={link.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
                >
                  <Icon className="h-4 w-4" />
                  {link.label}
                </a>
              )
            })}
          </div>
        </div>
      </div>
    </footer>
  )
}
