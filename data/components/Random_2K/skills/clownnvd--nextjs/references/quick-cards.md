# Quick Reference Cards — Next.js 16

## Card A: Where to Fetch Data

| Scenario | Pattern |
|----------|---------|
| Static page content | Server Component + `'use cache'` |
| Dynamic per-request data | Server Component in `<Suspense>` |
| User-interactive data | Client Component + SWR/React Query |
| Stream data to client | Promise prop + `use()` in Client Component |

## Card B: How to Cache

| What | How |
|------|-----|
| `fetch` request | `{ cache: 'force-cache' }` or `{ next: { revalidate: N } }` |
| DB/ORM query | `'use cache'` + `cacheTag(tag)` |
| Non-fetch function | `React.cache()` (per-request dedup only) |
| Entire page | `'use cache'` + `cacheLife('max')` at page level |

## Card C: How to Invalidate

| When | How |
|------|-----|
| After mutation (immediate) | `updateTag(tag)` in Server Action |
| After mutation (background) | `revalidateTag(tag, 'max')` |
| Entire route | `revalidatePath('/path')` |
| Re-render without cache change | `refresh()` |

## Card D: cacheLife Profiles

| Profile | Usage |
|---------|-------|
| `'hours'` | Short-lived cache |
| `'days'` | Medium cache |
| `'weeks'` | Long cache |
| `'max'` | Maximum cache duration |
| `{ stale, revalidate, expire }` | Custom (seconds) |

## Card E: Error Handling

| Error Type | Pattern |
|------------|---------|
| Validation failure | Return error state from Server Action + `useActionState` |
| API failure | Return error message, render in UI |
| 404 | `notFound()` + `not-found.tsx` |
| Unexpected crash | `error.tsx` boundary |
| Root layout crash | `global-error.tsx` (must define own `<html>` + `<body>`) |
| Event handler error | `try/catch` + `useState` (error boundaries don't catch these) |

## Card F: Server vs Client

| Need | Component Type |
|------|---------------|
| Fetch data (DB, API, secrets) | Server |
| Reduce client JS bundle | Server |
| State, event handlers | Client (`'use client'`) |
| Lifecycle effects (`useEffect`) | Client |
| Browser APIs (`localStorage`, `window`) | Client |
| Custom hooks with state/effects | Client |

## Card G: Proxy Patterns

```ts
export function proxy(request: NextRequest) {
  const token = request.cookies.get('session')?.value
  if (!token && request.nextUrl.pathname.startsWith('/dashboard'))
    return NextResponse.redirect(new URL('/login', request.url))
  return NextResponse.next()
}
export const config = {
  matcher: ['/dashboard/:path*', '/cv/:path*', '/billing/:path*'],
}
```

## Card H: Form Patterns

| Task | How |
|------|-----|
| Basic form | `<form action={serverAction}>` |
| Get form data | `formData.get('field')` or `Object.fromEntries(formData)` |
| Extra args | `action.bind(null, arg)` |
| Server validation | `z.object({}).safeParse()` |
| Show errors | `useActionState(action, initialState)` → `[state, formAction, pending]` |
| Pending state | `useFormStatus()` in child component |
| Optimistic UI | `useOptimistic(data, updaterFn)` |
| Keyboard submit | `form.requestSubmit()` on keydown |
| Multiple actions | `formAction` prop on `<button>` |

## Card I: Environment Variables

| Prefix | Available On | Example |
|--------|-------------|---------|
| None | Server only | `DATABASE_URL`, `ANTHROPIC_API_KEY` |
| `NEXT_PUBLIC_` | Client + Server | `NEXT_PUBLIC_APP_URL` |

## Card J: File Conventions

| File | Purpose |
|------|---------|
| `proxy.ts` | Request interception (replaces middleware.ts) |
| `layout.tsx` | Shared UI wrapper |
| `page.tsx` | Route page |
| `loading.tsx` | Route-level Suspense fallback |
| `error.tsx` | Route-level error boundary (`'use client'`) |
| `not-found.tsx` | 404 page |
| `global-error.tsx` | Root error boundary (must define `<html>` + `<body>`) |
| `next.config.ts` | Configuration |

## Card K: DO's and DON'Ts

| DO | DON'T |
|----|-------|
| Server Components by default | `'use client'` on layouts/pages |
| Push `'use client'` as deep as possible | Call Route Handlers from Server Components |
| Validate ALL Server Action inputs | Rely on proxy alone for auth |
| Check auth in EVERY Server Action | Check auth in layouts |
| `await` params, searchParams, cookies, headers | Access them synchronously |
| Use `proxy.ts` (not `middleware.ts`) | Expect `fetch` to be cached by default |
| Call revalidate BEFORE redirect | Use `unstable_cache` (deprecated) |
| `React.cache()` for DB dedup | Route segment configs with cacheComponents |
| `import 'server-only'` on sensitive modules | Pass non-serializable props to Client Components |
| `<Link>` for navigation | Heavy data fetching in proxy |
