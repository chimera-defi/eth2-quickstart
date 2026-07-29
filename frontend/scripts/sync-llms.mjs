// Anti-drift step for serving /llms.txt and /llms-full.txt on the website.
//
// Why this exists: the canonical llms.txt / llms-full.txt live at the repo
// root and are the source of truth for agent-facing instructions (see
// docs/GEO_AEO_DISCOVERABILITY_PLAN.md, item A2). The website must serve the
// *same* content, or the two copies silently drift and an agent that reads
// eth2quickstart.com/llms.txt gets stale instructions.
//
// Rather than hand-copy the files into frontend/public (which forks
// maintenance the moment either source file is edited), this script
// regenerates frontend/public/llms.txt and frontend/public/llms-full.txt
// from the repo-root files on every run. It is wired as `predev`/`prebuild`
// in package.json, so it always runs before `bun run dev` / `bun run build`.
//
// IMPORTANT — the generated files ARE COMMITTED, not gitignored. The deploy
// pipeline for eth2quickstart.com lives outside this repo (CloudFront + a
// Next standalone build), so we cannot assume it runs `bun run build`; if it
// invokes `next build` directly or restores a cached layer, the `prebuild`
// lifecycle hook never fires. Were these files gitignored, they would then be
// absent from the checkout and the site would ship without them — leaving
// /llms.txt a silent 404, which is the exact bug this feature exists to fix.
// Every other asset in frontend/public (og.png, deck/) is committed for the
// same reason.
//
// So: this script keeps the committed copies fresh, and CI enforces they
// match — see the "Verify served llms.txt files match repo root" step in
// .github/workflows/frontend.yml, which re-runs this script and fails on any
// diff. Workflow when editing agent instructions: edit the repo-root
// llms.txt / llms-full.txt, run `bun scripts/sync-llms.mjs`, then commit both
// the source and the regenerated public/ copies. The only difference between
// a source file and its served copy is the bridge line inserted below the title.

import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const REPO_ROOT = path.resolve(__dirname, '..', '..')
const PUBLIC_DIR = path.resolve(__dirname, '..', 'public')

const SITE_URL = 'https://eth2quickstart.com'
const GITHUB_URL = 'https://github.com/chimera-defi/eth2-quickstart'

const SOURCE_FILES = ['llms.txt', 'llms-full.txt']

function bridgeLine() {
  return `Website: ${SITE_URL} · Source: ${GITHUB_URL}`
}

/**
 * Inserts the bridge line right after the first line (the `# Title` line)
 * so the served copy keeps a valid llms.txt-format leading H1, e.g.:
 *
 *   # eth2-quickstart
 *
 *   Website: https://eth2quickstart.com · Source: https://github.com/...
 *
 *   > Repo-backed Ethereum node operations toolkit...
 */
function withBridgeLine(source) {
  const lines = source.split('\n')
  const titleLine = lines[0]
  const rest = lines.slice(1)
  return [titleLine, '', bridgeLine(), ...rest].join('\n')
}

for (const file of SOURCE_FILES) {
  const sourcePath = path.join(REPO_ROOT, file)
  if (!existsSync(sourcePath)) {
    throw new Error(`sync-llms: expected repo-root file not found: ${sourcePath}`)
  }

  const source = readFileSync(sourcePath, 'utf8')
  const generated = withBridgeLine(source)
  const destPath = path.join(PUBLIC_DIR, file)

  writeFileSync(destPath, generated, 'utf8')
  console.log(`[sync-llms] wrote public/${file} from repo-root ${file}`)
}
