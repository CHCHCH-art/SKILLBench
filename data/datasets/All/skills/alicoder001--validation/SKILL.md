---
name: validation
description: Zod schema validation patterns for TypeScript applications. Use when validating API responses, form data, environment variables, or any runtime data. Type-safe validation with automatic TypeScript inference.
---

# Zod Validation Patterns

> Type-safe schema validation with automatic TypeScript inference.

## Instructions

### 1. Basic Schemas

```typescript
import { z } from 'zod';

// Primitives
const nameSchema = z.string().min(2).max(50);
const ageSchema = z.number().int().positive();
const emailSchema = z.string().email();
const urlSchema = z.string().url();

// Objects
const userSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(2),
  email: z.string().email(),
  age: z.number().int().min(18).optional(),
  role: z.enum(['admin', 'user', 'guest']),
  createdAt: z.coerce.date(),
});

// Infer TypeScript type
type User = z.infer<typeof userSchema>;

// Usage
const result = userSchema.safeParse(data);
if (result.success) {
  const user: User = result.data;
} else {
  console.error(result.error.format());
}
```

### 2. Complex Schemas

```typescript
// Arrays
const tagsSchema = z.array(z.string()).min(1).max(10);

// Unions
const statusSchema = z.union([
  z.literal('pending'),
  z.literal('active'),
  z.literal('completed'),
]);

// Discriminated unions
const notificationSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('email'), email: z.string().email() }),
  z.object({ type: z.literal('sms'), phone: z.string() }),
  z.object({ type: z.literal('push'), deviceId: z.string() }),
]);

// Recursive (e.g., comments with replies)
const commentSchema: z.ZodType<Comment> = z.lazy(() =>
  z.object({
    id: z.string(),
    text: z.string(),
    replies: z.array(commentSchema),
  })
);
```

### 3. Transformations

```typescript
// Transform to different type
const dateStringSchema = z.string().transform((str) => new Date(str));

// Coerce types
const numberFromString = z.coerce.number(); // "123" → 123
const dateFromString = z.coerce.date();     // "2024-01-01" → Date

// Preprocess
const trimmedString = z.preprocess(
  (val) => (typeof val === 'string' ? val.trim() : val),
  z.string()
);

// Default values
const configSchema = z.object({
  port: z.number().default(3000),
  host: z.string().default('localhost'),
  debug: z.boolean().default(false),
});
```

### 4. API Response Validation

```typescript
// Define response schema
const apiResponseSchema = z.object({
  success: z.boolean(),
  data: z.object({
    users: z.array(userSchema),
    total: z.number(),
    page: z.number(),
  }),
});

// Validate API response
async function fetchUsers(): Promise<User[]> {
  const response = await fetch('/api/users');
  const json = await response.json();
  
  const result = apiResponseSchema.safeParse(json);
  if (!result.success) {
    throw new Error(`Invalid API response: ${result.error.message}`);
  }
  
  return result.data.data.users;
}
```

### 5. Form Validation (React Hook Form)

```typescript
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';

const loginSchema = z.object({
  email: z.string()
    .email('Invalid email')
    .min(1, 'Email is required'),
  password: z.string()
    .min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Must contain uppercase')
    .regex(/[0-9]/, 'Must contain number'),
  rememberMe: z.boolean().optional(),
});

type LoginForm = z.infer<typeof loginSchema>;

function LoginForm() {
  const form = useForm<LoginForm>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: '', password: '', rememberMe: false },
  });
  
  const onSubmit = (data: LoginForm) => {
    // data is fully typed and validated
  };
}
```

### 6. Environment Variables

```typescript
// env.ts
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']),
  DATABASE_URL: z.string().url(),
  API_KEY: z.string().min(32),
  PORT: z.coerce.number().default(3000),
  DEBUG: z.coerce.boolean().default(false),
});

// Parse with error handling
function getEnv() {
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    console.error('❌ Invalid environment variables:');
    console.error(result.error.format());
    process.exit(1);
  }
  return result.data;
}

export const env = getEnv();

// Usage
console.log(env.DATABASE_URL); // Fully typed!
```

### 7. Custom Error Messages

```typescript
const userSchema = z.object({
  username: z.string({
    required_error: 'Username is required',
    invalid_type_error: 'Username must be a string',
  })
    .min(3, { message: 'Username must be at least 3 characters' })
    .max(20, { message: 'Username must be at most 20 characters' })
    .regex(/^[a-z0-9_]+$/, { message: 'Only lowercase letters, numbers, and underscores' }),
    
  email: z.string()
    .email({ message: 'Please enter a valid email address' }),
    
  age: z.number()
    .min(18, { message: 'You must be at least 18 years old' }),
});

// Get formatted errors
const result = userSchema.safeParse(data);
if (!result.success) {
  const formatted = result.error.format();
  // formatted.username?._errors
  // formatted.email?._errors
}
```

### 8. Reusable Schemas

```typescript
// lib/schemas/common.ts
export const idSchema = z.string().uuid();
export const emailSchema = z.string().email().toLowerCase();
export const phoneSchema = z.string().regex(/^\+?[1-9]\d{9,14}$/);
export const urlSchema = z.string().url();
export const slugSchema = z.string().regex(/^[a-z0-9-]+$/);

// Pagination
export const paginationSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

// lib/schemas/user.ts
export const createUserSchema = z.object({
  name: z.string().min(2).max(100),
  email: emailSchema,
  password: z.string().min(8),
});

export const updateUserSchema = createUserSchema.partial();
```

### 9. Extend and Merge

```typescript
// Base schema
const baseUserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
});

// Extend
const fullUserSchema = baseUserSchema.extend({
  name: z.string(),
  role: z.enum(['admin', 'user']),
});

// Merge
const addressSchema = z.object({
  street: z.string(),
  city: z.string(),
});

const userWithAddressSchema = fullUserSchema.merge(addressSchema);

// Pick / Omit
const publicUserSchema = fullUserSchema.pick({ id: true, name: true });
const createUserSchema = fullUserSchema.omit({ id: true });
```

## Best Practices

| Do | Don't |
|----|-------|
| ✅ Use `safeParse()` | ❌ Use `parse()` without try/catch |
| ✅ Define schemas in separate files | ❌ Inline schemas everywhere |
| ✅ Use `z.infer<>` for types | ❌ Manually define duplicate types |
| ✅ Add custom error messages | ❌ Use default cryptic errors |

## References

- [Zod Documentation](https://zod.dev/)
- [React Hook Form + Zod](https://react-hook-form.com/get-started#SchemaValidation)
