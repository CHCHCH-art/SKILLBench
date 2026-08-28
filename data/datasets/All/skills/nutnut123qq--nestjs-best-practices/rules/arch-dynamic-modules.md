---
title: Use Dynamic Configurable Modules
impact: CRITICAL
impactDescription: Consistent, testable module configuration
tags: architecture, modules, dynamic-modules, ConfigurableModuleBuilder
---

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
