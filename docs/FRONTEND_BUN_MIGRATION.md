# Frontend Migration to Bun

## Overview

The frontend has been migrated from npm to [Bun](https://bun.sh) for improved performance and developer experience. Bun is a fast all-in-one JavaScript runtime, bundler, test runner, and package manager.

## Migration Date

**Date:** 2024-12-19  
**Reason:** Bun provides significantly faster package installation, builds, and test execution compared to npm.

## What Changed

### Package Management
- **Before:** `npm install`, `npm ci`, `npm run <script>`
- **After:** `bun install`, `bun install --frozen-lockfile`, `bun run <script>`

### Lock Files
- **Removed:** `package-lock.json` (npm lock file)
- **Added:** `bun.lockb` (Bun binary lock file - should be committed to git)

### CI/CD Workflow
- **Before:** Used `actions/setup-node@v4` with npm caching
- **After:** Uses `oven-sh/setup-bun@v2` with Bun's built-in caching

### Commands Reference

| Task | npm Command | Bun Command |
|------|-------------|-------------|
| Install dependencies | `npm install` | `bun install` |
| Install (CI) | `npm ci` | `bun install --frozen-lockfile` |
| Run script | `npm run <script>` | `bun run <script>` |
| Run dev server | `npm run dev` | `bun run dev` |
| Build | `npm run build` | `bun run build` |
| Test | `npm test` | `bun test` |
| Type check | `npx tsc --noEmit` | `bunx tsc --noEmit` |

## Installation

### Installing Bun

**macOS/Linux:**
```bash
curl -fsSL https://bun.sh/install | bash
```

**Windows:**
```powershell
powershell -c "irm bun.sh/install.ps1 | iex"
```

**Docker:**
```dockerfile
FROM oven/bun:latest
```

### Verifying Installation

```bash
bun --version
```

## Benefits

1. **Speed:** Bun installs packages 2-3x faster than npm
2. **Built-in Test Runner:** No need for Jest configuration (though we still use Jest for compatibility)
3. **Native TypeScript:** TypeScript support out of the box
4. **Better Performance:** Faster builds and test execution
5. **Compatibility:** Works with existing npm packages and Next.js

## CI/CD Changes

The GitHub Actions workflow (`.github/workflows/frontend.yml`) now:
- Uses `oven-sh/setup-bun@v2` action
- Runs `bun install --frozen-lockfile` for reproducible builds
- Uses `bunx` for running tools like TypeScript compiler
- Maintains the same job structure (lint, test, build)

## Migration Checklist

- [x] Remove `package-lock.json`
- [x] Update CI workflow to use Bun
- [x] Update README.md with Bun commands
- [x] Update .gitignore (bun.lockb should be committed)
- [x] Create migration documentation
- [x] Update documentation references

## Troubleshooting

### Bun not found
If you get "bun: command not found", install Bun using the command above or add it to your PATH.

### Lock file conflicts
If you see lock file conflicts:
1. Delete `node_modules` and `bun.lockb`
2. Run `bun install` to regenerate the lock file
3. Commit the new `bun.lockb`

### Package compatibility
Bun is compatible with npm packages. If you encounter issues:
- Check the package's compatibility with Bun
- Some packages may need specific Bun configurations
- Report issues to the Bun GitHub repository

## Future Considerations

- Consider migrating Jest tests to Bun's built-in test runner for even better performance
- Explore Bun's native bundler for potential build optimizations
- Monitor Bun updates for new features and improvements

## References

- [Bun Documentation](https://bun.sh/docs)
- [Bun GitHub](https://github.com/oven-sh/bun)
- [Bun vs npm Performance](https://bun.sh/docs/install)
