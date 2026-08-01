#!/usr/bin/env node
/**
 * Writes public/build-info.json so a deploy can be identified after the fact.
 *
 * Why this exists: on 2026-07-29 a broken prebuild step meant nothing deployed
 * for ~35 minutes while master moved on. The site kept serving the previous
 * build and returning 200, so the only reason anyone noticed was a manual curl.
 * A published commit SHA lets the post-deploy smoke check in frontend.yml tell
 * "the new build is live" from "the old build is still being served", which a
 * plain 200 check cannot do.
 *
 * This runs in prebuild, so it must never fail the build — a missing marker is
 * a lost signal, not a reason to ship nothing. Every failure path falls back to
 * writing 'unknown' and exiting 0.
 */
import { execSync } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const PUBLIC_DIR = path.resolve(__dirname, '..', 'public')

function resolveSha() {
  // CI provides the SHA directly; outside CI, ask git; if neither works the
  // marker still gets written, just without a usable identity.
  if (process.env.GITHUB_SHA) return process.env.GITHUB_SHA
  try {
    return execSync('git rev-parse HEAD', { stdio: ['ignore', 'pipe', 'ignore'] })
      .toString()
      .trim()
  } catch {
    return 'unknown'
  }
}

try {
  mkdirSync(PUBLIC_DIR, { recursive: true })
  const info = { sha: resolveSha(), builtAt: new Date().toISOString() }
  writeFileSync(path.join(PUBLIC_DIR, 'build-info.json'), JSON.stringify(info) + '\n', 'utf8')
  console.log(`[build-info] sha=${info.sha} builtAt=${info.builtAt}`)
} catch (err) {
  console.warn(`[build-info] skipped: ${err.message}`)
}
