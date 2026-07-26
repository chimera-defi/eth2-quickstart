import { cn, copyToClipboard } from '@/lib/utils'

describe('cn utility', () => {
  it('merges class names', () => {
    expect(cn('class1', 'class2')).toBe('class1 class2')
  })

  it('handles conditional classes', () => {
    expect(cn('base', true && 'conditional')).toBe('base conditional')
    expect(cn('base', false && 'conditional')).toBe('base')
  })

  it('handles undefined values', () => {
    expect(cn('base', undefined, 'other')).toBe('base other')
  })

  it('handles empty string', () => {
    expect(cn('base', '')).toBe('base')
  })
})

describe('copyToClipboard', () => {
  const originalIsSecureContext = window.isSecureContext
  const originalExecCommand = document.execCommand
  const originalClipboard = navigator.clipboard

  afterEach(() => {
    Object.defineProperty(window, 'isSecureContext', {
      value: originalIsSecureContext,
      configurable: true,
    })
    // execCommand may not exist at all in this jsdom environment; restore
    // faithfully rather than always reassigning a function.
    if (originalExecCommand === undefined) {
      // Deleting a possibly-absent jsdom API to restore baseline.
      delete (document as any).execCommand
    } else {
      document.execCommand = originalExecCommand
    }
    Object.defineProperty(navigator, 'clipboard', {
      value: originalClipboard,
      configurable: true,
      writable: true,
    })
    jest.restoreAllMocks()
  })

  it('uses navigator.clipboard.writeText and resolves true in a secure context', async () => {
    Object.defineProperty(window, 'isSecureContext', {
      value: true,
      configurable: true,
    })
    const writeText = jest.fn().mockResolvedValue(undefined)
    Object.defineProperty(navigator, 'clipboard', {
      value: { writeText },
      configurable: true,
      writable: true,
    })

    const result = await copyToClipboard('hello secure world')

    expect(writeText).toHaveBeenCalledWith('hello secure world')
    expect(result).toBe(true)
  })

  it('falls back to document.execCommand and resolves true when it succeeds', async () => {
    Object.defineProperty(window, 'isSecureContext', {
      value: false,
      configurable: true,
    })
    Object.defineProperty(navigator, 'clipboard', {
      value: undefined,
      configurable: true,
      writable: true,
    })
    document.execCommand = jest.fn().mockReturnValue(true)

    const result = await copyToClipboard('hello fallback world')

    expect(document.execCommand).toHaveBeenCalledWith('copy')
    expect(result).toBe(true)
  })

  it('resolves false when both clipboard and execCommand are unavailable/fail', async () => {
    Object.defineProperty(window, 'isSecureContext', {
      value: false,
      configurable: true,
    })
    Object.defineProperty(navigator, 'clipboard', {
      value: undefined,
      configurable: true,
      writable: true,
    })
    document.execCommand = jest.fn().mockReturnValue(false)

    const result = await copyToClipboard('hello failing world')

    expect(result).toBe(false)
  })
})
