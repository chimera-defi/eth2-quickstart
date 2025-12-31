import { cn, GITHUB_URL } from '@/lib/utils'

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
})

describe('constants', () => {
  it('exports correct GitHub URL', () => {
    expect(GITHUB_URL).toBe('https://github.com/chimera-defi/eth2-quickstart')
  })
})
