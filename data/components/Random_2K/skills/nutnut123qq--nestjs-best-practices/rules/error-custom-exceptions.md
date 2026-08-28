---
title: Use Custom Domain Exceptions
impact: HIGH
impactDescription: Consistent error handling and client-friendly codes
tags: error-handling, exceptions, domain-errors
---

## Use Custom Domain Exceptions

Define a base `AbstractException` extending `Error` with `code` and `metadata`. Create domain-specific exception classes (e.g. `UserNotFoundException`, `BotNotFoundException`) that extend it and accept metadata interfaces. Throw these from services so that exception filters can map them to HTTP responses consistently.

**Incorrect (throwing plain Error or string):**

```typescript
async getUser(id: string) {
  const user = await this.repo.findById(id)
  if (!user) throw new Error("User not found")
  return user
}
```

**Correct (custom exception with code and metadata):**

```typescript
// abstract.ts
export abstract class AbstractException extends Error {
  readonly code: string
  readonly metadata?: Record<string, unknown>

  constructor(message: string, name: string, metadata?: Record<string, unknown>) {
    super(message)
    this.code = name
    this.name = name
    this.metadata = metadata
  }

  toJSON(): string {
    return JSON.stringify({ message: this.message, code: this.code, metadata: this.metadata })
  }
}

export interface AbstractExceptionMetadata {
  originalError?: Error
}

// users/user.ts
export interface UserNotFoundExceptionMetadata extends AbstractExceptionMetadata {
  id?: string
  privyUserId?: string
}

export class UserNotFoundException extends AbstractException {
  constructor({ id, privyUserId, originalError }: UserNotFoundExceptionMetadata) {
    super("User not found", "USER_NOT_FOUND_EXCEPTION", { id, privyUserId, originalError })
  }
}

// In service
if (!user) throw new UserNotFoundException({ id })
```

- Group exception classes by domain (users, bot, transactions, etc.) and export from a central exceptions module.
- Use an exception filter to catch `AbstractException` (or subclasses) and return appropriate HTTP status and body.
