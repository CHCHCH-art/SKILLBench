# NestJS Best Practices

**Version 1.0.0**
NestJS Best Practices
2025

> **Note:**
> This document is mainly for agents and LLMs when maintaining, generating, or refactoring NestJS codebases. Guidance is optimized for automation and consistency.

---

## Abstract

Conventions for NestJS applications using configurable dynamic modules, custom domain exceptions, Mongoose data access, and feature-based module organization. Designed for AI agents and LLMs when maintaining or refactoring NestJS codebases.

---

## Table of Contents

1. [Architecture](#1-architecture) — **CRITICAL**
   - 1.1 [Use Dynamic Configurable Modules](#11-use-dynamic-configurable-modules)
   - 1.2 [Organize by Feature Modules](#12-organize-by-feature-modules)
2. [Error Handling](#2-error-handling) — **HIGH**
   - 2.1 [Use Custom Domain Exceptions](#21-use-custom-domain-exceptions)
3. [Database & ORM](#3-database-orm) — **MEDIUM-HIGH**
   - 3.1 [Mongoose Data Access with Connection Injection](#31-mongoose-data-access-with-connection-injection)
4. [Dependency Injection](#4-dependency-injection) — **CRITICAL**
   - 4.1 [Prefer Constructor Injection](#41-prefer-constructor-injection)
5. [API Design](#5-api-design) — **MEDIUM**
   - 5.1 [Validate Input with DTOs and class-validator](#51-validate-input-with-dtos-and-class-validator)
6. [Security](#6-security) — **HIGH**
   - 6.1 [Use Guards for Authentication and Rate Limiting](#61-use-guards-for-authentication-and-rate-limiting)

---

## 1. Architecture

**Section Impact: CRITICAL**

### 1.1 Use Dynamic Configurable Modules

**Impact: CRITICAL** — Consistent, testable module configuration

## Use Dynamic Configurable Modules

Use NestJS `ConfigurableModuleBuilder` for reusable modules that accept options. Define options and the configurable class in a `*-module-definition.ts` file; implement the module class that extends `ConfigurableModuleClass` and overrides `static register()` to return a `DynamicModule` with merged `imports`.

**Incorrect (static module with no options):**

```typescript
// my.module.ts
@Module({
  imports: [SomeOtherModule],
  providers: [MyService],
})
export class MyModule {}
// No way to pass options or conditionally load submodules
```

**Correct (configurable dynamic module):**

```typescript
// my.module-definition.ts
import { ConfigurableModuleBuilder } from "@nestjs/common"

export interface MyModuleOptions {
  isGlobal?: boolean
  configOnly?: boolean
}

export const { ConfigurableModuleClass, MODULE_OPTIONS_TOKEN, OPTIONS_TYPE } =
  new ConfigurableModuleBuilder<MyModuleOptions>()
    .setExtras({ isGlobal: false }, (definition, extras) => ({
      ...definition,
      global: extras.isGlobal,
    }))
    .build()

// my.module.ts
import { DynamicModule, Module } from "@nestjs/common"
import { ConfigurableModuleClass, OPTIONS_TYPE } from "./my.module-definition"
import { SubModule } from "./sub"

@Module({})
export class MyModule extends ConfigurableModuleClass {
  static register(options: typeof OPTIONS_TYPE): DynamicModule {
    const dynamicModule = super.register(options)
    const modules: DynamicModule[] = []
    if (!options?.configOnly) {
      modules.push(SubModule.register({ isGlobal: true }))
    }
    return {
      ...dynamicModule,
      imports: [...modules],
    }
  }
}
```

- Keep option types in the definition file; export `OPTIONS_TYPE` for use in `register()`.
- Use `super.register(options)` and spread the result, then add or override `imports` as needed.

---

### 1.2 Organize by Feature Modules

**Impact: CRITICAL** — Faster onboarding and feature development

## Organize by Feature Modules

Organize the application under `src/modules/` by feature (e.g. `api`, `blockchains`, `cache`, `executor`, `interface`). Each feature folder contains its own `*.module.ts`, `*.module-definition.ts` when configurable, services, and an `index.ts` that re-exports the public API. Avoid organizing by technical layer (all controllers in one folder, all services in another).

**Incorrect (technical layer organization):**

```
src/
  controllers/
    users.controller.ts
    orders.controller.ts
  services/
    users.service.ts
    orders.service.ts
  app.module.ts  // imports everything directly
```

**Correct (feature module organization):**

```
src/
  modules/
    users/
      users.module.ts
      users.module-definition.ts
      users.service.ts
      index.ts
    orders/
      orders.module.ts
      orders.service.ts
      index.ts
    cache/
      cache.module.ts
      cache.module-definition.ts
      cache.service.ts
      index.ts
```

- Each feature is self-contained: module, optional module-definition, services, DTOs, and an `index.ts` that exports what other modules need.
- Use path aliases (e.g. `@modules/cache`) to import from feature modules.
- The root app or parent modules import feature modules and re-export only what is necessary.

---

## 2. Error Handling

**Section Impact: HIGH**

### 2.1 Use Custom Domain Exceptions

**Impact: HIGH** — Consistent error handling and client-friendly codes

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

---

## 3. Database & ORM

**Section Impact: MEDIUM-HIGH**

### 3.1 Mongoose Data Access with Connection Injection

**Impact: MEDIUM-HIGH** — Consistent data access and testability

## Mongoose Data Access with Connection Injection

Inject the Mongoose `Connection` via a custom decorator (e.g. `@InjectPrimaryMongoose()`) in services. Use `this.connection.model(Schema.name)` for queries. Keep schemas and models in a shared databases module (e.g. `@modules/databases`); do not create new connections inside services.

**Incorrect (creating connection or using global mongoose):**

```typescript
import mongoose from "mongoose"
const model = mongoose.model("User", userSchema)
```

**Correct (inject Connection and use Schema name):**

```typescript
import { Injectable } from "@nestjs/common"
import { InjectPrimaryMongoose, UserSchema } from "@modules/databases"
import { Connection } from "mongoose"

@Injectable()
export class UserService {
  constructor(
    @InjectPrimaryMongoose()
    private readonly connection: Connection,
  ) {}

  async user(id: string) {
    const user = await this.connection
      .model<UserSchema>(UserSchema.name)
      .findById(id)
    if (!user) throw new UserNotFoundException({ id })
    return user.toJSON()
  }
}
```

- Schemas are defined once (e.g. in `databases/mongodb/primary/schemas/`) and exported; the same `Schema.name` is used for `connection.model()`.
- For multiple connections, use distinct decorators (e.g. `@InjectPrimaryMongoose()`, `@InjectSecondaryMongoose()`) and corresponding providers.

---

## 4. Dependency Injection

**Section Impact: CRITICAL**

### 4.1 Prefer Constructor Injection

**Impact: CRITICAL** — Testable and explicit dependencies

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

---

## 5. API Design

**Section Impact: MEDIUM**

### 5.1 Validate Input with DTOs and class-validator

**Impact: HIGH** — Safe and consistent API input

## Validate Input with DTOs and class-validator

Define DTOs for all incoming request bodies or GraphQL inputs and validate them with `class-validator` decorators. Use `@IsEmail()`, `@IsString()`, `@IsOptional()`, `@IsNumber()`, `@IsArray()`, `@ValidateNested()`, etc., so that invalid input is rejected before reaching business logic.

**Incorrect (no validation or ad-hoc checks):**

```typescript
@InputType()
export class CreateUserInput {
  @Field() email: string
  @Field() name: string
}
// No validation; invalid email or empty name can reach the resolver
```

**Correct (class-validator on DTO):**

```typescript
import { Field, InputType } from "@nestjs/graphql"
import { IsEmail, IsString, MinLength } from "class-validator"

@InputType()
export class RequestSignInOtpRequest {
  @IsEmail()
  @Field(() => String, { description: "The email of the user." })
  email: string
}

@InputType()
export class CreateUserInput {
  @IsEmail()
  @Field(() => String)
  email: string

  @IsString()
  @MinLength(1)
  @Field(() => String)
  name: string
}
```

- Enable ValidationPipe globally or on the routes that receive these DTOs so that validation runs automatically.
- Keep DTOs next to the resolver or controller that uses them, or in a shared `dto/` folder within the feature module.

---

## 6. Security

**Section Impact: HIGH**

### 6.1 Use Guards for Authentication and Rate Limiting

**Impact: HIGH** — Secure and resilient APIs

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

---

## References

- NestJS Dynamic Modules: https://docs.nestjs.com/fundamentals/dynamic-modules
- NestJS Custom Decorators: https://docs.nestjs.com/custom-decorators
- class-validator: https://github.com/typestack/class-validator

---

*Generated by build-agents.ts on 2026-02-05*
