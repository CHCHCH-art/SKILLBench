---
title: Prefer Constructor Injection
impact: CRITICAL
impactDescription: Testable and explicit dependencies
tags: dependency-injection, constructor-injection, NestJS
---

## Prefer Constructor Injection

Use `@Injectable()` on all services and inject dependencies via the constructor with `private readonly`. Avoid property injection or service locators. Use custom parameter decorators (e.g. for Mongoose Connection, cache, or options) when needed.

**Incorrect (property injection or no DI):**

```typescript
@Injectable()
export class MyService {
  private other: OtherService
  constructor() {
    this.other = new OtherService()
  }
}
```

**Correct (constructor injection with readonly):**

```typescript
import { Injectable } from "@nestjs/common"
import { OtherService } from "./other.service"
import { InjectRedisCache } from "./cache.decorators"
import { Cache } from "cache-manager"

@Injectable()
export class MyService {
  constructor(
    private readonly otherService: OtherService,
    @InjectRedisCache()
    private readonly redisCache: Cache,
  ) {}
}
```

- All injectable dependencies should be in the constructor; use `private readonly` so they are not reassigned.
- For optional or configurable dependencies, use `@Optional()` or inject options via a dedicated token (e.g. `MODULE_OPTIONS_TOKEN` from ConfigurableModuleBuilder).
