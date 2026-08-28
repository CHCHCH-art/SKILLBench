---
title: Mongoose Data Access with Connection Injection
impact: MEDIUM-HIGH
impactDescription: Consistent data access and testability
tags: database, mongoose, data-access, dependency-injection
---

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
