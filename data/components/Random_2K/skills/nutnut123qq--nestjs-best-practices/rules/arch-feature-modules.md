---
title: Organize by Feature Modules
impact: CRITICAL
impactDescription: Faster onboarding and feature development
tags: architecture, modules, organization, feature-modules
---

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
