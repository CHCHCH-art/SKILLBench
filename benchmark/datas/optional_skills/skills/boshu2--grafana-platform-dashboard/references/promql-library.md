# PromQL Panel Library

Starting-point queries for platform operations dashboards.

## Critical Alerts

Critical platform alert count with optional ArgoCD/GitOps exclusion:

```promql
count(
  (
    ALERTS{alertstate="firing",severity=~"(?i)critical",namespace=~"(openshift(-.*)?|crossplane-system|kubic-sso)",alertname!~"(?i).*argocd.*"}
  )
  or
  (
    ALERTS{alertstate="firing",severity=~"(?i)critical",namespace="",alertname=~".*(Kube|APIServer|Etcd|Node|Ingress|MachineConfig|ClusterOperator|Network|DNS|OAuth|Monitoring|Crossplane|Keycloak).*",alertname!~"(?i).*argocd.*"}
  )
) or vector(0)
```

Critical alert table:

```promql
max by (alertname, severity, namespace, runbook_url) (
  (
    ALERTS{alertstate="firing",severity=~"(?i)critical",namespace=~"(openshift(-.*)?|crossplane-system|kubic-sso)",alertname!~"(?i).*argocd.*"}
  )
  or
  (
    ALERTS{alertstate="firing",severity=~"(?i)critical",namespace="",alertname=~".*(Kube|APIServer|Etcd|Node|Ingress|MachineConfig|ClusterOperator|Network|DNS|OAuth|Monitoring|Crossplane|Keycloak).*",alertname!~"(?i).*argocd.*"}
  )
)
```

## Critical CO Gate Breaches

```promql
count(
  sum by (name) (
    (
      cluster_operator_conditions{condition="Degraded",name=~"cloud-credential|network|kube-apiserver|ingress|machine-config"} == 1
    )
    or
    (
      cluster_operator_conditions{condition="Progressing",name=~"cloud-credential|network|kube-apiserver|ingress|machine-config"} == 1
    )
    or
    (
      cluster_operator_conditions{condition="Available",name=~"cloud-credential|network|kube-apiserver|ingress|machine-config"} == 0
    )
  ) > 0
) or vector(0)
```

## Core Pod / Node Action Signals

OpenShift core pods not ready:

```promql
count(max by (namespace,pod,container) (
  kube_pod_container_status_ready{condition="false",namespace=~"openshift-(kube-apiserver|etcd|ovn-kubernetes|ingress|monitoring|authentication)"} == 1
)) or vector(0)
```

Nodes requiring action:

```promql
count(max by (node) (
  (kube_node_status_condition{condition="Ready",status="true"} == 0)
  or (kube_node_status_condition{condition=~"DiskPressure|MemoryPressure|PIDPressure|NetworkUnavailable",status="true"} == 1)
  or label_replace(kube_node_spec_unschedulable == 1, "condition", "SchedulingDisabled", "", "")
)) or vector(0)
```

## Crossplane

Unhealthy provider deployments:

```promql
count((
  kube_deployment_spec_replicas{namespace="crossplane-system",deployment=~"(crossplane-provider-.*|provider-.*|storagegrid-.*)"}
  -
  kube_deployment_status_replicas_available{namespace="crossplane-system",deployment=~"(crossplane-provider-.*|provider-.*|storagegrid-.*)"}
) > 0) or vector(0)
```

## Keycloak

Ready replica percent:

```promql
100 * sum(kube_statefulset_status_replicas_ready{namespace="kubic-sso",statefulset=~".*keycloak.*"})
/
clamp_min(sum(kube_statefulset_replicas{namespace="kubic-sso",statefulset=~".*keycloak.*"}), 1)
```
