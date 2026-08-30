# Errors — MEDIUM & LOW

## MEDIUM

| ID | Error Message | Fix |
|----|--------------|-----|
| ERR-015 | `TypeError: generate is not a function` | Patch: `typeof generate === "function" ? await generate() : null` |
| ERR-016 | `Cannot read 'runAfterProductionCompile'` | Add `compiler: {}` to next.config.ts + postinstall patch |
| ERR-017 | `Expected a non-empty string at picomatch.makeRe` | Patch: `p.hostname ? makeRe(p.hostname).source : "**"` + ensure hostname in remotePatterns |
| ERR-018 | SCSS path resolution (Windows + Turbopack) | `next build --webpack` or configure `sassOptions.includePaths` |
| ERR-019 | `non-ecmascript placeable asset` (Turbopack) | `serverExternalPackages: ['@libsql/client', '@react-pdf/renderer', 'pino']` |
| ERR-020 | `Unable to acquire lock at .next/dev/lock` | `rm -rf .next && pnpm dev` |
| ERR-021 | Hydration mismatch | `useEffect` + `useState(false)` for browser-only, or `suppressHydrationWarning` |
| ERR-022 | SVG imports return undefined | Use `--webpack`, inline SVGs, or `<Image>` component |
| ERR-023 | npm link / symlinks broken (Turbopack) | Use `--webpack` or workspace features |
| ERR-024 | Pino `Cannot find module './transport-stream'` | `serverExternalPackages: ['pino', 'pino-pretty']` |
| ERR-025 | CSS module resolution failure | `pnpm install sass postcss @tailwindcss/postcss` + import in layout.tsx |
| ERR-026 | `Unknown route segment config "experimental_ppr"` | Replace with `cacheComponents: true` |
| ERR-027 | Codemod misses edge cases | Manual audit of params/searchParams/cookies/headers access |

## LOW

| ID | Error Message | Fix |
|----|--------------|-----|
| ERR-028 | Server Actions serialization | Return plain objects: `{ error: { message: e.message } }` |
| ERR-029 | "use cache" ignored in dynamic routes (prod) | Use `generateStaticParams()` or `'use cache: remote'` |
| ERR-030 | In-memory cache misses (serverless) | `'use cache: remote'` or custom `cacheHandler` |
| ERR-031 | React Compiler context provider violations | `useMemo(() => ({ user, logout }), [user, logout])` for provider values |
| ERR-032 | Env variables not available in client | Prefix with `NEXT_PUBLIC_` |
| ERR-033 | Dev server requires restart after config changes | Kill and restart after next.config.ts changes |
| ERR-034 | InvariantError intercepted routes (16.0.0) | Update to latest 16.x (fixed in PR #85319) |
| ERR-035 | Turbopack null constructor (16.0.3) | `pnpm build --webpack` |
| ERR-036 | VSCode debugger broken (16.0.7) | Use `console.log` or external debugger |
| ERR-037 | Sitemap build failure (16.0.1) | Track GitHub #85632 |

## CVE Summary

| CVE | CVSS | Type | Fixed In |
|-----|------|------|----------|
| CVE-2025-66478 | **10.0** | Remote Code Execution | 16.0.10, 15.5.7, 15.4.8 |
| CVE-2025-55182 | High | Denial of Service (RSC) | Check advisories |
| CVE-2025-55183 | Medium | Source Code Exposure (RSC) | Check advisories |
