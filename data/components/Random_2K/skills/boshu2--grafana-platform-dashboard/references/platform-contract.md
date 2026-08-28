# Platform Contract

Use this file to keep dashboard scope tied to platform operations contracts instead of ad-hoc panels.

## Critical CO Gate (L1)

Default critical gate from repo health checks:

- `cloud-credential`
- `network`
- `kube-apiserver`
- `ingress`
- `machine-config`

Source of truth:
- `aap/playbooks/common/co-health-gate.yml`

## Platform Scope Namespaces

Use explicit namespace scope in panel descriptions and queries.

Recommended platform scope baseline:

- `openshift-*` (control plane and operators)
- `crossplane-system`
- `kubic-sso` (Keycloak)
- `openshift-grafana-operator`

Optional, cluster-specific additions:

- `ansible-automation-platform`
- storage/infra platform namespaces used by your environment

## Alert Filtering Policy

For L1 critical alert panels:

1. Include only `severity=critical`.
2. Exclude noise namespaces for request-specific cases (for example ArgoCD/GitOps).
3. Prefer platform namespace scoping and limited cluster-level alert-name allowlists.

## GPU Rule

Do not overload L1 with GPU deep diagnostics.

- Keep only top-level GPU availability indicators if required.
- Move detailed GPU health, drivers, and policy checks to dedicated GPU dashboard(s).
