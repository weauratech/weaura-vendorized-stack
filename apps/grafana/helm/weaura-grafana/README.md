# WeAura Grafana Helm Chart

The `weaura-grafana` Helm chart provides a comprehensive, multi-tenant observability solution for the WeAura platform. It bundles Grafana for visualization and Prometheus for metrics collection, tailored with pre-configured dashboards, alert rules, and branding options to meet the needs of WeAura clients.

This chart is designed to be deployed as a vendorized stack, offering a consistent monitoring experience across different environments. It includes deep integration with the WeAura platform through tenant-specific labeling and branding overrides, ensuring that each deployment reflects the identity of the managed tenant.

Key features include:
* Multi-tenant Grafana and Prometheus deployment
* Pre-provisioned dashboards for Kubernetes, applications, and infrastructure
* Built-in alert rules for common operational scenarios
* Customizable branding (titles, logos, and CSS overrides)
* Google OAuth SSO integration support

## Prerequisites

* Kubernetes cluster 1.23+ (EKS recommended)
* Helm 3.x
* StorageClass with dynamic provisioning support (default: `gp3`)
* `kubectl` configured with appropriate cluster access

## Quick Start

To install the chart with a basic configuration, use the following command.

```bash
# Installation without --wait flag is recommended due to node-exporter scheduling
helm install my-release oci://registry.dev.weaura.ai/weaura-vendorized/weaura-grafana \
  --namespace grafana \
  --create-namespace \
  --set tenant.id=my-tenant \
  --set tenant.name="My Tenant"

# Manually verify that critical pods are running
kubectl get pods -n grafana | grep -E 'grafana|prometheus-server'
```

## Configuration

The following table lists the key configuration parameters of the `weaura-grafana` chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `tenant.id` | REQUIRED: Alphanumeric identifier for the tenant | `""` |
| `tenant.name` | REQUIRED: Human-readable name of the client or tenant | `""` |
| `branding.appTitle` | Title displayed in the browser tab | `Grafana` |
| `branding.appName` | Name displayed in the Grafana UI | `Grafana` |
| `branding.loginTitle` | Title shown on the login page | `Sign in to Grafana` |
| `branding.logoUrl` | URL to a custom logo image (SVG/PNG) | `""` |
| `branding.cssOverrides` | Key-value pairs for CSS variable overrides | `{}` |
| `stack.grafana.enabled` | Enable the Grafana component | `true` |
| `grafana.enabled` | Master toggle for the Grafana subchart | `true` |
| `prometheus.enabled` | Master toggle for the Prometheus subchart | `true` |
| `dashboards.enabled` | Provision the WeAura default dashboards | `true` |
| `alerts.enabled` | Provision the WeAura default alert rules | `false` |
| `sso.enabled` | Enable Google OAuth SSO integration | `false` |
| `sso.google.clientId` | Google OAuth Client ID | `""` |
| `sso.google.clientSecret` | Google OAuth Client Secret | `""` |
| `sso.google.allowedDomains` | Comma-separated list of allowed domains | `""` |

For a complete list of options, please refer to the `values.yaml` file.

## Architecture Overview

The `weaura-grafana` chart is composed of the following core components and subcharts:

* **Grafana (Subchart v7.3.12)**: The primary visualization engine, configured with custom provisioning for datasources and dashboards.
* **Prometheus (Subchart v25.0.0)**: The metrics collection and storage backend.
* **Content Packs**: A collection of 4 dashboards and 4 alert rules provisioned via ConfigMaps and sidecar containers.
* **Branding Templates**: CSS and logo overrides applied through init containers and custom configuration files.

## Feature Toggles

The chart provides several toggles to customize the deployed features:

* **Dashboards**: When `dashboards.enabled` is true, 4 custom dashboards (Kubernetes Overview, Application Overview, Loki Logs, and Node Exporter) are automatically provisioned.
* **Alerts**: When `alerts.enabled` is true, 4 default alert rules are provisioned into the monitoring stack.
* **SSO**: Google OAuth can be enabled via `sso.enabled` to provide secure authentication for tenant users.
* **Branding**: The look and feel can be customized using the `branding` configuration block.

## Stack Integration

The chart includes configuration blocks for integrating with other observability backends like Loki, Tempo, Mimir, and Pyroscope.

**WARNING**: The `stack.loki`, `stack.tempo`, `stack.mimir`, and `stack.pyroscope` toggles are currently defined in `values.yaml` but are **NOT YET IMPLEMENTED**. Enabling these toggles will not result in the creation of corresponding datasources in this version.

## Content Packs

The following assets are included as part of the WeAura observability package:

### Dashboards
* **Kubernetes Overview**: Cluster-wide resource monitoring.
* **Application Overview**: Service-level golden signals (requests, errors, latency).
* **Loki Logs**: Centralized log exploration (requires external Loki).
* **Node Exporter**: Detailed hardware and OS metrics for cluster nodes.

### Alert Rules
* **High CPU Usage**: Triggers when node CPU exceeds 80%.
* **High Memory Usage**: Triggers when node memory exceeds 80%.
* **Pod CrashLooping**: Triggers when pods enter a CrashLoopBackOff state.
* **Disk Pressure**: Triggers when persistent volumes reach 90% capacity.

## Known Limitations

Please be aware of the following known issues in this release:

* **Bug #2: Prometheus Datasource Requirement**: The chart currently hardcodes a Prometheus datasource even when `prometheus.enabled` is set to false. This results in a broken datasource in Grafana if an external Prometheus is not provided with the expected service name.
* **Bug #4: Tenant Label Propagation**: `tenant.id` and `tenant.name` labels are not currently propagated to the pods created by the Grafana and Prometheus subcharts. They are applied only to parent chart resources like ConfigMaps.
* **Bug #5: Stack Datasources Missing**: As noted in the Stack Integration section, toggles for Loki, Tempo, Mimir, and Pyroscope are non-functional and do not provision datasources.
* **Node-exporter Scheduling**: The `prometheus-node-exporter` DaemonSet may fail to schedule on some nodes in EKS clusters due to nodeAffinity restrictions in the upstream subchart. This does not impact core functionality. Use the installation command without the `--wait` flag to avoid timeouts.

## Version History

* **0.2.2**: Added comprehensive README.md and updated `.helmignore` to ensure README is included in the OCI package.
* **0.2.1**: Initial migration to Harbor OCI registry complete.
