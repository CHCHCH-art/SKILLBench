---
title: Validate Input with DTOs and class-validator
impact: HIGH
impactDescription: Safe and consistent API input
tags: api, validation, dto, class-validator
---

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
