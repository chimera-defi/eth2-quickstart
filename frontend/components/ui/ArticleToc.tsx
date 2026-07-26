export interface ArticleTocLink {
  label: string
  href: string
}

export interface ArticleTocProps {
  links: ArticleTocLink[]
}

/**
 * Shared "Table of contents" nav shell used by every blog article. The markup is
 * byte-identical across articles; only the `links` data differs per page.
 */
export function ArticleToc({ links }: ArticleTocProps) {
  return (
    <nav aria-label="Table of contents" className="mt-8 rounded-lg border border-border p-4 sm:p-5">
      <p className="font-mono text-xs text-muted-foreground uppercase tracking-wide">Contents</p>
      <ul className="mt-2 flex flex-wrap gap-x-5 gap-y-1.5 text-sm">
        {links.map((link) => (
          <li key={link.href}>
            <a href={link.href} className="text-primary hover:underline">
              {link.label}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  )
}
