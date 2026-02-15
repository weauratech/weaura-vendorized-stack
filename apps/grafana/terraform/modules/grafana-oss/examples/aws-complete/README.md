# AWS Complete Example

This example deploys the complete Grafana OSS observability stack on AWS EKS with all components enabled.

## Components Deployed

- **Grafana** - Visualization and dashboarding
- **Prometheus** - Metrics collection (kube-prometheus-stack)
- **Loki** - Log aggregation (SimpleScalable mode)
- **Mimir** - Long-term metrics storage
- **Tempo** - Distributed tracing
- **Pyroscope** - Continuous profiling

## Prerequisites

1. An existing EKS cluster with OIDC enabled
2. AWS CLI configured with appropriate permissions
3. kubectl configured to access the cluster
4. Helm 3.x installed
5. Terraform >= 1.5.0

## AWS Resources Created

- **S3 Buckets**: For Loki, Mimir, and Tempo storage
- **IAM Roles**: IRSA roles for each component with S3 access

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

| Variable                 | Description                  |
| ------------------------ | ---------------------------- |
| `eks_cluster_name`       | Name of the EKS cluster      |
| `eks_oidc_provider_arn`  | ARN of the EKS OIDC provider |
| `eks_oidc_provider_url`  | URL of the EKS OIDC provider |
| `grafana_domain`         | Domain for Grafana ingress   |
| `grafana_admin_password` | Grafana admin password       |

## Optional Variables

| Variable          | Description        | Default      |
| ----------------- | ------------------ | ------------ |
| `aws_region`      | AWS region         | `us-east-1`  |
| `environment`     | Environment name   | `production` |
| `slack_webhook_*` | Slack webhook URLs | `""`         |

## Getting EKS OIDC Information

```bash
# Get OIDC issuer URL
aws eks describe-cluster --name <cluster-name> --query "cluster.identity.oidc.issuer" --output text

# Get OIDC provider ARN
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?ends_with(Arn, '$(aws eks describe-cluster --name <cluster-name> --query "cluster.identity.oidc.issuer" --output text | cut -d'/' -f5)')].Arn" --output text
```

## Outputs

After applying, you'll receive:

- `grafana_url` - URL to access Grafana
- `datasource_urls` - Internal URLs for all datasources
- `s3_bucket_names` - Names of created S3 buckets
- `iam_role_arns` - ARNs of IRSA roles

## Cleanup

```bash
terraform destroy
```

**Note**: S3 buckets may need to be emptied before destruction if they contain data.
