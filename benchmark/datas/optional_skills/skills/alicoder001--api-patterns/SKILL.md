---
name: api-patterns
description: API integration patterns including REST, GraphQL, WebSocket, and tRPC. Use when designing APIs, implementing data fetching, or building real-time features.
---

# API Integration Patterns

> Pick the protocol by data shape, ownership, and runtime constraints. Avoid mixing patterns without a clear boundary.

## Selection Guide

- REST:
- Standard CRUD, broad client compatibility, simple caching.
- GraphQL:
- Flexible read models, multi-client data composition, schema governance.
- WebSocket:
- Bi-directional real-time channels with low-latency updates.
- SSE:
- Server-to-client streaming where client push is unnecessary.
- tRPC:
- End-to-end TypeScript contracts in monorepos.

## Use This Skill When

- You need to define or refactor API boundaries.
- Frontend/server data fetching strategy is unclear.
- Real-time transport choice is blocking implementation.

## Implementation Workflow

### 1) Define API Contract

- Identify resource ownership and versioning strategy.
- Define request/response shapes and error model.
- Standardize auth, pagination, filtering, and idempotency.

### 2) Choose Transport

- REST for core CRUD.
- GraphQL for query composition.
- WebSocket/SSE for live updates.
- tRPC when shared TS types are required and service boundary allows it.

### 3) Standardize Client Layer

- Central client factory and interceptors.
- Typed API wrappers.
- Uniform retries/timeouts and auth refresh logic.
- Cache and invalidation rules documented per endpoint group.

### 4) Error and Observability

- Consistent API error envelope.
- Correlation IDs and request tracing.
- Log validation and transport failures separately.

### 5) Security Baseline

- Validate input schema at API boundary.
- Enforce authz at resource/action level.
- Apply rate limiting and payload size limits.

## Output Requirements for Agent

- Recommended transport and why.
- Endpoint/schema proposal.
- Client integration pattern.
- Real-time model if needed.
- Security and testing checklist.

## References

- Full templates for REST, GraphQL, WebSocket, SSE, and tRPC: `references/guide.md`
