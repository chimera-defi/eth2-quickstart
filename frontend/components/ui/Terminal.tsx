'use client'

import { cn } from '@/lib/utils'
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter'
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism'

/**
 * Terminal component props
 */
export interface TerminalProps {
  /** Code content to display */
  code?: string
  /** Programming language for syntax highlighting */
  language?: string
  /** Alternative: render children directly */
  children?: React.ReactNode
  /** Additional CSS classes */
  className?: string
  /** Terminal title */
  title?: string
}

/**
 * Terminal mockup component with macOS-style header.
 * Supports syntax highlighting for code content.
 * 
 * @example
 * ```tsx
 * <Terminal code="curl -fsSL https://... | bash" language="bash" />
 * <Terminal title="Output">
 *   <pre>Custom content here</pre>
 * </Terminal>
 * ```
 */
export function Terminal({ code, language = 'bash', children, className, title }: TerminalProps) {
  return (
    <div
      className={cn(
        'overflow-hidden rounded-xl border border-border/30 bg-[#1e1e1e] shadow-2xl',
        className
      )}
    >
      {/* macOS-style header */}
      <div className="flex items-center gap-2 border-b border-border/20 bg-[#2d2d2d] px-4 py-3">
        <div className="flex gap-2">
          <div className="h-3 w-3 rounded-full bg-red-500" />
          <div className="h-3 w-3 rounded-full bg-yellow-500" />
          <div className="h-3 w-3 rounded-full bg-green-500" />
        </div>
        {title && (
          <span className="ml-4 font-mono text-sm text-muted-foreground">{title}</span>
        )}
      </div>
      
      {/* Terminal content */}
      <div className="overflow-x-auto p-4">
        {code ? (
          <SyntaxHighlighter
            language={language}
            style={vscDarkPlus}
            customStyle={{
              margin: 0,
              padding: 0,
              background: 'transparent',
              fontSize: '14px',
            }}
            codeTagProps={{
              style: {
                fontFamily: 'JetBrains Mono, Fira Code, monospace',
              },
            }}
          >
            {code}
          </SyntaxHighlighter>
        ) : (
          <div className="font-mono text-sm text-foreground">
            {children}
          </div>
        )}
      </div>
    </div>
  )
}
