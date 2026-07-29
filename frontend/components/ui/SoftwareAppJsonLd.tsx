import {
  SITE_CONFIG,
  EXECUTION_CLIENTS,
  CONSENSUS_CLIENTS,
  PREREQUISITES,
  FEATURES,
} from '@/lib/constants'

/**
 * SoftwareApplication JSON-LD for the homepage.
 *
 * This is the defensible structured-data win for a tool like this one (see
 * docs/GEO_AEO_DISCOVERABILITY_PLAN.md, item A3): unlike FAQPage/HowTo,
 * SoftwareApplication rich-result support was not curtailed by Google, and
 * it's an accurate, literal description of what this repo is — not a claim
 * of measurable ranking gains.
 */
function summarizeRequirements(): string {
  const wanted = ['Storage', 'Memory', 'CPU']
  return PREREQUISITES.filter((p) => wanted.includes(p.label))
    .map((p) => `${p.label}: ${p.value}`)
    .join('; ')
}

function buildFeatureList(): string[] {
  const executionNames = EXECUTION_CLIENTS.map((c) => c.name).join(', ')
  const consensusNames = CONSENSUS_CLIENTS.map((c) => c.name).join(', ')
  const featureTitle = (id: string) => FEATURES.find((f) => f.id === id)?.title

  return [
    `${EXECUTION_CLIENTS.length} execution clients: ${executionNames}`,
    `${CONSENSUS_CLIENTS.length} consensus clients: ${consensusNames}`,
    featureTitle('mev'),
    featureTitle('security'),
    featureTitle('rpc'),
  ].filter((item): item is string => Boolean(item))
}

export function SoftwareAppJsonLd() {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: SITE_CONFIG.name,
    description: SITE_CONFIG.description,
    applicationCategory: 'DeveloperApplication',
    operatingSystem: 'Linux (Ubuntu 20.04+)',
    url: SITE_CONFIG.url,
    sameAs: [SITE_CONFIG.github],
    isAccessibleForFree: true,
    offers: {
      '@type': 'Offer',
      price: '0',
      priceCurrency: 'USD',
    },
    softwareRequirements: summarizeRequirements(),
    featureList: buildFeatureList(),
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}
