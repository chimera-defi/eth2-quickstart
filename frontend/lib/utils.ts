import { clsx, type ClassValue } from 'clsx'

/**
 * Utility function to merge Tailwind CSS classes conditionally.
 * Combines clsx for conditional classes.
 * @param inputs - Class values to merge
 * @returns Merged class string
 */
export function cn(...inputs: ClassValue[]): string {
  return clsx(inputs)
}

/**
 * Copy text to clipboard with fallback for older browsers.
 * @param text - Text to copy
 * @returns Promise that resolves when copy is complete
 */
export async function copyToClipboard(text: string): Promise<boolean> {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text)
      return true
    }
    // Fallback for older browsers
    const textArea = document.createElement('textarea')
    textArea.value = text
    textArea.style.position = 'fixed'
    textArea.style.left = '-999999px'
    document.body.appendChild(textArea)
    textArea.focus()
    textArea.select()
    const successful = document.execCommand('copy')
    document.body.removeChild(textArea)
    return successful
  } catch {
    return false
  }
}

/**
 * Format large numbers with commas.
 * @param num - Number to format
 * @returns Formatted string
 */
export function formatNumber(num: number): string {
  return num.toLocaleString('en-US')
}

/**
 * GitHub repository URL
 */
export const GITHUB_URL = 'https://github.com/chimera-defi/eth2-quickstart'

/**
 * Documentation base URL
 */
export const DOCS_URL = `${GITHUB_URL}/blob/main/docs`
