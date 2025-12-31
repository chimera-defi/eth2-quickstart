import { render, screen } from '@testing-library/react'
import { Card } from '@/components/ui/Card'

describe('Card', () => {
  it('renders children correctly', () => {
    render(<Card>Card content</Card>)
    expect(screen.getByText('Card content')).toBeInTheDocument()
  })

  it('applies base styles', () => {
    render(<Card>Content</Card>)
    const card = screen.getByTestId('card')
    expect(card).toHaveClass('rounded-xl')
    expect(card).toHaveClass('border')
  })

  it('applies hover styles when hover prop is true', () => {
    render(<Card hover>Hoverable</Card>)
    const card = screen.getByTestId('card')
    expect(card).toHaveClass('hover:border-primary/20')
  })

  it('applies padding variants correctly', () => {
    const { rerender } = render(<Card padding="sm">Small padding</Card>)
    let card = screen.getByTestId('card')
    expect(card).toHaveClass('p-4')
    
    rerender(<Card padding="md">Medium padding</Card>)
    card = screen.getByTestId('card')
    expect(card).toHaveClass('p-6')
    
    rerender(<Card padding="lg">Large padding</Card>)
    card = screen.getByTestId('card')
    expect(card).toHaveClass('p-8')
  })

  it('applies variant styles correctly', () => {
    const { rerender } = render(<Card variant="default">Default</Card>)
    let card = screen.getByTestId('card')
    expect(card).toHaveClass('bg-card')
    
    rerender(<Card variant="subtle">Subtle</Card>)
    card = screen.getByTestId('card')
    expect(card).toHaveClass('bg-muted/50')
  })

  it('accepts custom className', () => {
    render(<Card className="custom-class">Custom</Card>)
    const card = screen.getByTestId('card')
    expect(card).toHaveClass('custom-class')
  })
})
