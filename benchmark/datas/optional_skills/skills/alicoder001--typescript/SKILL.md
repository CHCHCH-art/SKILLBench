---
name: typescript
description: TypeScript strict mode patterns, naming conventions, and type safety rules. Use when writing TypeScript code, defining types, or reviewing TypeScript projects. Includes generics, utility types, and best practices.
---

# TypeScript Professional

> Strict TypeScript patterns for professional development.

## Instructions

### 1. Strict Mode Configuration

Always enable strict mode in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

### 2. Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Interface | PascalCase, prefix with I (optional) | `User`, `IUserService` |
| Type | PascalCase | `UserRole`, `ApiResponse` |
| Enum | PascalCase | `Status`, `Direction` |
| Function | camelCase | `getUserById`, `calculateTotal` |
| Variable | camelCase | `userName`, `isLoading` |
| Constant | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `API_URL` |

### 3. Type vs Interface

```typescript
// ✅ Interface for object shapes
interface User {
  id: string;
  name: string;
  email: string;
}

// ✅ Type for unions, intersections, primitives
type Status = 'pending' | 'active' | 'inactive';
type ApiResponse<T> = { data: T; error: null } | { data: null; error: string };
```

### 4. Never Use `any`

```typescript
// ❌ Bad
function process(data: any) { ... }

// ✅ Good - use unknown and narrow
function process(data: unknown) {
  if (typeof data === 'string') {
    return data.toUpperCase();
  }
}

// ✅ Good - use generics
function process<T>(data: T): T { ... }
```

### 5. Utility Types

```typescript
// Partial - all optional
type PartialUser = Partial<User>;

// Required - all required
type RequiredUser = Required<User>;

// Pick - select specific
type UserName = Pick<User, 'name'>;

// Omit - exclude specific
type UserWithoutId = Omit<User, 'id'>;

// Record - key-value mapping
type UserMap = Record<string, User>;
```

### 6. Function Types

```typescript
// ✅ Explicit return types for public APIs
function getUser(id: string): Promise<User | null> {
  // ...
}

// ✅ Arrow function with types
const add = (a: number, b: number): number => a + b;
```

### 7. Generics

```typescript
// ✅ Constrained generics
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

// ✅ Default generic types
interface ApiResponse<T = unknown> {
  data: T;
  status: number;
}
```

## References

- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/)
- [TypeScript Deep Dive](https://basarat.gitbook.io/typescript/)
