---
name: proto-service-generator
description: Generate or complete `internal/service/<module>/*.go` service implementation skeletons from generated `api/<module>/v1/*.sphere.pb.go` HTTP interfaces in this repository. Use when proto and generated API files already exist and you need per-service files, interface assertion checks, safe append-only updates, simple CRUD direct Ent implementation, and fallback stub methods for unknown business logic.
---

# Proto Service Generator

Generate or complete compilable service implementations under `internal/service/<module>/` from generated `*ServiceHTTPServer` interfaces in `api/<module>/v1/*.sphere.pb.go`.

## When To Use

1. Proto and generated API files already exist.
2. You need missing service files or method implementations for `*ServiceHTTPServer`.
3. You need safe append-only completion for existing service files.

## Out of Scope

1. `BotServer` and non-HTTP interfaces.
2. Redesigning proto contracts or editing generated files.
3. Rewriting existing business logic unless explicitly requested.

## Required Reading

Read before generation:
1. [references/service-implementation-best-practices.md](references/service-implementation-best-practices.md)

Load sections selectively:
1. Always: `1) Interface Assertion and File Mapping`, `4) Append-Only Update Procedure`, `7) Import and Naming Checklist`.
2. Simple CRUD: `3) Simple CRUD (Direct Ent) Template`.
3. Unknown logic: `2) Stub Template for Unknown Logic`.
4. Complex orchestration and DI changes: `5) Complex Logic Split to Usecase`, `6) Wire Injection Pattern`.
5. Reuse checks: `8) Sphere Feature Reuse Pattern`.

## Companion Skill Policy

When `sphere-feature-workflow` is available in the current session, use it together with this skill.

Division of responsibility:
1. `sphere-feature-workflow`: framework-native end-to-end integration (routing, middleware, auth, errors, wiring flow).
2. `proto-service-generator`: per-service file generation and completion from `*ServiceHTTPServer`.

If `sphere-feature-workflow` is unavailable, continue with this skill and enforce reuse-first checks from the reference.

## Repository Conventions

1. Keep one `Service` struct per proto module.
2. Keep one Go file per proto service.
3. File naming: `XxxService -> xxx.go` (snake_case, remove `Service` suffix).
4. Every service file must include an interface assertion:
`var _ <pkg>.<ServiceName>HTTPServer = (*Service)(nil)`

## Workflow

1. Discover all `type XxxServiceHTTPServer interface` definitions under `api/<module>/v1/*.sphere.pb.go`.
2. Map each service to `internal/service/<module>/<service>.go`.
3. Check target file state:
- If missing, create file with assertion and all methods.
- If existing, append only missing methods, assertions, and required imports.
4. Run reuse-first checks before implementing new logic.
5. Implement method bodies by decision:
- Simple CRUD: direct Ent fast path.
- Unknown logic: compilable stub.
- Complex logic: split to `internal/usecase/<module>/<service>/` and wire dependencies.
6. Keep signatures exactly aligned with the interface; receiver is always `func (s *Service)`.
7. Preserve existing behavior; do not rewrite existing method bodies.
8. Validate with tests and report using the Output Contract.

## Decision Rules

1. Use simple CRUD fast path when method is `Create*`, `Get*`, `List*`, `Update*`, or `Delete*` on a single entity without complex orchestration.
2. Use stubs when logic cannot be inferred safely:
`return nil, errors.New("not implemented: <Method>")`
3. Split to usecase for clear cross-entity transactions, reusable orchestration, or long flows.

## Hard Rules

1. Do not modify generated files under `api/*`.
2. Do not add a new DAO wrapper for simple CRUD.
3. Do not delete or rewrite existing assertions or method bodies in target service files.
4. Add only required imports.
5. Keep dependency injection compilable when constructor signatures change.

## Output Contract

Output in this exact order:
1. `Scaffold Plan`
2. `Files To Create/Update`
3. `Interface Coverage Check`
4. `Stub Methods Added`
5. `Usecase Split Decision`
6. `Validation Result`

## Minimal Validation Checklist

1. `go test ./internal/service/...`
2. `go test ./cmd/app/...`
3. If constructor or provider signatures changed, run `make gen/wire` and rerun tests.

## Acceptance Checklist

1. New-file case: file exists, assertion exists, all interface methods exist, and code compiles.
2. Existing-file case: only missing methods are appended; existing implementations are unchanged.
3. Simple CRUD case: direct Ent via `s.db` with render helpers.
4. Complex-flow case: usecase split plus DI chain updates remain compilable.
