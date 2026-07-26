import Link from 'next/link'
import { ARTICLES } from '@/lib/articles'

export interface ReadNextProps {
  /** The slug of the article this component is rendered on — excluded from the list. */
  currentSlug: string
}

/**
 * Consistent "Read next" cross-link block for the blog articles: links to the
 * other three articles in the four-post bake-off series, excluding whichever
 * one it's rendered on.
 */
export function ReadNext({ currentSlug }: ReadNextProps) {
  const others = ARTICLES.filter((article) => article.slug !== currentSlug).map(
    ({ slug, navTitle }) => ({ slug, navTitle })
  )

  return (
    <section className="mt-10 sm:mt-16 border-t border-border pt-6">
      <h2 className="text-lg sm:text-xl font-semibold text-foreground">Read next</h2>
      <ul className="mt-3 flex flex-wrap gap-x-6 gap-y-2 text-sm">
        {others.map((article) => (
          <li key={article.slug}>
            <Link href={`/blog/${article.slug}`} className="text-primary hover:underline">
              {article.navTitle}
            </Link>
          </li>
        ))}
      </ul>
    </section>
  )
}
