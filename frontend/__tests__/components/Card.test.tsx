import { render, screen } from '@testing-library/react'
import { Card } from '@/components/ui/Card'

describe('Card', () => {
  it('renders children correctly', () => {
    render(<Card>Card content</Card>)
    expect(screen.getByText('Card content')).toBeInTheDocument()
  })

  it('applies base styles', () => {
    render(<Card data-testid="card">Content</Card>)
    const card = screen.getByTestId('card')
    expect(card).toHaveClass('rounded-xl')
    expect(card).toHaveClass('border')
  })

  it('applies hover styles when hover prop is true', () => {
    render(<Card hover data-testid="card">Hoverable</Card>)
    const card = screen.getByTestId('card')
    expect(card).toHaveClass('hover:scale-[1.02]')
  })

  it('applies padding variants correctly', () => {
    const { rerender } = render(<Card padding="sm" data-testid="card">Small padding</Card>)
    let card = screen.getByTestId('card')
    expect(card).toHaveClass('p-4')
    
    rerender(<Card padding="md" data-testid="card">Medium padding</Card>)
    card = screen.getByTestId('card')
    expect(card).toHaveClass('p-6')
    
    rerender(<Card padding="lg" data-testid="card">Large padding</Card>)
    card = screen.getByTestId('card')
    expect(card).toHaveClass('p-8')
  })

  it('accepts custom className', () => {
    render(<Card className="custom-class" data-testid="card">Custom</Card>)
    const card = screen.getByTestId('card')
    expect(card).toHaveClass('custom-class')
  })
})
