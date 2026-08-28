# Errors — CRITICAL & HIGH

## CRITICAL

### ERR-001: CVE-2025-66478 — RCE (CVSS 10.0)
```
Unauthenticated RCE via insecure deserialization (Next-Action header)
```
**Fix:** `pnpm add next@16.0.10` | **Affected:** 15.0.0–16.0.x

### ERR-002: Async params/searchParams Removed
```
TypeError: Cannot read properties of undefined (reading '0')
```
**Fix:** `await params`, `await searchParams`, `await cookies()`, `await headers()`
**Codemod:** `npx @next/codemod next-async-request-api .`

### ERR-003: middleware.ts Silently Ignored
```
No error or warning. Auth guards simply stop executing.
```
**Fix:** Rename `middleware.ts` → `proxy.ts`, `middleware()` → `proxy()`
**Codemod:** `npx @next/codemod middleware-to-proxy .`

### ERR-004: htmlLimitedBots Build Crash (16.1.x)
```
TypeError: Cannot read properties of undefined (reading 'source')
```
**Patch:** `htmlLimitedBots: nextConfig.htmlLimitedBots?.source,`

### ERR-005: useContext null in /_global-error (16.0.2–16.0.3)
```
TypeError: Cannot read properties of null (reading 'useContext')
```
**Fix:** None. Update to latest 16.x patch.

## HIGH

### ERR-006: Turbopack + Webpack Config Conflict
```
ERROR: This build is using Turbopack, with a `webpack` config
```
**Fix A:** `"dev": "next dev --webpack"` | **Fix B:** Migrate to `turbopack: { rules: {} }`

### ERR-007: Uncached Data Outside Suspense
```
Error: Uncached data was accessed outside of <Suspense>.
```
**Fix:** Wrap in `<Suspense>` or add `'use cache'` to async function.

### ERR-008: SWC Options Undefined (16.1.6)
```
SWC binary crash (silent)
```
**Patch:** `cacheComponentsEnabled: isCacheComponents ?? false` (3 locations in swc/options.js)

### ERR-009: Missing NextRequest/NextResponse Stubs (16.1.6)
```
Module not found: Can't resolve 'next/dist/server/web/exports/next-response'
```
**Patch:** Create 4 stub files re-exporting from `spec-extension/`.

### ERR-010: Dynamic APIs Inside Cache Scope
```
Error: Accessing Dynamic data sources inside a cache scope is not supported.
```
**Fix:** Read cookies/headers OUTSIDE cache function, pass as argument:
```tsx
const cookieHeader = (await cookies()).toString()
const data = await getCachedData(cookieHeader)
async function getCachedData(cookie: string) {
  'use cache'
  return auth.getSession({ headers: { Cookie: cookie } })
}
```

### ERR-011: "use cache" Prerender Timeout
```
Error: Filling a cache during prerender timed out
```
**Fix:** Separate cached function from params access:
```tsx
async function getCachedData(slug: string) {
  'use cache'
  return await fetchData(slug)
}
export default async function Page({ params }) {
  const { slug } = await params
  return <div>{await getCachedData(slug)}</div>
}
```

### ERR-012: Route Segment Config + cacheComponents
```
Route segment config "dynamic" is not compatible with `nextConfig.experimental.cacheComponents`.
```
**Fix:** Remove `export const dynamic/revalidate/fetchCache`. Use `'use cache'` + `cacheLife()`.

### ERR-013: Functions Passed to Client Components
```
Functions cannot be passed directly to Client Components unless marked with "use server".
```
**Fix:** Create `'use client'` wrapper: `export { Link }` from next/link.

### ERR-014: useState/useContext null in Build (16.0.1–16.0.3)
```
TypeError: Cannot read properties of null (reading 'useState')
```
**Fix:** Ensure `'use client'`, check `pnpm ls react` for duplicates, or `dynamic(import, { ssr: false })`
