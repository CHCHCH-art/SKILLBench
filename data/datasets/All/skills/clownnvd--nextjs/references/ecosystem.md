# Ecosystem Compatibility — Next.js 16

> Tested on Next.js 16.1.6 (CViet project)

## Compatibility Matrix

| Package | Status | Config Required |
|---------|--------|----------------|
| Prisma 7 | Works | Fake DB URL for CI builds |
| Better Auth | Works | Extract cookies outside cache scopes |
| @polar-sh/nextjs | Works | `payload: any` type workaround |
| @react-pdf/renderer | Works | `serverExternalPackages`, `ssr: false` |
| Anthropic SDK | Works | Serialize errors before client |
| Tailwind CSS v4 | Works | `cross-env NODE_ENV=development` |
| Zod | Works | No issues |
| lucide-react | Works | No issues |
| TanStack Query v5 | Works | No issues |

## Prisma + Neon PostgreSQL

| Issue | Fix |
|-------|-----|
| Edge/Serverless TCP failure | Use pooled connection string. proxy.ts = Node.js runtime |
| `Prisma.JsonValue` not castable | Double-cast: `cv.data as unknown as CVData` |
| Build without DB | `DATABASE_URL="postgresql://fake:fake@localhost/fake"` |
| Client not generated | `pnpm db:generate` / `prisma generate` |

## Better Auth

| Issue | Fix |
|-------|-----|
| `getServerSession()` + `'use cache'` | Extract cookies outside: `(await cookies()).toString()` → pass as arg |
| Custom model names | Ensure Prisma models match Better Auth conventions |
| Cookie in proxy | `getSessionCookie(request)` works unchanged |
| middleware → proxy | Rename function to `proxy()` in `src/proxy.ts` |

## Polar SDK

| Issue | Fix |
|-------|-----|
| Type mismatch `@polar-sh/sdk@0.29` vs `@polar-sh/nextjs` | Use `payload: any` in webhook handlers |
| Webhook routes | Unaffected by proxy.ts change |

## @react-pdf/renderer

| Issue | Fix |
|-------|-----|
| `require() of ES Module not supported` | `serverExternalPackages: ["@react-pdf/renderer"]` |
| `PDFViewer is a web specific API` | `dynamic(() => import(...), { ssr: false })` |
| `renderToBuffer()` type mismatch (React 19) | `component: any` workaround |
| Buffer not assignable to BodyInit | `new Uint8Array(buffer)` |

## Anthropic SDK

| Issue | Fix |
|-------|-----|
| Error objects crossing RSC boundary | Catch + return `{ error: e.message }` |
| Streaming responses | Works in Route Handlers, no special handling |

## Tailwind CSS v4

| Issue | Fix |
|-------|-----|
| VSCode NODE_ENV=production breaks CSS | `cross-env NODE_ENV=development next dev --webpack` |
| PostCSS config format | Use `postcss.config.mjs` only, remove duplicate `.js` |
| `@import` order | Google Fonts `@import url()` BEFORE `@import "tailwindcss"` |
