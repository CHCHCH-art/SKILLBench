# Next.js 15 → 16 Breaking Changes

| # | Change | Before (v15) | After (v16) | Impact |
|---|--------|-------------|-------------|--------|
| 1 | **Middleware → Proxy** | `middleware.ts` / `middleware()` | `proxy.ts` / `proxy()` | CRITICAL — silent failure |
| 2 | **Async Request APIs** | `params.slug`, `cookies()` sync | Must `await params`, `await cookies()` | CRITICAL — TypeError |
| 3 | **fetch not cached** | Auto-cached | `{ cache: 'force-cache' }` required | HIGH |
| 4 | **Turbopack default** | Webpack default | Turbopack default (`--webpack` to revert) | HIGH |
| 5 | **Route segment configs removed** | `export const dynamic = 'force-dynamic'` | Use `'use cache'` + `cacheLife()` | HIGH |
| 6 | **PPR config renamed** | `experimental: { ppr: true }` | `cacheComponents: true` | MEDIUM |
| 7 | **unstable_cache deprecated** | `unstable_cache(fn, keys, opts)` | `'use cache'` + `cacheTag(tag)` | MEDIUM |
| 8 | **Edge dropped for PPR** | Edge + PPR supported | Cache Components = Node.js only | MEDIUM |
| 9 | **Image priority** | `<Image priority />` | `<Image loading="eager" fetchPriority="high" />` | MEDIUM |
| 10 | **remotePatterns required** | `images.domains` | `images.remotePatterns` with `protocol` + `hostname` | MEDIUM |
| 11 | **Proxy = Node.js only** | Middleware on Edge | proxy.ts on Node.js (not configurable) | LOW |
| 12 | **Config renames** | `skipMiddlewareUrlNormalize` | `skipProxyUrlNormalize` | LOW |

## Codemods

```bash
# Upgrade packages
npx @next/codemod@latest upgrade latest

# Rename middleware → proxy
npx @next/codemod@canary middleware-to-proxy .

# Async request APIs
npx @next/codemod next-async-request-api .
```

**Codemod catches ~80%.** Manual audit needed for: nested params props, conditional access, custom hooks, `generateStaticParams`.

## Route Segment Config Replacements

| Old Config | Replacement |
|-----------|-------------|
| `dynamic = 'force-dynamic'` | Remove (all pages dynamic by default) |
| `dynamic = 'force-static'` | `'use cache'` + `cacheLife('max')` |
| `revalidate = 3600` | `'use cache'` + `cacheLife('hours')` |
| `fetchCache = 'force-cache'` | `'use cache'` (auto-caches all fetches in scope) |

## Security: CVE-2025-66478 (CVSS 10.0 — RCE)

**IMMEDIATE ACTION:** Ensure `next@16.0.10+`. Unauthenticated RCE via `Next-Action` header deserialization. Near-100% reliability against default configs.

```bash
pnpm add next@16.0.10   # For 16.0.x
pnpm add next@15.5.7    # For 15.5.x
```
