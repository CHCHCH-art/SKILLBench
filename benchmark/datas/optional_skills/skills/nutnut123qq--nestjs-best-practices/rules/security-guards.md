---
title: Use Guards for Authentication and Rate Limiting
impact: HIGH
impactDescription: Secure and resilient APIs
tags: security, guards, throttler, jwt, totp
---

## Use Guards for Authentication and Rate Limiting

Protect routes and resolvers with guards: JWT for authentication, TOTP for second-factor when required, and Throttler for rate limiting. Configure ThrottlerModule with a persistent storage (e.g. Redis) when running multiple instances so limits are shared across nodes.

**Incorrect (no guards or in-memory throttling in production):**

```typescript
@Query(() => User)
user() {
  return this.userService.getCurrentUser()
}
// No auth; no rate limit
```

**Correct (guards and Throttler with Redis):**

```typescript
// Module: ThrottlerModule with Redis storage
ThrottlerModule.forRootAsync({
  imports: [
    IoRedisModule.register({ instanceKeys: [IoRedisInstanceKey.Throttler] }),
  ],
  inject: [createIoRedisKey(IoRedisInstanceKey.Throttler)],
  useFactory: (redis: RedisOrCluster) => ({
    storage: new ThrottlerStorageRedisService(redis),
    throttlers: [],
  }),
})

// Resolver or controller
@UseGuards(JwtAuthGuard, ThrottlerGuard)
@Query(() => User)
user(@CurrentUser() user: UserJwtLike) {
  return this.userService.user(user)
}

// When 2FA is required
@UseGuards(JwtAuthGuard, TotpGuard)
@Mutation(() => SensitiveResult)
sensitiveOperation() { ... }
```

- Apply JWT guard globally or on protected controllers/resolvers; use TOTP guard only where second-factor is required.
- Use a dedicated Throttler guard (e.g. behind proxy) and configure Redis so rate limits are consistent in multi-instance deployments.
