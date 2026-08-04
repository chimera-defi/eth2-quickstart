import { formatArticleDate, getArticle } from '@/lib/articles'

/** "Published X · Updated Y" byline rendered under each article's eyebrow. */
export function ArticleByline({ slug }: { slug: string }) {
  const article = getArticle(slug)
  return (
    <p className="mt-1 text-xs text-muted-foreground">
      Published {formatArticleDate(article.datePublished)}
      {article.dateModified !== article.datePublished && (
        <> &middot; Updated {formatArticleDate(article.dateModified)}</>
      )}
    </p>
  )
}
