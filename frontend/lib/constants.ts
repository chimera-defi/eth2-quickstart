/**
 * Application constants and static data
 */

export const SITE_CONFIG = {
  name: 'Ethereum Node Quick Setup',
  shortName: 'ETH2 Quick Start',
  description: 'Transform a fresh cloud server into a fully-configured Ethereum node.',
  github: 'https://github.com/chimera-defi/eth2-quickstart',
}

export const NAV_LINKS = [
  { label: 'Learn', href: '/learn' },
  { label: 'GitHub', href: SITE_CONFIG.github, external: true },
]

export const STATS = [
  { value: '12', label: 'Clients Supported' },
  { value: '36', label: 'Client Combinations' },
  { value: '~30m', label: 'Setup Time' },
  { value: '1', label: 'Command' },
]

export const EXECUTION_CLIENTS = [
  { name: 'Geth', language: 'Go', description: 'Original Go implementation, most stable', bestFor: 'Beginners, stability', script: 'geth.sh' },
  { name: 'Erigon', language: 'Go', description: 'Re-architected for efficiency', bestFor: 'Performance, fast sync', script: 'erigon.sh' },
  { name: 'Reth', language: 'Rust', description: 'Modern Rust implementation', bestFor: 'Performance, modularity', script: 'reth.sh' },
  { name: 'Nethermind', language: 'C#', description: 'Enterprise-focused .NET client', bestFor: 'Enterprise, advanced features', script: 'nethermind.sh' },
  { name: 'Besu', language: 'Java', description: 'Apache 2.0 licensed, enterprise-ready', bestFor: 'Private networks, compliance', script: 'besu.sh' },
  { name: 'Nimbus-eth1', language: 'Nim', description: 'Lightweight, resource efficient', bestFor: 'Raspberry Pi, low resources', script: 'nimbus_eth1.sh' },
]

export const CONSENSUS_CLIENTS = [
  { name: 'Prysm', language: 'Go', description: 'Well-documented, reliable', bestFor: 'Beginners, documentation', script: 'prysm.sh' },
  { name: 'Lighthouse', language: 'Rust', description: 'Security-focused, high performance', bestFor: 'Performance, security', script: 'lighthouse.sh' },
  { name: 'Teku', language: 'Java', description: 'ConsenSys-developed, enterprise features', bestFor: 'Institutional, monitoring', script: 'teku.sh' },
  { name: 'Nimbus', language: 'Nim', description: 'Lightweight, resource efficient', bestFor: 'Raspberry Pi, low resources', script: 'nimbus.sh' },
  { name: 'Lodestar', language: 'TypeScript', description: 'Developer-friendly, modern', bestFor: 'Development, TypeScript devs', script: 'lodestar.sh' },
  { name: 'Grandine', language: 'Rust', description: 'High-performance, cutting-edge', bestFor: 'Advanced users, performance', script: 'grandine.sh' },
]

export const FEATURES = [
  {
    id: 'client-diversity',
    title: 'Choose Your Perfect Client Stack',
    description: 'Support for all major Ethereum clients—mix and match execution and consensus clients for optimal performance and network diversity. From lightweight Nimbus to enterprise-grade Teku, find the perfect combination for your hardware and needs.',
    icon: 'Grid3x3',
  },
  {
    id: 'one-liner',
    title: 'From Zero to Node in One Command',
    description: 'No manual configuration files. No hours of reading documentation. Just one command and you\'re running. Our automated scripts handle everything—security hardening, client installation, MEV setup, and RPC configuration.',
    icon: 'Terminal',
  },
  {
    id: 'security',
    title: 'Enterprise-Grade Security Out of the Box',
    description: 'Firewall rules, fail2ban, SSH hardening, secure file permissions—all configured automatically. Your node is protected from day one with industry best practices and comprehensive security monitoring.',
    icon: 'Shield',
  },
  {
    id: 'mev',
    title: 'Maximize Validator Rewards',
    description: 'Built-in MEV-Boost and Commit-Boost support. Configure once, earn more. Connect to multiple relays, set minimum bids, and optimize your validator rewards automatically.',
    icon: 'TrendingUp',
  },
  {
    id: 'rpc',
    title: 'Your Own Censorship-Resistant RPC',
    description: 'Run your own RPC endpoint. Faster than Infura/Alchemy, completely uncensored. Share with friends, use for your dApps, or offer as a service. Includes SSL certificates, rate limiting, and security hardening.',
    icon: 'Globe',
  },
]

export const DOCUMENTATION_LINKS = [
  { title: 'Main README', description: 'Project overview and quickstart guide', path: 'README.md' },
  { title: 'Scripts Reference', description: 'Detailed script reference and usage', path: 'docs/SCRIPTS.md' },
  { title: 'Configuration Guide', description: 'Configuration architecture and conventions', path: 'docs/CONFIGURATION_GUIDE.md' },
  { title: 'Security Guide', description: 'Comprehensive security documentation', path: 'docs/SECURITY_GUIDE.md' },
  { title: 'MEV Guide', description: 'MEV setup and configuration', path: 'docs/MEV_GUIDE.md' },
  { title: 'Workflow Guide', description: 'Setup workflow and process', path: 'docs/WORKFLOW.md' },
]

export const INSTALLATION_STEPS = [
  {
    step: 1,
    title: 'Download and Prepare',
    description: 'Clone the repository and make scripts executable.',
    code: `git clone https://github.com/chimera-defi/eth2-quickstart
cd eth2-quickstart
chmod +x run_1.sh`,
  },
  {
    step: 2,
    title: 'Run Server Setup',
    description: 'This script upgrades Ubuntu, sets up firewalls, security hardening, and creates a non-root user.',
    code: 'sudo ./run_1.sh',
  },
  {
    step: 3,
    title: 'Reboot and Configure',
    description: 'After the initial setup, reboot and login as the new user.',
    code: `sudo reboot
# Login as new user (default: eth@ip)`,
  },
  {
    step: 4,
    title: 'Configure and Install Clients',
    description: 'Edit your configuration or use the interactive selector, then run the installation.',
    code: `# Edit exports.sh with your settings
nano exports.sh

# Or use interactive client selection
./select_clients.sh

# Run installation
./run_2.sh`,
  },
  {
    step: 5,
    title: 'Start Services',
    description: 'Start and verify all services are running correctly.',
    code: `sudo systemctl start eth1 cl validator mev
sudo systemctl status eth1 cl validator mev`,
  },
]

export const PREREQUISITES = [
  { label: 'Server', value: 'Cloud VPS with SSH access (Ubuntu 20.04+)' },
  { label: 'Hardware', value: '2-4TB SSD/NVMe, 16-64GB RAM, 4-8 cores' },
  { label: 'Network', value: 'Stable broadband connection (unmetered preferred)' },
  { label: 'Access', value: 'SSH key configured or root access' },
]

export const TROUBLESHOOTING = [
  {
    issue: 'Services not starting',
    solution: 'Check logs with journalctl -u service_name -f and verify configuration with ./docs/verify_security.sh',
  },
  {
    issue: 'Sync issues',
    solution: 'Verify network connectivity, check client status, and review client-specific documentation.',
  },
  {
    issue: 'Permission errors',
    solution: 'Ensure proper file ownership, check file permissions, and verify user has sudo access.',
  },
]
