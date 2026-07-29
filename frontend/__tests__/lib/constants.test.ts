import {
  SITE_CONFIG,
  NAV_LINKS,
  STATS,
  EXECUTION_CLIENTS,
  CONSENSUS_CLIENTS,
  FEATURES,
  DOCUMENTATION_LINKS,
  INSTALLATION_STEPS_ONELINER,
  INSTALLATION_STEPS_MANUAL,
  PREREQUISITES,
  TOTAL_CLIENTS,
  FAQ_ITEMS,
} from '@/lib/constants'

describe('constants', () => {
  it('SITE_CONFIG has required properties', () => {
    expect(SITE_CONFIG.github).toMatch(/^https:\/\/github\.com\//)
  })

  it('arrays are not empty', () => {
    expect(NAV_LINKS.length).toBeGreaterThan(0)
    expect(STATS.length).toBeGreaterThan(0)
    expect(EXECUTION_CLIENTS).toHaveLength(7)
    expect(CONSENSUS_CLIENTS).toHaveLength(6)
    expect(FEATURES).toHaveLength(5)
    expect(DOCUMENTATION_LINKS.length).toBeGreaterThan(0)
    expect(INSTALLATION_STEPS_ONELINER).toHaveLength(5)
    expect(INSTALLATION_STEPS_MANUAL).toHaveLength(5)
    expect(PREREQUISITES.length).toBeGreaterThan(0)
  })

  it('clients have required properties', () => {
    EXECUTION_CLIENTS.forEach(c => {
      expect(c).toHaveProperty('name')
      expect(c).toHaveProperty('language')
    })
    CONSENSUS_CLIENTS.forEach(c => {
      expect(c).toHaveProperty('name')
      expect(c).toHaveProperty('language')
    })
  })

  it('stats stay aligned with supported client matrix', () => {
    const clientsStat = STATS.find(s => s.label === 'Clients')
    const combosStat = STATS.find(s => s.label === 'Combinations')

    expect(clientsStat?.value).toBe(String(EXECUTION_CLIENTS.length + CONSENSUS_CLIENTS.length))
    expect(combosStat?.value).toBe(String(EXECUTION_CLIENTS.length * CONSENSUS_CLIENTS.length))
  })

  it('installation steps are sequential', () => {
    INSTALLATION_STEPS_ONELINER.forEach((step, i) => {
      expect(step.step).toBe(i + 1)
    })
    INSTALLATION_STEPS_MANUAL.forEach((step, i) => {
      expect(step.step).toBe(i + 1)
    })
  })

  it('TOTAL_CLIENTS matches the execution + consensus client matrix', () => {
    expect(TOTAL_CLIENTS).toBe(EXECUTION_CLIENTS.length + CONSENSUS_CLIENTS.length)
  })

  it('FAQ_ITEMS are non-empty, unique questions with substantive answers', () => {
    expect(FAQ_ITEMS.length).toBeGreaterThan(0)
    const questions = FAQ_ITEMS.map((item) => item.question)
    expect(new Set(questions).size).toBe(questions.length)
    FAQ_ITEMS.forEach((item) => {
      expect(item.question.length).toBeGreaterThan(0)
      expect(item.answer.length).toBeGreaterThan(20)
    })
  })
})
