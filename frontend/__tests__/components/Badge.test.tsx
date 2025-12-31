import { render, screen } from '@testing-library/react'
import { Badge } from '@/components/ui/Badge'

describe('Badge', () => {
  it('renders children correctly', () => {
    render(<Badge>Test Badge</Badge>)
    expect(screen.getByText('Test Badge')).toBeInTheDocument()
  })

  it('applies primary variant styles by default', () => {
    render(<Badge>Primary</Badge>)
    const badge = screen.getByText('Primary')
    expect(badge).toHaveClass('bg-primary/10')
    expect(badge).toHaveClass('text-primary')
  })

  it('applies variant styles correctly', () => {
    const { rerender } = render(<Badge variant="secondary">Secondary</Badge>)
    expect(screen.getByText('Secondary')).toHaveClass('text-secondary')
    
    rerender(<Badge variant="success">Success</Badge>)
    expect(screen.getByText('Success')).toHaveClass('text-green-400')
    
    rerender(<Badge variant="muted">Muted</Badge>)
    expect(screen.getByText('Muted')).toHaveClass('text-muted-foreground')
  })

  it('applies size variants correctly', () => {
    const { rerender } = render(<Badge size="sm">Small</Badge>)
    expect(screen.getByText('Small')).toHaveClass('px-3')
    
    rerender(<Badge size="md">Medium</Badge>)
    expect(screen.getByText('Medium')).toHaveClass('px-4')
  })

  it('has rounded-full class for pill shape', () => {
    render(<Badge>Pill</Badge>)
    expect(screen.getByText('Pill')).toHaveClass('rounded-full')
  })
})
