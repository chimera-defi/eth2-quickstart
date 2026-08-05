import type { Metadata } from 'next'
import { Inter, JetBrains_Mono } from 'next/font/google'
import './globals.css'
import { Navbar } from '@/components/layout/Navbar'
import { Footer } from '@/components/layout/Footer'
import { SiteJsonLd } from '@/components/ui/SiteJsonLd'
import { TOTAL_CLIENTS } from '@/lib/constants'
import { MotionProvider } from './motion-provider'

const inter = Inter({
  subsets: ['latin'],
  weight: ['400', '500', '600'],
  display: 'swap',
  variable: '--font-sans',
})

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  weight: ['400', '500', '600'],
  display: 'swap',
  variable: '--font-mono',
})

// Single source of truth for the root <title>/description so the three
// copies below (plain, OG, Twitter) can't drift from each other or from the
// real client count in lib/constants.ts (this string previously hardcoded
// "12 clients" in all three places, which had gone stale — the execution +
// consensus client matrix is TOTAL_CLIENTS).
const SITE_TITLE = 'ETH2 Quick Start - Ethereum Node Setup in Minutes'
const SITE_DESCRIPTION = `Transform a fresh server into a fully-configured Ethereum node. ${TOTAL_CLIENTS} clients, automated security, MEV integration.`

export const metadata: Metadata = {
  metadataBase: new URL('https://eth2quickstart.com'),
  title: SITE_TITLE,
  description: SITE_DESCRIPTION,
  // Feed-reader autodiscovery: emits <link rel="alternate" type="application/rss+xml">
  // in <head> so readers find /rss.xml from any page.
  alternates: {
    types: {
      'application/rss+xml': [{ url: '/rss.xml', title: 'ETH2 Quick Start — Field notes & benchmarks' }],
    },
  },
  openGraph: {
    title: SITE_TITLE,
    description: SITE_DESCRIPTION,
    siteName: 'ETH2 Quick Start',
    type: 'website',
    images: [{ url: '/og.png', width: 1200, height: 630, alt: 'ETH2 Quick Start — Ethereum client bake-off' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: SITE_TITLE,
    description: SITE_DESCRIPTION,
    images: ['/og.png'],
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className={`dark ${inter.variable} ${jetbrainsMono.variable}`}>
      <body className="min-h-screen bg-background text-foreground antialiased overflow-x-hidden">
        <SiteJsonLd />
        <a
          href="#main-content"
          className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-3 focus:z-[60] focus:rounded focus:bg-background focus:px-4 focus:py-2 focus:text-foreground focus:outline focus:outline-2 focus:outline-primary"
        >
          Skip to content
        </a>
        <MotionProvider>
          <Navbar />
          <main id="main-content" tabIndex={-1} className="overflow-x-hidden focus:outline-none">
            {children}
          </main>
          <Footer />
        </MotionProvider>
      </body>
    </html>
  )
}
