# Best Practices — Next.js 16

## Server & Client Components

- Server Components by default. `'use client'` only on interactive leaf components.
- Push `'use client'` as deep as possible — not on layouts/pages.
- Interleaving: pass Server Components as `children` to Client Components.
- Props must be serializable (no functions, class instances) across the boundary.
- Wrap third-party components lacking `'use client'` in own Client Component wrapper.
- Use `import 'server-only'` / `import 'client-only'` to enforce boundaries.

## Data Fetching

- Fetch in Server Components (primary pattern).
- NEVER call Route Handlers from Server Components.
- Use `Promise.all()` for parallel fetching (avoid waterfalls).
- `<Suspense>` for granular streaming; `loading.tsx` for route-level.
- `fetch` is NOT cached by default — use `{ cache: 'force-cache' }` explicitly.
- `React.cache()` for per-request deduplication of DB/ORM calls.

```tsx
import { cache } from 'react'
export const getPost = cache(async (id: string) => {
  return db.query.posts.findFirst({ where: eq(posts.id, parseInt(id)) })
})
```

## Caching & Revalidation

- `'use cache'` + `cacheTag()` for DB/ORM queries.
- `updateTag()` in Server Actions for immediate invalidation.
- `revalidateTag(tag, 'max')` for background stale-while-revalidate.
- Call `revalidatePath`/`revalidateTag` BEFORE `redirect()` — redirect throws internally.

```tsx
'use server'
export async function createPost(formData: FormData) {
  await db.post.create({ data: { title: formData.get('title') } })
  revalidatePath('/posts')   // BEFORE redirect
  redirect('/posts')          // Throws — code after won't execute
}
```

## Proxy (formerly Middleware)

- Use `proxy.ts` (not `middleware.ts`). Export `function proxy()`.
- Use for: optimistic auth redirects, header modification, rewrites, A/B testing.
- Do NOT use as sole auth check. Always verify auth close to data source.
- Do NOT do heavy data fetching in proxy.

```ts
// src/proxy.ts
export function proxy(request: NextRequest) {
  const token = request.cookies.get('session')?.value
  if (!token && request.nextUrl.pathname.startsWith('/dashboard'))
    return NextResponse.redirect(new URL('/login', request.url))
  return NextResponse.next()
}
export const config = { matcher: ['/dashboard/:path*', '/cv/:path*'] }
```

## Forms & Server Actions

- Validate ALL inputs with Zod. Check auth in EVERY action.
- Return errors as values (don't throw).
- `useActionState` for error display + pending state.
- `useFormStatus` in **child** of `<form>` (not the form itself).

## Authentication

| Location | What to Do |
|----------|-----------|
| Proxy | Optimistic redirect only (read cookie) |
| Server Component | `verifySession()` via DAL |
| Server Action | `verifySession()` — ALWAYS |
| Route Handler | `verifySession()` — ALWAYS |
| Layout | DO NOT check auth here |

## Async Request APIs (v16)

```tsx
// Server Component
const { slug } = await params
const { q } = await searchParams
const cookieStore = await cookies()

// Client Component
const resolvedParams = use(params)

// Route Handler
export async function GET(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
}

// generateMetadata
export async function generateMetadata(props: { params: Promise<{ id: string }> }) {
  const params = await props.params
}
```

## Performance

- `next/font` for self-hosted fonts. `<Image>` for optimization. `<Link>` for navigation.
- Run `next build` + `next start` before deploying.
- `@next/bundle-analyzer` for large module identification.
