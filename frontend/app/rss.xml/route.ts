import { renderFeed, RSS_CONTENT_TYPE } from '@/lib/rss'

/**
 * RSS 2.0 feed for the blog, served at /rss.xml.
 *
 * `force-static` pre-renders the feed at build time into the static output the
 * deploy serves behind CloudFront — the same model as sitemap.ts / robots.ts.
 * The feed-building logic and its build-safety guarantee live in lib/rss.ts
 * (a route module may only export the framework's reserved names).
 */
export const dynamic = 'force-static'

export function GET(): Response {
  return new Response(renderFeed(), {
    headers: {
      'Content-Type': RSS_CONTENT_TYPE,
      'Cache-Control': 'public, max-age=3600',
    },
  })
}
