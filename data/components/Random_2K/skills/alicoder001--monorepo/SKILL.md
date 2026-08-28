---
name: monorepo
description: Monorepo architecture patterns with Turborepo, pnpm workspaces, and shared packages. Use when setting up multi-package repositories, shared libraries, or micro-frontend architectures.
---

# Monorepo Architecture

> Use this skill to create predictable package boundaries, shared tooling, and fast incremental builds.

## Use This Skill When

- Multiple apps share code and release cadence.
- You need shared packages (`ui`, `types`, `config`, `utils`).
- Build/test/lint pipelines need workspace-level orchestration.

## Core Contract

1. Keep deployable apps in `apps/`.
2. Keep reusable packages in `packages/`.
3. Use workspace protocol dependencies (`workspace:*`).
4. Use Turbo pipelines for dependency-aware task execution.
5. Keep environment variables explicit per app/package boundary.

## Recommended Structure

```text
apps/
packages/
turbo.json
pnpm-workspace.yaml
package.json
```

## Implementation Workflow

### 1) Workspace Setup

- Configure `pnpm-workspace.yaml`.
- Define root scripts for `dev`, `build`, `lint`, `test`.
- Add Turbo pipeline with `dependsOn` and `outputs`.

### 2) Shared Packages

- Create `packages/ui`, `packages/types`, `packages/config`.
- Export public APIs from package roots.
- Keep package boundaries strict and testable.

### 3) App Integration

- Consume shared packages via workspace deps.
- Keep app-specific runtime config local to app.
- Avoid hidden coupling through root-only env assumptions.

### 4) Operational Quality

- Cache-friendly tasks and deterministic outputs.
- Per-package ownership and CI filters.
- Versioning/release strategy documented.

## Output Requirements for Agent

- Folder layout proposal.
- Workspace and Turbo config.
- Shared package strategy.
- CI/build command matrix.

## References

- Detailed setup files and command examples: `references/guide.md`
