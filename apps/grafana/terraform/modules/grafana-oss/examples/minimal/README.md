# Minimal Example

This example deploys a minimal observability stack with just Grafana and Prometheus.

## Components Deployed

- **Grafana** - Visualization and dashboarding
- **Prometheus** - Metrics collection (kube-prometheus-stack)

## Use Cases

- Development environments
- Testing and evaluation
- Learning and experimentation
- Resource-constrained clusters

## Features Disabled

- **Loki** - Log aggregation
- **Mimir** - Long-term metrics storage
- **Tempo** - Distributed tracing
- **Pyroscope** - Continuous profiling
- **Alerting** - No alert channels configured
- **Object Storage** - Uses local storage only
- **Resource Quotas/Limit Ranges** - Disabled

## Prerequisites

1. A Kubernetes cluster (EKS, AKS, or any other)
2. kubectl configured to access the cluster
3. Helm 3.x installed
4. Terraform >= 1.5.0

## Usage

1. Set your variables:

```bash
export TF_VAR_grafana_domain="grafana.example.com"
export TF_VAR_grafana_admin_password="my-secure-password"
```

2. Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

## Variables

| Variable                 | Description        | Default          |
| ------------------------ | ------------------ | ---------------- |
| `cloud_provider`         | aws or azure       | `aws`            |
| `grafana_domain`         | Domain for Grafana | Required         |
| `grafana_admin_password` | Admin password     | Required         |
| `kubeconfig_path`        | Path to kubeconfig | `~/.kube/config` |

## Resource Usage

This minimal setup requires approximately:

- **Grafana**: 100m-500m CPU, 256Mi-512Mi memory
- **Prometheus**: 200m-1000m CPU, 512Mi-1Gi memory
- **Storage**: ~30Gi total (20Gi Prometheus, 10Gi Grafana)

## Upgrading to Full Stack

To upgrade to the full observability stack, enable additional components:

```hcl
module "grafana_oss" {
  # ...existing config...

  enable_loki      = true
  enable_mimir     = true
  enable_tempo     = true
  enable_pyroscope = true

  create_storage = true  # Enable cloud storage
}
```

## Cleanup

```bash
terraform destroy
```
