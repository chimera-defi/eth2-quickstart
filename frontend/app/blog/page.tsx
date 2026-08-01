import type { Metadata } from 'next'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { ARTICLES } from '@/lib/articles'
import { SITE_CONFIG } from '@/lib/constants'

const BLOG_TITLE = 'Blog - ETH2 Quick Start'
const BLOG_DESCRIPTION =
  'Field notes and benchmarks from the ETH2 Quick Start lab: the six-week Ethereum client bake-off, how we tested it with Claude, the harness, and raw results.'

const BLOG_OG_ALT = 'ETH2 Quick Start — from the lab'

export const metadata: Metadata = {
  title: BLOG_TITLE,
  description: BLOG_DESCRIPTION,
  alternates: { canonical: '/blog' },
  openGraph: {
    type: 'website',
    url: '/blog',
    siteName: SITE_CONFIG.shortName,
    title: BLOG_TITLE,
    description: BLOG_DESCRIPTION,
    images: [{ url: '/og.png', width: 1200, height: 630, alt: BLOG_OG_ALT }],
  },
  twitter: {
    card: 'summary_large_image',
    title: BLOG_TITLE,
    description: BLOG_DESCRIPTION,
    images: [{ url: '/og.png', width: 1200, height: 630, alt: BLOG_OG_ALT }],
  },
}

const posts = ARTICLES.map((article) => ({
  eyebrow: article.eyebrow,
  title: article.navTitle,
  description: article.indexDescription,
  href: `/blog/${article.slug}`,
}))

export default function BlogPage() {
  return (
    <div className="min-h-screen py-12 sm:py-16 md:py-24">
      <div className="mx-auto max-w-5xl px-4 sm:px-6">
        <header>
          <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
            Blog
          </p>
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-foreground sm:text-3xl md:text-4xl">
            From the lab
          </h1>
          <p className="mt-3 sm:mt-4 text-base sm:text-lg text-muted-foreground">
            Field notes, benchmarks, and practical lessons from running Ethereum nodes.
          </p>
        </header>

        <section className="mt-10 sm:mt-16">
          <h2 className="text-lg sm:text-xl font-semibold text-foreground">
            Latest
          </h2>
          <div className="mt-4 sm:mt-6 space-y-4">
            {posts.map((post) => (
              <Card key={post.href} hover>
                <p className="font-mono text-sm text-muted-foreground uppercase tracking-wide">
                  {post.eyebrow}
                </p>
                <h3 className="mt-2 text-xl font-semibold text-foreground">
                  {post.title}
                </h3>
                <p className="mt-2 text-sm text-muted-foreground">
                  {post.description}
                </p>
                <div className="mt-4">
                  <Button href={post.href} variant="ghost" size="sm">
                    Read more
                  </Button>
                </div>
              </Card>
            ))}
          </div>
        </section>
      </div>
    </div>
  )
}
