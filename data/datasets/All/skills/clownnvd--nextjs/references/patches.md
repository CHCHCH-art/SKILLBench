# Patches — Next.js 16.1.6 (CViet Project)

All patches applied via `scripts/postinstall.js` (runs after `pnpm install`):

```json
{ "scripts": { "postinstall": "node scripts/postinstall.js" } }
```

## 6 Postinstall Patches

| # | File | Bug | Fix | Severity |
|---|------|-----|-----|----------|
| 1 | `generate-build-id.js` | `generate()` without type guard | `typeof generate === "function" ? await generate() : null` | Medium |
| 2 | `swc/options.js` (3 spots) | `useCacheEnabled`/`cacheComponentsEnabled` = undefined → SWC crash | `?? false` null-coalescing | High |
| 3 | `next-response/request.js` stubs (4 files) | Missing from npm package, SWC tree-shaking fails | Create CJS + ESM stubs re-exporting from `spec-extension/` | High |
| 4 | `after-production-compile.js` | `config.compiler` undefined | `config.compiler && config.compiler.runAfterProductionCompile` | Medium |
| 5 | `build/index.js` | `picomatch.makeRe(undefined)` | `p.hostname ? makeRe(p.hostname).source : "**"` | Medium |
| 6 | `export/index.js:337` | `htmlLimitedBots.source` without optional chaining | `htmlLimitedBots?.source` | **Critical** |

## 3 Config Workarounds

| # | File | Config | Why |
|---|------|--------|-----|
| 7 | `next.config.ts` | `compiler: {}` | Prevents `undefined.someProperty` access. Do NOT add `reactCompiler: true` or `cacheComponents: true` — causes SWC errors. |
| 8 | `next.config.ts` | `serverExternalPackages: ["@react-pdf/renderer"]` | Native modules can't be bundled by webpack/turbopack. |
| 9 | `package.json` | `"dev": "cross-env NODE_ENV=development next dev --webpack"` | VSCode sets `NODE_ENV=production` breaking Tailwind v4. `--webpack` avoids Turbopack incompatibilities. |

## Complete next.config.ts

```ts
import type { NextConfig } from 'next'
const nextConfig: NextConfig = {
  serverExternalPackages: ["@react-pdf/renderer"],
  compiler: {},   // Required — do NOT add reactCompiler or cacheComponents
}
export default nextConfig
```

## Build Command (CI/CD)

```bash
BETTER_AUTH_SECRET="..." DATABASE_URL="postgresql://fake:fake@localhost/fake" \
  NEXT_PUBLIC_APP_URL="http://localhost:3000" pnpm build
```

## Upgrade Protocol

After updating Next.js version:
1. Run `pnpm build` WITHOUT `postinstall.js` to see which patches are still needed
2. The patch script is idempotent — skips patches where target string no longer exists
3. Re-enable `postinstall.js` and verify build passes
