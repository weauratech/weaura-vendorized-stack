# Azure Complete Example

This example deploys the complete Grafana OSS observability stack on Azure AKS with all components enabled.

## Components Deployed

- **Grafana** - Visualization and dashboarding
- **Prometheus** - Metrics collection (kube-prometheus-stack)
- **Loki** - Log aggregation (SimpleScalable mode)
- **Mimir** - Long-term metrics storage
- **Tempo** - Distributed tracing
- **Pyroscope** - Continuous profiling

## Prerequisites

1. An existing AKS cluster with Workload Identity enabled
2. Azure CLI configured with appropriate permissions
3. kubectl configured to access the cluster
4. Helm 3.x installed
5. Terraform >= 1.5.0

## Azure Resources Created

- **Storage Account**: For blob storage (LRS/ZRS/GRS based on config)
- **Blob Containers**: For Loki, Mimir, and Tempo data
- **User Assigned Managed Identities**: For each component with Storage Blob Data Contributor role
- **Federated Credentials**: For Kubernetes Service Account authentication

## Usage

1. Copy the example tfvars file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your values:

```bash
vim terraform.tfvars
```

3. Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

## Required Variables

| Variable                    | Description                  |
| --------------------------- | ---------------------------- |
| `azure_subscription_id`     | Azure subscription ID        |
| `azure_tenant_id`           | Azure tenant ID              |
| `azure_resource_group_name` | Resource group for resources |
| `aks_cluster_name`          | Name of the AKS cluster      |
| `aks_oidc_issuer_url`       | AKS OIDC issuer URL          |
| `grafana_domain`            | Domain for Grafana ingress   |
| `grafana_admin_password`    | Grafana admin password       |

## Optional Variables

| Variable          | Description        | Default      |
| ----------------- | ------------------ | ------------ |
| `azure_location`  | Azure location     | `eastus`     |
| `environment`     | Environment name   | `production` |
| `teams_webhook_*` | Teams webhook URLs | `""`         |

## Getting AKS OIDC Issuer URL

```bash
az aks show --resource-group <rg-name> --name <aks-name> --query "oidcIssuerProfile.issuerUrl" -o tsv
```

## Workload Identity

This module uses Azure Workload Identity for secure access to Azure resources:

1. Creates User Assigned Managed Identities for Loki, Mimir, and Tempo
2. Assigns Storage Blob Data Contributor role to each identity
3. Creates Federated Identity Credentials linking K8s Service Accounts
4. Configures Helm charts with the correct annotations

## Outputs

After applying, you'll receive:

- `grafana_url` - URL to access Grafana
- `datasource_urls` - Internal URLs for all datasources
- `storage_account` - Azure Storage Account name
- `storage_containers` - Blob container names
- `managed_identity_ids` - Managed Identity client IDs

## Cleanup

```bash
terraform destroy
```

**Note**: Storage containers may need to be emptied before destruction if they contain data.
