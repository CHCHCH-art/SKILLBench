# Layout Guidelines

Design for platform operators first, not for visual completeness.

## L1: Command View (Critical First)

Budget: 5-7 panels max.

Order:

1. `Critical Platform Alerts Count`
2. `Critical CO Gate Breaches`
3. `OpenShift Core Pods Not Ready`
4. `Nodes Requiring Action`
5. `Firing Critical Platform Alerts (with Runbook URL)`

Rules:

- Every panel must answer “what action now?”.
- Avoid trend-only visualizations in L1.
- Avoid ambiguous panel names.

## L2: Platform Service Health

Group by dependency domains with action tables:

- Control plane and core operators
- Crossplane providers/XRD readiness
- Keycloak readiness
- MCP and ingress control signals

## L3: Deep Dives

Use dedicated dashboards for complex domains:

- GPU
- Storage subsystem
- Service-specific workloads

Do not duplicate deep-dive detail in L1.

## Anti-Patterns

- Mixed severity panels at the top.
- Large top-row panel counts that require scrolling for critical alerts.
- “Red without action” panels.
