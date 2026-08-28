# Complete Data Access Layer Implementation Example

This document provides a complete, working example of the Data Access Layer pattern for Next.js 16 authentication security.

## Project Structure

```tree
app/
├── lib/
│   ├── dal.ts
│   ├── session.ts
│   └── db.ts
├── dashboard/
│   ├── layout.tsx
│   └── page.tsx
├── api/
│   └── posts/
│       └── route.ts
└── actions/
    └── profile.ts
```

## Core DAL Implementation

### lib/dal.ts

```typescript
import 'server-only';
import { cookies } from 'next/headers';
import { decrypt } from '@/lib/session';
import { cache } from 'react';

export const verifySession = cache(async () => {
  const cookie = (await cookies()).get('session')?.value;
  const session = await decrypt(cookie);

  if (!session?.userId) {
    throw new Error('Unauthorized');
  }

  return { isAuth: true, userId: session.userId as string };
});

export async function getUser() {
  const session = await verifySession();

  const user = await db.query.users.findFirst({
    where: eq(users.id, session.userId),
  });

  if (!user) {
    throw new Error('User not found');
  }

  return user;
}

export async function getUserPosts() {
  const session = await verifySession();

  const posts = await db.query.posts.findMany({
    where: eq(posts.authorId, session.userId),
    orderBy: [desc(posts.createdAt)],
  });

  return posts;
}

export async function getPost(postId: string) {
  const session = await verifySession();

  const post = await db.query.posts.findFirst({
    where: eq(posts.id, postId),
  });

  if (!post) {
    throw new Error('Post not found');
  }

  if (post.authorId !== session.userId) {
    throw new Error('Forbidden');
  }

  return post;
}
```

### lib/session.ts

```typescript
import 'server-only';
import { SignJWT, jwtVerify } from 'jose';
import { cookies } from 'next/headers';

const secretKey = process.env.SESSION_SECRET;
const encodedKey = new TextEncoder().encode(secretKey);

export async function encrypt(payload: { userId: string; expiresAt: Date }) {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('7d')
    .sign(encodedKey);
}

export async function decrypt(session: string | undefined = '') {
  try {
    const { payload } = await jwtVerify(session, encodedKey, {
      algorithms: ['HS256'],
    });
    return payload;
  } catch (error) {
    return null;
  }
}

export async function createSession(userId: string) {
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  const session = await encrypt({ userId, expiresAt });

  const cookieStore = await cookies();
  cookieStore.set('session', session, {
    httpOnly: true,
    secure: true,
    expires: expiresAt,
    sameSite: 'lax',
    path: '/',
  });
}

export async function deleteSession() {
  const cookieStore = await cookies();
  cookieStore.delete('session');
}
```

### lib/db.ts

```typescript
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema';

const client = postgres(process.env.DATABASE_URL!);
export const db = drizzle(client, { schema });
```

## Layer 1: Route Protection (UX)

### dashboard/layout.tsx

```typescript
import { verifySession } from '@/lib/dal';
import { redirect } from 'next/navigation';

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await verifySession().catch(() => null);

  if (!session?.isAuth) {
    redirect('/login');
  }

  return (
    <div>
      <nav>Dashboard Navigation</nav>
      <main>{children}</main>
    </div>
  );
}
```

### dashboard/page.tsx

```typescript
import { getUser, getUserPosts } from '@/lib/dal';

export default async function DashboardPage() {
  const user = await getUser();
  const posts = await getUserPosts();

  return (
    <div>
      <h1>Welcome, {user.name}</h1>
      <div>
        <h2>Your Posts</h2>
        {posts.map((post) => (
          <article key={post.id}>
            <h3>{post.title}</h3>
            <p>{post.content}</p>
          </article>
        ))}
      </div>
    </div>
  );
}
```

## Layer 2: Data Access Layer (Security)

### Advanced DAL Patterns

```typescript
import 'server-only';
import { cache } from 'react';
import { verifySession } from './dal';
import { db } from './db';

export const verifyAdmin = cache(async () => {
  const session = await verifySession();

  const user = await db.query.users.findFirst({
    where: eq(users.id, session.userId),
  });

  if (!user || user.role !== 'admin') {
    throw new Error('Forbidden: Admin access required');
  }

  return { userId: session.userId, role: user.role };
});

export async function getAllUsers() {
  await verifyAdmin();

  return db.query.users.findMany({
    orderBy: [desc(users.createdAt)],
  });
}

export async function getPostWithAuthor(postId: string) {
  const session = await verifySession();

  const post = await db.query.posts.findFirst({
    where: eq(posts.id, postId),
    with: {
      author: {
        columns: {
          id: true,
          name: true,
          username: true,
        },
      },
    },
  });

  if (!post) {
    throw new Error('Post not found');
  }

  if (post.authorId !== session.userId) {
    throw new Error('Forbidden');
  }

  return post;
}

export async function getPublicProfile(username: string) {
  const session = await verifySession().catch(() => null);

  const profile = await db.query.users.findFirst({
    where: eq(users.username, username),
    columns: {
      id: true,
      username: true,
      name: true,
      bio: true,
      email: session ? true : false,
    },
  });

  if (!profile) {
    throw new Error('Profile not found');
  }

  return profile;
}
```

## Layer 3: Server Actions (Mutations)

### actions/profile.ts

```typescript
'use server';

import { verifySession } from '@/lib/dal';
import { db } from '@/lib/db';
import { users } from '@/lib/schema';
import { eq } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { z } from 'zod';

const updateProfileSchema = z.object({
  name: z.string().min(1).max(100),
  bio: z.string().max(500).optional(),
});

export async function updateProfile(formData: FormData) {
  const session = await verifySession();

  const rawData = {
    name: formData.get('name'),
    bio: formData.get('bio'),
  };

  const validated = updateProfileSchema.parse(rawData);

  await db
    .update(users)
    .set({
      name: validated.name,
      bio: validated.bio,
      updatedAt: new Date(),
    })
    .where(eq(users.id, session.userId));

  revalidatePath('/profile');

  return { success: true };
}

export async function deleteAccount() {
  const session = await verifySession();

  await db.transaction(async (tx) => {
    await tx.delete(posts).where(eq(posts.authorId, session.userId));
    await tx.delete(users).where(eq(users.id, session.userId));
  });

  await deleteSession();

  return { success: true };
}
```

### actions/posts.ts

```typescript
'use server';

import { verifySession } from '@/lib/dal';
import { db } from '@/lib/db';
import { posts } from '@/lib/schema';
import { eq } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { z } from 'zod';

const createPostSchema = z.object({
  title: z.string().min(1).max(200),
  content: z.string().min(1).max(10000),
});

export async function createPost(formData: FormData) {
  const session = await verifySession();

  const rawData = {
    title: formData.get('title'),
    content: formData.get('content'),
  };

  const validated = createPostSchema.parse(rawData);

  const [post] = await db
    .insert(posts)
    .values({
      title: validated.title,
      content: validated.content,
      authorId: session.userId,
      createdAt: new Date(),
    })
    .returning();

  revalidatePath('/dashboard');

  return { success: true, postId: post.id };
}

export async function updatePost(postId: string, formData: FormData) {
  const session = await verifySession();

  const post = await db.query.posts.findFirst({
    where: eq(posts.id, postId),
  });

  if (!post) {
    throw new Error('Post not found');
  }

  if (post.authorId !== session.userId) {
    throw new Error('Forbidden');
  }

  const rawData = {
    title: formData.get('title'),
    content: formData.get('content'),
  };

  const validated = createPostSchema.parse(rawData);

  await db
    .update(posts)
    .set({
      title: validated.title,
      content: validated.content,
      updatedAt: new Date(),
    })
    .where(eq(posts.id, postId));

  revalidatePath('/dashboard');
  revalidatePath(`/posts/${postId}`);

  return { success: true };
}

export async function deletePost(postId: string) {
  const session = await verifySession();

  const post = await db.query.posts.findFirst({
    where: eq(posts.id, postId),
  });

  if (!post) {
    throw new Error('Post not found');
  }

  if (post.authorId !== session.userId) {
    throw new Error('Forbidden');
  }

  await db.delete(posts).where(eq(posts.id, postId));

  revalidatePath('/dashboard');

  return { success: true };
}
```

## API Routes

### api/posts/route.ts

```typescript
import { verifySession } from '@/lib/dal';
import { getUserPosts } from '@/lib/dal';
import { NextResponse } from 'next/server';

export async function GET() {
  try {
    const session = await verifySession();
    const posts = await getUserPosts();

    return NextResponse.json({ posts });
  } catch (error) {
    return NextResponse.json(
      { error: 'Unauthorized' },
      { status: 401 }
    );
  }
}
```

### api/posts/[id]/route.ts

```typescript
import { verifySession, getPost } from '@/lib/dal';
import { NextResponse } from 'next/server';

export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const session = await verifySession();
    const post = await getPost(params.id);

    return NextResponse.json({ post });
  } catch (error) {
    if (error.message === 'Unauthorized') {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    if (error.message === 'Forbidden') {
      return NextResponse.json(
        { error: 'Forbidden' },
        { status: 403 }
      );
    }

    return NextResponse.json(
      { error: 'Not found' },
      { status: 404 }
    );
  }
}
```

## Database Schema Example

### lib/schema.ts

```typescript
import { pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: uuid('id').defaultRandom().primaryKey(),
  email: text('email').notNull().unique(),
  password: text('password').notNull(),
  name: text('name').notNull(),
  username: text('username').notNull().unique(),
  bio: text('bio'),
  role: text('role').notNull().default('user'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at'),
});

export const posts = pgTable('posts', {
  id: uuid('id').defaultRandom().primaryKey(),
  title: text('title').notNull(),
  content: text('content').notNull(),
  authorId: uuid('author_id')
    .notNull()
    .references(() => users.id),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at'),
});
```

## Key Implementation Notes

1. **Every data access function calls `verifySession()` first**
2. **React `cache()` ensures single verification per request**
3. **'server-only' import prevents client-side leaks**
4. **Authorization happens in DAL, not in middleware**
5. **Server actions verify session independently**
6. **API routes use try/catch for proper error responses**
7. **Resource ownership is verified in DAL functions**
8. **Role-based access uses separate verification functions**

## Testing Checklist

- [ ] Try accessing protected routes without session cookie
- [ ] Try accessing other users' resources
- [ ] Verify admin routes reject non-admin users
- [ ] Test server actions without authentication
- [ ] Check API routes return 401 for unauthorized requests
- [ ] Verify cache() prevents multiple verification calls
- [ ] Ensure 'server-only' prevents client imports

This pattern provides defense-in-depth security that protects against CVE-2025-29927 and other authentication bypasses.
