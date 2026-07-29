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
// The generated files are NOT committed (see frontend/.gitignore) — they
// are always a fresh copy of the repo-root source plus one inserted line
// bridging back to the site + GitHub repo, so there is nothing to keep
// manually in sync. If you need to check they match by hand: re-run this
// script and diff frontend/public/llms.txt against llms.txt (the only
// expected difference is the inserted bridge line below the title).

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
