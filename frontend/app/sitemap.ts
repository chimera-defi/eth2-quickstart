import type { MetadataRoute } from 'next'
import { ARTICLES } from '@/lib/articles'
import { SITE_CONFIG } from '@/lib/constants'

// Static routes worth indexing. Blog articles get a higher priority since
// they're the pages we want people to find and share.
const staticRoutes: { path: string; priority: number }[] = [
  { path: '', priority: 1 },
  { path: '/quickstart', priority: 0.7 },
  { path: '/blog', priority: 0.7 },
]

const blogRoutes: { path: string; priority: number }[] = ARTICLES.map((article) => ({
  path: `/blog/${article.slug}`,
  priority: article.sitemapPriority,
}))

const routes: { path: string; priority: number }[] = [
  ...staticRoutes,
  ...blogRoutes,
  { path: '/deck/bakeoff.html', priority: 0.6 },
]

export default function sitemap(): MetadataRoute.Sitemap {
  return routes.map(({ path, priority }) => ({
    url: `${SITE_CONFIG.url}${path}`,
    changeFrequency: 'monthly',
    priority,
  }))
}
