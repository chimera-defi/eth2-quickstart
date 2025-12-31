import {
  SITE_CONFIG,
  NAV_LINKS,
  STATS,
  EXECUTION_CLIENTS,
  CONSENSUS_CLIENTS,
  FEATURES,
  DOCUMENTATION_LINKS,
  INSTALLATION_STEPS,
  PREREQUISITES,
  TROUBLESHOOTING,
} from '@/lib/constants'

describe('constants', () => {
  describe('SITE_CONFIG', () => {
    it('has required properties', () => {
      expect(SITE_CONFIG).toHaveProperty('name')
      expect(SITE_CONFIG).toHaveProperty('shortName')
      expect(SITE_CONFIG).toHaveProperty('description')
      expect(SITE_CONFIG).toHaveProperty('github')
    })

    it('has valid GitHub URL', () => {
      expect(SITE_CONFIG.github).toMatch(/^https:\/\/github\.com\//)
    })
  })

  describe('NAV_LINKS', () => {
    it('has correct navigation links', () => {
      expect(NAV_LINKS.length).toBeGreaterThan(0)
      expect(NAV_LINKS.some(link => link.label === 'Learn')).toBe(true)
      expect(NAV_LINKS.some(link => link.label === 'GitHub')).toBe(true)
    })
  })

  describe('STATS', () => {
    it('has 4 stats', () => {
      expect(STATS).toHaveLength(4)
    })

    it('each stat has value and label', () => {
      STATS.forEach(stat => {
        expect(stat).toHaveProperty('value')
        expect(stat).toHaveProperty('label')
      })
    })
  })

  describe('EXECUTION_CLIENTS', () => {
    it('has 6 execution clients', () => {
      expect(EXECUTION_CLIENTS).toHaveLength(6)
    })

    it('each client has required properties', () => {
      EXECUTION_CLIENTS.forEach(client => {
        expect(client).toHaveProperty('name')
        expect(client).toHaveProperty('language')
        expect(client).toHaveProperty('description')
        expect(client).toHaveProperty('bestFor')
        expect(client).toHaveProperty('script')
      })
    })

    it('includes expected clients', () => {
      const names = EXECUTION_CLIENTS.map(c => c.name)
      expect(names).toContain('Geth')
      expect(names).toContain('Reth')
      expect(names).toContain('Nethermind')
    })
  })

  describe('CONSENSUS_CLIENTS', () => {
    it('has 6 consensus clients', () => {
      expect(CONSENSUS_CLIENTS).toHaveLength(6)
    })

    it('each client has required properties', () => {
      CONSENSUS_CLIENTS.forEach(client => {
        expect(client).toHaveProperty('name')
        expect(client).toHaveProperty('language')
        expect(client).toHaveProperty('description')
        expect(client).toHaveProperty('bestFor')
        expect(client).toHaveProperty('script')
      })
    })

    it('includes expected clients', () => {
      const names = CONSENSUS_CLIENTS.map(c => c.name)
      expect(names).toContain('Prysm')
      expect(names).toContain('Lighthouse')
      expect(names).toContain('Teku')
    })
  })

  describe('FEATURES', () => {
    it('has 5 features', () => {
      expect(FEATURES).toHaveLength(5)
    })

    it('each feature has required properties', () => {
      FEATURES.forEach(feature => {
        expect(feature).toHaveProperty('id')
        expect(feature).toHaveProperty('title')
        expect(feature).toHaveProperty('description')
        expect(feature).toHaveProperty('icon')
      })
    })
  })

  describe('DOCUMENTATION_LINKS', () => {
    it('has documentation links', () => {
      expect(DOCUMENTATION_LINKS.length).toBeGreaterThan(0)
    })

    it('each link has title, description, and path', () => {
      DOCUMENTATION_LINKS.forEach(link => {
        expect(link).toHaveProperty('title')
        expect(link).toHaveProperty('description')
        expect(link).toHaveProperty('path')
      })
    })
  })

  describe('INSTALLATION_STEPS', () => {
    it('has 5 installation steps', () => {
      expect(INSTALLATION_STEPS).toHaveLength(5)
    })

    it('steps are numbered sequentially', () => {
      INSTALLATION_STEPS.forEach((step, index) => {
        expect(step.step).toBe(index + 1)
      })
    })

    it('each step has required properties', () => {
      INSTALLATION_STEPS.forEach(step => {
        expect(step).toHaveProperty('step')
        expect(step).toHaveProperty('title')
        expect(step).toHaveProperty('description')
        expect(step).toHaveProperty('code')
      })
    })
  })

  describe('PREREQUISITES', () => {
    it('has prerequisite items', () => {
      expect(PREREQUISITES.length).toBeGreaterThan(0)
    })

    it('each prerequisite has label and value', () => {
      PREREQUISITES.forEach(prereq => {
        expect(prereq).toHaveProperty('label')
        expect(prereq).toHaveProperty('value')
      })
    })
  })

  describe('TROUBLESHOOTING', () => {
    it('has troubleshooting items', () => {
      expect(TROUBLESHOOTING.length).toBeGreaterThan(0)
    })

    it('each item has issue and solution', () => {
      TROUBLESHOOTING.forEach(item => {
        expect(item).toHaveProperty('issue')
        expect(item).toHaveProperty('solution')
      })
    })
  })
})
