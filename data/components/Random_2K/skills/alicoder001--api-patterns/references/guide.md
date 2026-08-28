# Legacy Detailed Guide

This file preserves the previous detailed version of `SKILL.md` for deep reference.


# API Integration Patterns

> REST, GraphQL, WebSocket, and tRPC best practices.

## Selection Guide

- REST: Standard CRUD APIs, caching, and broad tooling support.
- GraphQL: Flexible client-driven queries with complex data graphs.
- tRPC: End-to-end TypeScript in monorepos with shared types.
- WebSocket: Real-time, bi-directional updates and live data streams.

## Instructions

### 1. REST API Design

```typescript
// RESTful endpoints
GET    /api/users          // List users
GET    /api/users/:id      // Get user
POST   /api/users          // Create user
PUT    /api/users/:id      // Update user
PATCH  /api/users/:id      // Partial update
DELETE /api/users/:id      // Delete user

// Nested resources
GET    /api/users/:id/posts        // User's posts
POST   /api/users/:id/posts        // Create post for user

// Query parameters
GET    /api/users?page=1&limit=20&sort=createdAt:desc&filter[role]=admin
```

### 2. REST with Axios

```typescript
// lib/api.ts
import axios, { AxiosInstance, AxiosError } from 'axios';

const api: AxiosInstance = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor - add token
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor - handle errors
api.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// Typed API functions
export const userApi = {
  getAll: (params?: UserListParams) => 
    api.get<PaginatedResponse<User>>('/users', { params }),
    
  getById: (id: string) => 
    api.get<User>(`/users/${id}`),
    
  create: (data: CreateUserDto) => 
    api.post<User>('/users', data),
    
  update: (id: string, data: UpdateUserDto) => 
    api.patch<User>(`/users/${id}`, data),
    
  delete: (id: string) => 
    api.delete(`/users/${id}`),
};
```

### 3. REST with Fetch (Next.js)

```typescript
// lib/fetch.ts
async function fetchApi<T>(
  endpoint: string,
  options?: RequestInit
): Promise<T> {
  const url = `${process.env.NEXT_PUBLIC_API_URL}${endpoint}`;
  
  const response = await fetch(url, {
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
    ...options,
  });

  if (!response.ok) {
    throw new Error(`API Error: ${response.status}`);
  }

  return response.json();
}

// Server Component usage
async function UsersPage() {
  const users = await fetchApi<User[]>('/users', {
    next: { revalidate: 60 }, // ISR: revalidate every 60s
  });
  
  return <UserList users={users} />;
}
```

### 4. GraphQL with Apollo Client

```typescript
// lib/apollo.ts
import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';

const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_URL,
});

const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('token');
  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : '',
    },
  };
});

export const apolloClient = new ApolloClient({
  link: authLink.concat(httpLink),
  cache: new InMemoryCache(),
});
```

```typescript
// hooks/useUsers.ts
import { gql, useQuery, useMutation } from '@apollo/client';

const GET_USERS = gql`
  query GetUsers($page: Int, $limit: Int) {
    users(page: $page, limit: $limit) {
      id
      name
      email
      role
    }
  }
`;

const CREATE_USER = gql`
  mutation CreateUser($input: CreateUserInput!) {
    createUser(input: $input) {
      id
      name
      email
    }
  }
`;

export function useUsers(page = 1) {
  return useQuery(GET_USERS, {
    variables: { page, limit: 20 },
  });
}

export function useCreateUser() {
  return useMutation(CREATE_USER, {
    refetchQueries: [{ query: GET_USERS }],
  });
}
```

### 5. WebSocket (Socket.io)

```typescript
// lib/socket.ts
import { io, Socket } from 'socket.io-client';

let socket: Socket | null = null;

export function getSocket(): Socket {
  if (!socket) {
    socket = io(process.env.NEXT_PUBLIC_WS_URL!, {
      autoConnect: false,
      auth: {
        token: localStorage.getItem('token'),
      },
    });
  }
  return socket;
}

// hooks/useSocket.ts
export function useSocket() {
  const socket = useMemo(() => getSocket(), []);

  useEffect(() => {
    socket.connect();
    return () => { socket.disconnect(); };
  }, [socket]);

  return socket;
}

// Chat example
export function useChat(roomId: string) {
  const socket = useSocket();
  const [messages, setMessages] = useState<Message[]>([]);

  useEffect(() => {
    socket.emit('join-room', roomId);

    socket.on('message', (message: Message) => {
      setMessages((prev) => [...prev, message]);
    });

    return () => {
      socket.emit('leave-room', roomId);
      socket.off('message');
    };
  }, [socket, roomId]);

  const sendMessage = (text: string) => {
    socket.emit('send-message', { roomId, text });
  };

  return { messages, sendMessage };
}
```

### 6. tRPC (Type-Safe APIs)

```typescript
// server/trpc.ts
import { initTRPC, TRPCError } from '@trpc/server';
import { z } from 'zod';

const t = initTRPC.context<Context>().create();

export const router = t.router;
export const publicProcedure = t.procedure;
export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  if (!ctx.user) {
    throw new TRPCError({ code: 'UNAUTHORIZED' });
  }
  return next({ ctx: { ...ctx, user: ctx.user } });
});
```

```typescript
// server/routers/user.ts
export const userRouter = router({
  getAll: publicProcedure
    .input(z.object({
      page: z.number().default(1),
      limit: z.number().default(20),
    }))
    .query(async ({ input, ctx }) => {
      return ctx.db.user.findMany({
        skip: (input.page - 1) * input.limit,
        take: input.limit,
      });
    }),

  getById: publicProcedure
    .input(z.string().uuid())
    .query(async ({ input, ctx }) => {
      return ctx.db.user.findUnique({ where: { id: input } });
    }),

  create: protectedProcedure
    .input(createUserSchema)
    .mutation(async ({ input, ctx }) => {
      return ctx.db.user.create({ data: input });
    }),
});
```

```typescript
// Client usage - fully typed!
import { trpc } from '@/lib/trpc';

function UserList() {
  const { data, isLoading } = trpc.user.getAll.useQuery({ page: 1 });
  const createUser = trpc.user.create.useMutation();

  // data is typed as User[]
  // createUser has typed input/output
}
```

### 7. Real-Time with Server-Sent Events

```typescript
// Server (Next.js API route)
export async function GET(request: Request) {
  const stream = new ReadableStream({
    start(controller) {
      const encoder = new TextEncoder();
      
      const interval = setInterval(() => {
        const data = JSON.stringify({ time: new Date().toISOString() });
        controller.enqueue(encoder.encode(`data: ${data}\n\n`));
      }, 1000);

      request.signal.addEventListener('abort', () => {
        clearInterval(interval);
        controller.close();
      });
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
}

// Client
function useSSE<T>(url: string) {
  const [data, setData] = useState<T | null>(null);

  useEffect(() => {
    const eventSource = new EventSource(url);
    
    eventSource.onmessage = (event) => {
      setData(JSON.parse(event.data));
    };

    return () => eventSource.close();
  }, [url]);

  return data;
}
```

## Comparison

| Feature | REST | GraphQL | WebSocket | tRPC |
|---------|------|---------|-----------|------|
| Type Safety | Manual | Codegen | Manual | Built-in |
| Over-fetching | Yes | No | N/A | No |
| Real-time | No | Subscriptions | Yes | Yes |
| Caching | HTTP Cache | Apollo Cache | Manual | React Query |
| Learning Curve | Low | Medium | Medium | Low |

## References

- [REST API Design](https://restfulapi.net/)
- [Apollo GraphQL](https://www.apollographql.com/docs/)
- [Socket.io](https://socket.io/docs/)
- [tRPC](https://trpc.io/docs)



