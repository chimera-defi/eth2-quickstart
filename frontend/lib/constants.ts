/**
 * Application constants
 */

export const SITE_CONFIG = {
  name: 'Ethereum Node Quick Setup',
  shortName: 'ETH2 Quick Start',
  description: 'Transform a fresh cloud server into a fully-configured Ethereum node.',
  github: 'https://github.com/chimera-defi/eth2-quickstart',
  url: 'https://eth2quickstart.com',
}

export const NAV_LINKS = [
  { label: 'Install', href: '/#install' },
  { label: 'Blog', href: '/blog' },
  { label: 'Get Started', href: '/quickstart' },
  { label: 'Agents', href: '/agents' },
  { label: 'GitHub', href: SITE_CONFIG.github, external: true },
]

export const EXECUTION_CLIENTS = [
  { name: 'Geth', language: 'Go', bestFor: 'Beginners, stability' },
  { name: 'Erigon', language: 'Go', bestFor: 'Performance, fast sync' },
  { name: 'Reth', language: 'Rust', bestFor: 'Performance, modularity' },
  { name: 'Nethermind', language: 'C#', bestFor: 'Enterprise, advanced features' },
  { name: 'Besu', language: 'Java', bestFor: 'Private networks, compliance' },
  { name: 'Nimbus-eth1', language: 'Nim', bestFor: 'Low resources' },
  { name: 'Ethrex', language: 'Rust', bestFor: 'Early adopters, modular L1/L2 support' },
]

export const CONSENSUS_CLIENTS = [
  { name: 'Prysm', language: 'Go', bestFor: 'Beginners, documentation' },
  { name: 'Lighthouse', language: 'Rust', bestFor: 'Performance, security' },
  { name: 'Teku', language: 'Java', bestFor: 'Institutional, monitoring' },
  { name: 'Nimbus', language: 'Nim', bestFor: 'Low resources' },
  { name: 'Lodestar', language: 'TypeScript', bestFor: 'Development' },
  { name: 'Grandine', language: 'Rust', bestFor: 'Advanced users' },
]

// Exported so any copy that states the client count (Hero quick-answer, FAQ)
// derives it instead of hardcoding a number that can drift when a client is
// added or removed (see EXECUTION_CLIENTS / CONSENSUS_CLIENTS above).
export const TOTAL_CLIENTS = EXECUTION_CLIENTS.length + CONSENSUS_CLIENTS.length
const TOTAL_COMBINATIONS = EXECUTION_CLIENTS.length * CONSENSUS_CLIENTS.length

export const STATS = [
  { value: String(TOTAL_CLIENTS), label: 'Clients' },
  { value: String(TOTAL_COMBINATIONS), label: 'Combinations' },
  { value: '~30m', label: 'Setup Time' },
  { value: '2-step', label: 'Hardened Flow' },
]

export const INSTALL_COMMAND =
  'curl -fsSL https://raw.githubusercontent.com/chimera-defi/eth2-quickstart/master/install.sh | sudo bash'

export const INSTALL_HIGHLIGHTS = [
  {
    title: 'Bootstraps safely',
    description: 'Runs a two-phase flow: hardened base setup, reboot, then client install.',
    icon: 'Shield',
  },
  {
    title: 'Configurable wizard',
    description: 'Supports guided TUI on a real TTY and auto-falls back to non-interactive defaults for one-line piped installs.',
    icon: 'Terminal',
  },
  {
    title: 'Everything included',
    description: 'Sets up monitoring, firewalls, and service management automatically.',
    icon: 'Grid3x3',
  },
]

export const WORKFLOW_STEPS = [
  {
    title: 'Bootstrap the host',
    description: 'Run the one-line installer to clone the repo, verify requirements, and launch the wizard.',
    detail: 'Includes firewall rules, SSH hardening, and a non-root operator user.',
  },
  {
    title: 'Reboot & validate',
    description: 'Reboot to confirm secure access with the new user and updated SSH settings.',
    detail: 'The script pauses and reminds you to verify access before proceeding.',
  },
  {
    title: 'Install clients',
    description: 'Select execution and consensus clients, MEV relay presets, and monitoring.',
    detail: 'The installer configures services, systemd units, and auto-start.',
  },
  {
    title: 'Go live',
    description: 'Start services and monitor sync progress from a dedicated dashboard.',
    detail: 'Health checks and logs are included for ongoing ops.',
  },
]

export const FEATURES = [
  {
    id: 'client-diversity',
    title: 'Choose Your Client Stack',
    description: 'Support for all major Ethereum clients. Mix and match for optimal performance and network diversity.',
    icon: 'Grid3x3',
  },
  {
    id: 'one-liner',
    title: 'One Command Setup',
    description: 'No manual configuration. One command handles security, client installation, and MEV setup.',
    icon: 'Terminal',
  },
  {
    id: 'security',
    title: 'Security Out of the Box',
    description: 'Firewall, fail2ban, SSH hardening, and secure permissions—all configured automatically.',
    icon: 'Shield',
  },
  {
    id: 'mev',
    title: 'Maximize Rewards',
    description: 'Built-in MEV-Boost, Commit-Boost, and optional ETHGas support.',
    icon: 'TrendingUp',
  },
  {
    id: 'rpc',
    title: 'Your Own RPC',
    description: 'Run your own censorship-resistant RPC endpoint. Faster and uncensored.',
    icon: 'Globe',
  },
]

export const DOCUMENTATION_LINKS = [
  { title: 'README', description: 'Project overview and quickstart', path: 'README.md' },
  { title: 'Scripts', description: 'Script reference and usage', path: 'docs/SCRIPTS.md' },
  { title: 'Configuration', description: 'Configuration guide', path: 'docs/CONFIGURATION_GUIDE.md' },
  { title: 'Security', description: 'Security documentation', path: 'docs/SECURITY_GUIDE.md' },
]

/** One-liner flow - curl runs install.sh, wizard generates install_phase1.sh and install_phase2.sh */
export const INSTALLATION_STEPS_ONELINER = [
  {
    step: 1,
    title: 'Run the one-line installer',
    description: 'Clones the repo and generates phase scripts. Defaults to non-interactive in piped mode; use --interactive when running from a real TTY.',
    code: 'curl -fsSL https://raw.githubusercontent.com/chimera-defi/eth2-quickstart/master/install.sh | sudo bash',
  },
  {
    step: 2,
    title: 'Run Phase 1 (as root)',
    description: 'Use the path shown when the wizard completes (typically ~/.eth2-quickstart). Hardens firewall, SSH, creates non-root user.',
    code: 'cd ~/.eth2-quickstart && ./install_phase1.sh',
  },
  {
    step: 3,
    title: 'Reboot',
    description: 'Reboot and SSH back in as the new user.',
    code: 'sudo reboot',
  },
  {
    step: 4,
    title: 'Run Phase 2 (as new user)',
    description: 'run_1.sh copies the repo to ~/eth2-quickstart for the new user. Run from there.',
    code: 'cd ~/eth2-quickstart && ./install_phase2.sh',
  },
  {
    step: 5,
    title: 'Start Services',
    description: 'Start and verify all services. Omit mev if you skipped MEV installation.',
    code: 'sudo systemctl start eth1 cl validator mev',
  },
]

/** Manual flow - uses pre-existing run_1.sh and run_2.sh from the repo */
export const INSTALLATION_STEPS_MANUAL = [
  {
    step: 1,
    title: 'Clone Repository',
    description: 'Download the repo. run_1.sh and run_2.sh are included—make run_1.sh executable.',
    code: `git clone https://github.com/chimera-defi/eth2-quickstart
cd eth2-quickstart && chmod +x run_1.sh`,
  },
  {
    step: 2,
    title: 'Add SSH key, then run run_1.sh (as root)',
    description: 'Add your SSH key first to prevent lockout. The run_1.sh script hardens firewall, SSH, creates non-root user, copies repo to ~/eth2-quickstart for the new user.',
    code: `ssh-copy-id root@<your-server-ip>
./run_1.sh   # or: sudo ./run_1.sh if not root`,
  },
  {
    step: 3,
    title: 'Reboot',
    description: 'Reboot and SSH back in as the new user (e.g. eth@ip).',
    code: 'sudo reboot',
  },
  {
    step: 4,
    title: 'Install Clients with run_2.sh (as new user)',
    description: 'Edit exports.sh with your settings, then run run_2.sh. Use install/utils/select_clients.sh for client recommendations.',
    code: `nano exports.sh  # Edit settings
./install/utils/select_clients.sh  # Optional: get recommendations
./run_2.sh           # Install clients`,
  },
  {
    step: 5,
    title: 'Start Services',
    description: 'Start and verify all services. Omit mev if you skipped MEV installation.',
    code: 'sudo systemctl start eth1 cl validator mev',
  },
]

export const PREREQUISITES = [
  { label: 'Server', value: 'Ubuntu 20.04+ with SSH key access (bare metal VPS preferred)' },
  { label: 'Storage', value: '2–4TB SSD/NVMe (4TB NVMe recommended)' },
  { label: 'Memory', value: '16–64GB RAM (32GB+ recommended)' },
  { label: 'CPU', value: '4–8+ cores (8+ recommended for sync)' },
  { label: 'Network', value: 'Stable broadband, unlimited data preferred' },
  { label: 'RAID', value: 'Set swraid 1 & swraidlevel 0 for full disk access before install' },
]

const EXECUTION_CLIENT_NAMES = EXECUTION_CLIENTS.map((c) => c.name).join(', ')
const CONSENSUS_CLIENT_NAMES = CONSENSUS_CLIENTS.map((c) => c.name).join(', ')
const SETUP_TIME = STATS.find((s) => s.label === 'Setup Time')?.value ?? '~30m'
const DISK_PREREQ = PREREQUISITES.find((p) => p.label === 'Storage')?.value ?? ''
const RAM_PREREQ = PREREQUISITES.find((p) => p.label === 'Memory')?.value ?? ''
const CPU_PREREQ = PREREQUISITES.find((p) => p.label === 'CPU')?.value ?? ''

/**
 * Single source of truth for the homepage FAQ: both the visible
 * `components/sections/Faq.tsx` and the `FAQPage` JSON-LD in
 * `components/ui/FaqJsonLd.tsx` render from this array, so the visible copy
 * and the structured data can never drift apart. Answers are written to be
 * self-contained and quotable in isolation (an LLM lifting just the answer
 * text should still make sense).
 */
export const FAQ_ITEMS = [
  {
    question: 'How do I set up an Ethereum validator?',
    answer: `Run the one-line installer, complete Phase 1 (security hardening) as root, reboot, then run Phase 2 as the new non-root user to install and configure your validator — ${SETUP_TIME} end-to-end for the install. The node then syncs over hours to days (and mainnet has an activation queue) before it actually starts validating.`,
  },
  {
    question: 'How do I run an Ethereum node?',
    answer:
      'The same two-phase installer works without a validator key: Phase 1 hardens the host, Phase 2 installs your chosen execution and consensus clients so you get a synced node with your own local RPC endpoint.',
  },
  {
    question: 'Which Ethereum execution or consensus client should I choose?',
    answer: `eth2-quickstart supports ${EXECUTION_CLIENTS.length} execution clients (${EXECUTION_CLIENT_NAMES}) and ${CONSENSUS_CLIENTS.length} consensus clients (${CONSENSUS_CLIENT_NAMES}) — ${TOTAL_COMBINATIONS} possible combinations. Geth + Prysm is the well-documented default for beginners; the client bake-off measured disk-footprint and sync-time trade-offs for the rest.`,
  },
  {
    question: 'How much disk, RAM, and CPU does an Ethereum node need?',
    answer: `Plan for ${DISK_PREREQ}, ${RAM_PREREQ}, and ${CPU_PREREQ}. Disk is the most common constraint — a bare-metal VPS with NVMe storage is strongly preferred over cloud block storage.`,
  },
  {
    question: 'Is it safe? How are validator keys and secrets handled?',
    answer:
      'Phase 1 hardens SSH (key-only auth, non-standard port, no root login), enables a strict firewall and fail2ban, and every service runs as a non-root user. Keys and JWT secrets live under $HOME/secrets with 600/700 permissions and are never touched by the agent/MCP layer.',
  },
  {
    question: 'Can an AI agent set this up for me?',
    answer:
      'Yes — the repo ships a packaged agent skill, an MCP server, and a JSON-first ./scripts/eth2qs.sh CLI that an agent can drive directly; see /agents for the copy-paste setup and the safety contract.',
  },
]
