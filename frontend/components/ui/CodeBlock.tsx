'use client'

import { useState } from 'react'
import { cn, copyToClipboard } from '@/lib/utils'
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter'
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism'
import { Copy, Check } from 'lucide-react'

/**
 * CodeBlock component props
 */
export interface CodeBlockProps {
  /** Code content to display */
  code: string
  /** Programming language for syntax highlighting */
  language?: string
  /** Show copy button */
  showCopy?: boolean
  /** Additional CSS classes */
  className?: string
}

/**
 * CodeBlock component with syntax highlighting and copy-to-clipboard functionality.
 * Used for code examples in documentation and quickstart guide.
 * 
 * @example
 * ```tsx
 * <CodeBlock 
 *   code="npm install package" 
 *   language="bash" 
 *   showCopy 
 * />
 * ```
 */
export function CodeBlock({ code, language = 'bash', showCopy = true, className }: CodeBlockProps) {
  const [copied, setCopied] = useState(false)
  
  const handleCopy = async () => {
    const success = await copyToClipboard(code)
    if (success) {
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }
  
  return (
    <div
      className={cn(
        'group relative overflow-hidden rounded-lg border border-border/30 bg-[#1e1e1e]',
        className
      )}
    >
      {showCopy && (
        <button
          onClick={handleCopy}
          className="absolute right-2 top-2 rounded-md border border-border/30 bg-[#2d2d2d] p-2 text-muted-foreground opacity-0 transition-all hover:bg-[#3d3d3d] hover:text-foreground group-hover:opacity-100 focus:opacity-100"
          aria-label={copied ? 'Copied!' : 'Copy code'}
        >
          {copied ? (
            <Check className="h-4 w-4 text-green-400" />
          ) : (
            <Copy className="h-4 w-4" />
          )}
        </button>
      )}
      
      <div className="overflow-x-auto p-4">
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
      </div>
    </div>
  )
}
