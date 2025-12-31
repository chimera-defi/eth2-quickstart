import { render, screen } from '@testing-library/react'
import { Badge } from '@/components/ui/Badge'

describe('Badge', () => {
  it('renders children correctly', () => {
    render(<Badge>Test Badge</Badge>)
    expect(screen.getByText('Test Badge')).toBeInTheDocument()
  })

  it('applies default variant styles', () => {
    render(<Badge>Default</Badge>)
    const badge = screen.getByText('Default')
    expect(badge).toHaveClass('bg-muted')
    expect(badge).toHaveClass('text-muted-foreground')
  })

  it('applies variant styles correctly', () => {
    const { rerender } = render(<Badge variant="primary">Primary</Badge>)
    expect(screen.getByText('Primary')).toHaveClass('text-primary')
    
    rerender(<Badge variant="secondary">Secondary</Badge>)
    expect(screen.getByText('Secondary')).toHaveClass('text-foreground')
    
    rerender(<Badge variant="success">Success</Badge>)
    expect(screen.getByText('Success')).toHaveClass('text-green-400')
  })

  it('applies size variants correctly', () => {
    const { rerender } = render(<Badge size="sm">Small</Badge>)
    expect(screen.getByText('Small')).toHaveClass('px-2.5')
    
    rerender(<Badge size="md">Medium</Badge>)
    expect(screen.getByText('Medium')).toHaveClass('px-3')
  })

  it('has rounded-md class', () => {
    render(<Badge>Rounded</Badge>)
    expect(screen.getByText('Rounded')).toHaveClass('rounded-md')
  })

  it('has font-mono class', () => {
    render(<Badge>Mono</Badge>)
    expect(screen.getByText('Mono')).toHaveClass('font-mono')
  })
})
