'use client'

import { useState } from 'react'
import { cn, copyToClipboard } from '@/lib/utils'
import { PrismLight as SyntaxHighlighter } from 'react-syntax-highlighter'
import bash from 'react-syntax-highlighter/dist/esm/languages/prism/bash'
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism'
import { Copy, Check } from 'lucide-react'

// Only bash is used anywhere in this repo (verified via grep across app/components).
// Register any additional language here if a new call site ever needs one.
SyntaxHighlighter.registerLanguage('bash', bash)

export interface CodeBlockProps {
  code: string
  language?: string
  showCopy?: boolean
  className?: string
}

const codeStyle = {
  margin: 0,
  padding: 0,
  background: 'transparent',
  fontSize: '13px',
  lineHeight: '1.6',
}

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
    <div className={cn('group relative overflow-hidden rounded-lg border border-border bg-[#0c0c0c]', className)}>
      {showCopy && (
        <button
          onClick={handleCopy}
          className="absolute right-2 top-2 rounded p-1.5 text-zinc-500 opacity-0 transition-all hover:text-zinc-300 group-hover:opacity-100 focus:opacity-100"
          aria-label={copied ? 'Copied!' : 'Copy code'}
        >
          {copied ? (
            <Check className="h-4 w-4 text-green-400" aria-hidden="true" />
          ) : (
            <Copy className="h-4 w-4" aria-hidden="true" />
          )}
        </button>
      )}
      <div className="overflow-x-auto p-4">
        <SyntaxHighlighter language={language} style={vscDarkPlus} customStyle={codeStyle}>
          {code}
        </SyntaxHighlighter>
      </div>
    </div>
  )
}
