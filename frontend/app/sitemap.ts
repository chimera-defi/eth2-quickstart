import type { MetadataRoute } from 'next'

const BASE = 'https://eth2quickstart.com'

// Static routes worth indexing. Blog articles get a higher priority since
// they're the pages we want people to find and share.
const routes: { path: string; priority: number }[] = [
  { path: '', priority: 1 },
  { path: '/quickstart', priority: 0.7 },
  { path: '/blog', priority: 0.7 },
  { path: '/blog/ethereum-client-bakeoff', priority: 0.9 },
  { path: '/blog/how-we-tested-with-claude', priority: 0.8 },
  { path: '/blog/bakeoff-harness', priority: 0.8 },
  { path: '/blog/bakeoff-results', priority: 0.8 },
]

export default function sitemap(): MetadataRoute.Sitemap {
  return routes.map(({ path, priority }) => ({
    url: `${BASE}${path}`,
    changeFrequency: 'monthly',
    priority,
  }))
}
