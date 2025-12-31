'use client'

import { cn } from '@/lib/utils'
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter'
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism'

export interface TerminalProps {
  code?: string
  language?: string
  children?: React.ReactNode
  className?: string
  title?: string
}

const codeStyle = {
  margin: 0,
  padding: 0,
  background: 'transparent',
  fontSize: '14px',
}

export function Terminal({ code, language = 'bash', children, className, title }: TerminalProps) {
  return (
    <div className={cn('overflow-hidden rounded-xl border border-border/30 bg-[#1e1e1e] shadow-2xl', className)}>
      <div className="flex items-center gap-2 border-b border-border/20 bg-[#2d2d2d] px-4 py-3">
        <div className="flex gap-2">
          <div className="h-3 w-3 rounded-full bg-red-500" />
          <div className="h-3 w-3 rounded-full bg-yellow-500" />
          <div className="h-3 w-3 rounded-full bg-green-500" />
        </div>
        {title && <span className="ml-4 font-mono text-sm text-muted-foreground">{title}</span>}
      </div>
      <div className="overflow-x-auto p-4">
        {code ? (
          <SyntaxHighlighter language={language} style={vscDarkPlus} customStyle={codeStyle}>
            {code}
          </SyntaxHighlighter>
        ) : (
          <div className="font-mono text-sm text-foreground">{children}</div>
        )}
      </div>
    </div>
  )
}
