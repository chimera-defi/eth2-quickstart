import type { Metadata } from 'next'
import './globals.css'
import { Navbar } from '@/components/layout/Navbar'
import { Footer } from '@/components/layout/Footer'

export const metadata: Metadata = {
  metadataBase: new URL('https://eth2-quickstart.com'),
  title: 'Ethereum Node Quick Setup - From Zero to Validator in 30 Minutes',
  description: 'Transform a fresh cloud server into a fully-configured Ethereum node. Choose from 6 execution and 6 consensus clients. Automated security, MEV integration, and RPC endpoints. Save 2+ days vs manual setup.',
  keywords: 'ethereum node, validator setup, eth2 quickstart, ethereum staking, rpc node, mev boost, ethereum clients, node installation',
  openGraph: {
    title: 'Ethereum Node Quick Setup - Automated Installation in Minutes',
    description: 'Get your Ethereum node running in 30 minutes. Support for 12 clients, automated security, MEV integration, and uncensored RPC endpoints.',
    url: 'https://eth2-quickstart.com',
    siteName: 'Ethereum Node Quick Setup',
    images: [
      {
        url: '/og-image.jpg',
        width: 1200,
        height: 630,
        alt: 'Ethereum Node Quick Setup',
      },
    ],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Ethereum Node Quick Setup - Zero to Validator in 30 Minutes',
    description: 'Automated Ethereum node installation. 12 clients, security hardening, MEV integration. Save 2+ days vs manual setup.',
    images: ['/og-image.jpg'],
  },
  robots: {
    index: true,
    follow: true,
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-screen bg-background text-foreground antialiased">
        <Navbar />
        <main>{children}</main>
        <Footer />
      </body>
    </html>
  )
}
