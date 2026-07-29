import type { Metadata } from 'next'
import { Hero } from '@/components/sections/Hero'
import { Install } from '@/components/sections/Install'
import { Workflow } from '@/components/sections/Workflow'
import { Agents } from '@/components/sections/Agents'
import { Features } from '@/components/sections/Features'
import { Blog } from '@/components/sections/Blog'
import { Faq } from '@/components/sections/Faq'
import { CallToAction } from '@/components/sections/CallToAction'
import { SoftwareAppJsonLd } from '@/components/ui/SoftwareAppJsonLd'
import { FaqJsonLd } from '@/components/ui/FaqJsonLd'
import { SITE_CONFIG, TOTAL_CLIENTS } from '@/lib/constants'

const PAGE_TITLE = 'ETH2 Quick Start - Ethereum Node Setup in Minutes'
const PAGE_DESCRIPTION = `Transform a fresh server into a fully-configured Ethereum node. ${TOTAL_CLIENTS} clients, automated security, MEV integration.`
const PAGE_OG_ALT = 'ETH2 Quick Start — turn a fresh server into a fully-configured Ethereum node'

export const metadata: Metadata = {
  title: PAGE_TITLE,
  description: PAGE_DESCRIPTION,
  alternates: { canonical: '/' },
  openGraph: {
    type: 'website',
    siteName: SITE_CONFIG.shortName,
    url: '/',
    title: PAGE_TITLE,
    description: PAGE_DESCRIPTION,
    images: [{ url: '/og.png', width: 1200, height: 630, alt: PAGE_OG_ALT }],
  },
  twitter: {
    card: 'summary_large_image',
    title: PAGE_TITLE,
    description: PAGE_DESCRIPTION,
    images: [{ url: '/og.png', width: 1200, height: 630, alt: PAGE_OG_ALT }],
  },
}

/**
 * Homepage component
 * Displays hero section and features
 */
export default function Home() {
  return (
    <>
      <SoftwareAppJsonLd />
      <FaqJsonLd />
      <Hero />
      <Install />
      <Workflow />
      <Agents />
      <Features />
      <Blog />
      <Faq />
      <CallToAction />
    </>
  )
}
