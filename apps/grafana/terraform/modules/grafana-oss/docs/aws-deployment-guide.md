# AWS Deployment Guide: Grafana OSS Observability Stack

```yaml
# METADATA - AI AGENT PARSING CONTEXT
document_type: ai-agent-deployment-guide
cloud_provider: aws
module_name: grafana-oss
module_source: github.com/weauratech/weaura-terraform-modules//modules/grafana-oss
version: "1.0.0"
last_updated: "2025-01-19"
estimated_deployment_time: "15-25 minutes"
components:
  - grafana
  - prometheus
  - loki
  - mimir
  - tempo
  - pyroscope
```

---

## 1. PREREQUISITES

### 1.1 Required Infrastructure

| Resource                 | Requirement                        | How to Verify                               |
| ------------------------ | ---------------------------------- | ------------------------------------------- |
| EKS Cluster              | Kubernetes 1.27+ with OIDC enabled | `aws eks describe-cluster --name <CLUSTER>` |
| VPC                      | With private subnets               | `aws ec2 describe-vpcs`                     |
| AWS Account              | Admin or PowerUser permissions     | `aws sts get-caller-identity`               |
| NGINX Ingress Controller | Installed in cluster               | `kubectl get pods -n ingress-nginx`         |
| cert-manager             | Installed for TLS                  | `kubectl get pods -n cert-manager`          |
| StorageClass             | `gp3` or equivalent                | `kubectl get storageclass`                  |

### 1.2 Required Permissions

The executing identity (user or role) needs:

| AWS Permission        | Resource            | Purpose                              |
| --------------------- | ------------------- | ------------------------------------ |
| `s3:*`                | S3 buckets          | Create buckets for long-term storage |
| `iam:*`               | IAM roles           | Create IRSA roles for pods           |
| `kms:*`               | KMS keys (optional) | Encrypt S3 buckets                   |
| `secretsmanager:*`    | Secrets (optional)  | Store webhook URLs                   |
| `eks:DescribeCluster` | EKS cluster         | Get cluster info                     |

### 1.3 Required Tools

| Tool      | Minimum Version | Install Command          |
| --------- | --------------- | ------------------------ |
| terraform | 1.5.0           | `brew install terraform` |
| kubectl   | 1.27            | `brew install kubectl`   |
| aws cli   | 2.13            | `brew install awscli`    |
| helm      | 3.12            | `brew install helm`      |

### 1.4 Prerequisite Validation Commands

```bash
# AGENT: Execute these commands to validate prerequisites
# All commands must succeed before proceeding

# 1. Verify AWS CLI authentication
aws sts get-caller-identity --query "{Account:Account, Arn:Arn}" --output json

# 2. Verify EKS cluster exists and get info
aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --query "{name:cluster.name, version:cluster.version, oidcIssuer:cluster.identity.oidc.issuer}" --output json

# 3. Get OIDC Provider ARN
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, '${EKS_CLUSTER_NAME}')].Arn" --output text

# 4. Verify kubectl context
kubectl cluster-info

# 5. Verify NGINX Ingress Controller
kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# 6. Verify cert-manager
kubectl get pods -n cert-manager

# 7. Verify StorageClass exists
kubectl get storageclass gp3

# 8. Verify Terraform version
terraform version
```

**AGENT DECISION POINT - Missing Prerequisites:**
If any prerequisite check fails, present these options to the user:

| Missing Component | Options                                                           |
| ----------------- | ----------------------------------------------------------------- |
| NGINX Ingress     | 1. Install now (provide Helm command) 2. Skip and configure later |
| cert-manager      | 1. Install now (provide Helm command) 2. Disable TLS              |
| gp3 StorageClass  | 1. Create gp3 StorageClass 2. Use gp2 instead                     |
| OIDC not enabled  | 1. Enable OIDC on EKS (requires eksctl or console)                |

---

## 2. INFORMATION GATHERING

### 2.1 Required Information

**AGENT: Ask the user each question below. All fields in this section are REQUIRED.**

| Variable                 | Question to Ask User                                                     | Type   | Validation                       |
| ------------------------ | ------------------------------------------------------------------------ | ------ | -------------------------------- |
| `aws_region`             | "Which AWS region is your EKS cluster in? (e.g., us-east-1)"             | string | Valid AWS region                 |
| `eks_cluster_name`       | "What is the name of your EKS cluster?"                                  | string | Non-empty                        |
| `eks_oidc_provider_arn`  | "What is the ARN of your EKS OIDC Provider?"                             | string | ARN format                       |
| `eks_oidc_provider_url`  | "What is the OIDC Provider URL (without https://)?"                      | string | URL without protocol             |
| `grafana_domain`         | "What domain will Grafana be accessible at? (e.g., grafana.example.com)" | string | Valid FQDN                       |
| `grafana_admin_password` | "Set the Grafana admin password (min 12 characters):"                    | string | min 12 chars                     |
| `environment`            | "Which environment is this? (dev/staging/production)"                    | string | One of: dev, staging, production |
| `project`                | "What is the project name? (used for resource naming)"                   | string | Alphanumeric with hyphens        |

**AGENT: Auto-retrieve these values if possible:**

```bash
# Get AWS Region
aws configure get region

# Get EKS OIDC Provider URL
aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --query "cluster.identity.oidc.issuer" --output text

# Get OIDC Provider ARN (extract ID from URL first)
OIDC_ID=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?ends_with(Arn, '${OIDC_ID}')].Arn" --output text
```

### 2.2 Optional Configuration

**AGENT: Present these as optional customizations. Use defaults if user doesn't specify.**

| Variable                   | Question                                                       | Default            | Notes                   |
| -------------------------- | -------------------------------------------------------------- | ------------------ | ----------------------- |
| `s3_bucket_prefix`         | "S3 bucket name prefix? (leave empty for auto-generated)"      | `{project}-{env}`  | Must be globally unique |
| `s3_kms_key_arn`           | "KMS key ARN for S3 encryption? (leave empty for AWS managed)" | `""`               | CMK improves security   |
| `storage_class`            | "Which StorageClass for persistent volumes?"                   | `gp3`              | Must exist in cluster   |
| `grafana_chart_version`    | "Grafana Helm chart version?"                                  | `8.12.1`           |                         |
| `prometheus_chart_version` | "Prometheus chart version?"                                    | `72.6.2`           |                         |
| `cluster_issuer`           | "cert-manager ClusterIssuer name?"                             | `letsencrypt-prod` |                         |
| `ingress_class`            | "Ingress class name?"                                          | `nginx`            |                         |
| `acm_certificate_arn`      | "ACM certificate ARN? (for ALB ingress)"                       | `""`               | Only if using ALB       |

### 2.3 Decision Points

**AGENT: Present these choices to the user and record their selections.**

#### Decision 1: Component Selection

```yaml
decision: component_selection
question: "Which components do you want to deploy?"
options:
  - id: full_stack
    label: "Full Stack (Recommended)"
    description: "All 6 components: Grafana, Prometheus, Loki, Mimir, Tempo, Pyroscope"
    sets:
      enable_grafana: true
      enable_prometheus: true
      enable_loki: true
      enable_mimir: true
      enable_tempo: true
      enable_pyroscope: true
  - id: core_only
    label: "Core Observability"
    description: "Grafana + Prometheus + Loki (metrics and logs)"
    sets:
      enable_grafana: true
      enable_prometheus: true
      enable_loki: true
      enable_mimir: false
      enable_tempo: false
      enable_pyroscope: false
  - id: custom
    label: "Custom Selection"
    description: "Choose individual components"
    follow_up_questions:
      - "Enable Grafana? (yes/no)"
      - "Enable Prometheus? (yes/no)"
      - "Enable Loki? (yes/no)"
      - "Enable Mimir? (yes/no)"
      - "Enable Tempo? (yes/no)"
      - "Enable Pyroscope? (yes/no)"
```

#### Decision 2: Sizing Profile

```yaml
decision: sizing_profile
question: "What sizing profile matches your workload?"
options:
  - id: development
    label: "Development"
    description: "Minimal resources, single replicas, 10GB storage"
    sets:
      grafana_resources:
        requests: { cpu: "100m", memory: "128Mi" }
        limits: { cpu: "500m", memory: "512Mi" }
      prometheus_storage_size: "10Gi"
      loki_replicas: { read: 1, write: 1, backend: 1 }
      mimir_replication_factor: 1
  - id: staging
    label: "Staging"
    description: "Moderate resources, some HA, 50GB storage"
    sets:
      grafana_resources:
        requests: { cpu: "200m", memory: "256Mi" }
        limits: { cpu: "1000m", memory: "1Gi" }
      prometheus_storage_size: "50Gi"
      loki_replicas: { read: 2, write: 2, backend: 2 }
      mimir_replication_factor: 2
  - id: production
    label: "Production (Recommended for prod)"
    description: "Full HA, generous resources, 100GB+ storage"
    sets:
      grafana_resources:
        requests: { cpu: "500m", memory: "512Mi" }
        limits: { cpu: "2000m", memory: "2Gi" }
      prometheus_storage_size: "100Gi"
      loki_replicas: { read: 3, write: 3, backend: 3 }
      mimir_replication_factor: 3
```

#### Decision 3: SSO Configuration

```yaml
decision: sso_configuration
question: "Do you want to enable Single Sign-On (SSO) for Grafana?"
options:
  - id: none
    label: "No SSO"
    description: "Use local admin account only"
    sets:
      grafana_sso_enabled: false
  - id: google
    label: "Google Workspace (Recommended)"
    description: "Use Google for authentication"
    sets:
      grafana_sso_enabled: true
      grafana_sso_provider: "google"
    required_inputs:
      - variable: grafana_sso_client_id
        question: "Google OAuth Client ID:"
      - variable: grafana_sso_client_secret
        question: "Google OAuth Client Secret:"
      - variable: grafana_sso_allowed_domains
        question: "Allowed email domains (comma-separated, e.g., 'company.com'):"
  - id: okta
    label: "Okta"
    description: "Use Okta for authentication"
    sets:
      grafana_sso_enabled: true
      grafana_sso_provider: "okta"
    required_inputs:
      - variable: grafana_sso_client_id
        question: "Okta Client ID:"
      - variable: grafana_sso_client_secret
        question: "Okta Client Secret:"
      - variable: grafana_oauth_auth_url
        question: "Okta Authorization URL:"
      - variable: grafana_oauth_token_url
        question: "Okta Token URL:"
      - variable: grafana_sso_allowed_domains
        question: "Allowed email domains:"
  - id: cognito
    label: "AWS Cognito"
    description: "Use AWS Cognito for authentication"
    sets:
      grafana_sso_enabled: true
      grafana_sso_provider: "generic_oauth"
    required_inputs:
      - variable: grafana_sso_client_id
        question: "Cognito App Client ID:"
      - variable: grafana_sso_client_secret
        question: "Cognito App Client Secret:"
      - variable: grafana_oauth_auth_url
        question: "Cognito Authorization URL:"
      - variable: grafana_oauth_token_url
        question: "Cognito Token URL:"
```

#### Decision 4: Alerting Provider

```yaml
decision: alerting_provider
question: "Where should alerts be sent?"
options:
  - id: none
    label: "No Alerting"
    description: "Disable alert notifications"
    sets:
      alerting_provider: "none"
  - id: slack
    label: "Slack (Recommended for AWS)"
    description: "Send alerts to Slack channels"
    sets:
      alerting_provider: "slack"
    required_inputs:
      - variable: slack_webhook_general
        question: "Slack webhook URL for general alerts:"
      - variable: slack_webhook_critical
        question: "Slack webhook URL for critical alerts (optional, uses general if empty):"
      - variable: slack_channel_general
        question: "Slack channel for general alerts (e.g., #alerts):"
      - variable: slack_channel_critical
        question: "Slack channel for critical alerts (e.g., #alerts-critical):"
  - id: teams
    label: "Microsoft Teams"
    description: "Send alerts to Teams channels"
    sets:
      alerting_provider: "teams"
    required_inputs:
      - variable: teams_webhook_general
        question: "Teams webhook URL for general alerts:"
      - variable: teams_webhook_critical
        question: "Teams webhook URL for critical alerts (optional):"
```

#### Decision 5: Ingress Type

```yaml
decision: ingress_type
question: "Which ingress type do you want to use?"
options:
  - id: nginx_internal
    label: "NGINX Internal (Recommended)"
    description: "NGINX Ingress Controller with internal NLB"
    sets:
      ingress_class: "nginx"
      ingress_scheme: "internal"
  - id: nginx_public
    label: "NGINX Public"
    description: "NGINX Ingress Controller with public NLB"
    sets:
      ingress_class: "nginx"
      ingress_scheme: "internet-facing"
  - id: alb
    label: "AWS ALB"
    description: "AWS Application Load Balancer (requires ALB controller)"
    sets:
      ingress_class: "alb"
      ingress_scheme: "internal"
    required_inputs:
      - variable: acm_certificate_arn
        question: "ACM Certificate ARN for TLS:"
```

---

## 3. TERRAFORM CONFIGURATION

### 3.1 Directory Structure

**AGENT: Create this directory structure:**

```bash
mkdir -p observability-aws/{environments/production,modules}
cd observability-aws
```

```
observability-aws/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── terraform.tfvars
└── environments/
    └── production/
        └── terraform.tfvars
```

### 3.2 providers.tf

```hcl
# providers.tf - AWS Provider Configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # AGENT: Uncomment and configure backend for state storage
  # backend "s3" {
  #   bucket         = "terraform-state-bucket"
  #   key            = "observability/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

# AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data source for EKS cluster
data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.eks_cluster_name
}

# Kubernetes Provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Helm Provider
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
```

### 3.3 variables.tf

```hcl
# variables.tf - Input Variables

# ============================================================
# AWS CONFIGURATION (Required)
# ============================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_oidc_provider_arn" {
  description = "EKS OIDC Provider ARN for IRSA"
  type        = string
}

variable "eks_oidc_provider_url" {
  description = "EKS OIDC Provider URL (without https://)"
  type        = string
}

# ============================================================
# ENVIRONMENT & NAMING
# ============================================================

variable "environment" {
  description = "Environment (dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "project" {
  description = "Project name for resource naming"
  type        = string
  default     = "observability"
}

# ============================================================
# COMPONENT TOGGLES
# ============================================================

variable "enable_grafana" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Enable Prometheus"
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Enable Loki"
  type        = bool
  default     = true
}

variable "enable_mimir" {
  description = "Enable Mimir"
  type        = bool
  default     = true
}

variable "enable_tempo" {
  description = "Enable Tempo"
  type        = bool
  default     = true
}

variable "enable_pyroscope" {
  description = "Enable Pyroscope"
  type        = bool
  default     = true
}

# ============================================================
# GRAFANA CONFIGURATION
# ============================================================

variable "grafana_domain" {
  description = "Domain for Grafana (e.g., grafana.example.com)"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_sso_enabled" {
  description = "Enable SSO for Grafana"
  type        = bool
  default     = false
}

variable "grafana_sso_provider" {
  description = "SSO provider (google, okta, generic_oauth)"
  type        = string
  default     = "google"
}

variable "grafana_sso_client_id" {
  description = "SSO Client ID"
  type        = string
  default     = ""
}

variable "grafana_sso_client_secret" {
  description = "SSO Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "grafana_sso_allowed_domains" {
  description = "Allowed email domains for SSO"
  type        = string
  default     = ""
}

variable "grafana_oauth_auth_url" {
  description = "OAuth Authorization URL (for Okta/Cognito)"
  type        = string
  default     = ""
}

variable "grafana_oauth_token_url" {
  description = "OAuth Token URL (for Okta/Cognito)"
  type        = string
  default     = ""
}

# ============================================================
# ALERTING CONFIGURATION
# ============================================================

variable "alerting_provider" {
  description = "Alerting provider (slack, teams, none)"
  type        = string
  default     = "none"
}

variable "slack_webhook_general" {
  description = "Slack webhook for general alerts"
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_webhook_critical" {
  description = "Slack webhook for critical alerts"
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_channel_general" {
  description = "Slack channel for general alerts"
  type        = string
  default     = "#alerts"
}

variable "slack_channel_critical" {
  description = "Slack channel for critical alerts"
  type        = string
  default     = "#alerts-critical"
}

variable "teams_webhook_general" {
  description = "Teams webhook for general alerts"
  type        = string
  default     = ""
  sensitive   = true
}

variable "teams_webhook_critical" {
  description = "Teams webhook for critical alerts"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================================
# INGRESS CONFIGURATION
# ============================================================

variable "enable_ingress" {
  description = "Enable ingress for Grafana"
  type        = bool
  default     = true
}

variable "enable_tls" {
  description = "Enable TLS for ingress"
  type        = bool
  default     = true
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer name"
  type        = string
  default     = "letsencrypt-prod"
}

variable "ingress_class" {
  description = "Ingress class name (nginx or alb)"
  type        = string
  default     = "nginx"
}

variable "ingress_scheme" {
  description = "Ingress scheme (internal or internet-facing)"
  type        = string
  default     = "internal"
}

variable "acm_certificate_arn" {
  description = "ACM Certificate ARN (for ALB ingress)"
  type        = string
  default     = ""
}

# ============================================================
# STORAGE CONFIGURATION
# ============================================================

variable "storage_class" {
  description = "Kubernetes StorageClass for PVCs"
  type        = string
  default     = "gp3"
}

variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket names"
  type        = string
  default     = ""
}

variable "s3_kms_key_arn" {
  description = "KMS key ARN for S3 encryption (empty for AWS managed)"
  type        = string
  default     = ""
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "50Gi"
}

# ============================================================
# RESOURCE SIZING
# ============================================================

variable "grafana_resources" {
  description = "Grafana resource requests/limits"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

variable "loki_replicas" {
  description = "Loki component replicas"
  type = object({
    read    = number
    write   = number
    backend = number
  })
  default = {
    read    = 2
    write   = 2
    backend = 2
  }
}

variable "mimir_replication_factor" {
  description = "Mimir replication factor"
  type        = number
  default     = 2
}

# ============================================================
# TAGS
# ============================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### 3.4 main.tf

```hcl
# main.tf - Grafana OSS Observability Stack

module "observability" {
  source = "github.com/weauratech/weaura-terraform-modules//modules/grafana-oss?ref=v1.0.0"

  # Cloud Provider
  cloud_provider = "aws"

  # AWS Configuration
  aws_region            = var.aws_region
  eks_cluster_name      = var.eks_cluster_name
  eks_oidc_provider_arn = var.eks_oidc_provider_arn
  eks_oidc_provider_url = var.eks_oidc_provider_url

  # Environment
  environment = var.environment
  project     = var.project

  # Component Toggles
  enable_grafana    = var.enable_grafana
  enable_prometheus = var.enable_prometheus
  enable_loki       = var.enable_loki
  enable_mimir      = var.enable_mimir
  enable_tempo      = var.enable_tempo
  enable_pyroscope  = var.enable_pyroscope

  # Grafana Configuration
  grafana_domain            = var.grafana_domain
  grafana_admin_password    = var.grafana_admin_password
  grafana_resources         = var.grafana_resources
  grafana_sso_enabled       = var.grafana_sso_enabled
  grafana_sso_provider      = var.grafana_sso_provider
  grafana_sso_client_id     = var.grafana_sso_client_id
  grafana_sso_client_secret = var.grafana_sso_client_secret
  grafana_sso_allowed_domains = var.grafana_sso_allowed_domains
  grafana_oauth_auth_url    = var.grafana_oauth_auth_url
  grafana_oauth_token_url   = var.grafana_oauth_token_url

  # Alerting
  alerting_provider      = var.alerting_provider
  slack_webhook_general  = var.slack_webhook_general
  slack_webhook_critical = var.slack_webhook_critical
  slack_channel_general  = var.slack_channel_general
  slack_channel_critical = var.slack_channel_critical
  teams_webhook_general  = var.teams_webhook_general
  teams_webhook_critical = var.teams_webhook_critical

  # Ingress
  enable_ingress      = var.enable_ingress
  enable_tls          = var.enable_tls
  cluster_issuer      = var.cluster_issuer
  ingress_class       = var.ingress_class
  ingress_scheme      = var.ingress_scheme
  acm_certificate_arn = var.acm_certificate_arn

  # Storage
  storage_class           = var.storage_class
  s3_bucket_prefix        = var.s3_bucket_prefix
  s3_kms_key_arn          = var.s3_kms_key_arn
  prometheus_storage_size = var.prometheus_storage_size

  # Loki & Mimir
  loki_replicas            = var.loki_replicas
  mimir_replication_factor = var.mimir_replication_factor

  # Tags
  tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  })
}
```

### 3.5 outputs.tf

```hcl
# outputs.tf - Module Outputs

output "grafana_url" {
  description = "Grafana URL"
  value       = "https://${var.grafana_domain}"
}

output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = "admin"
}

output "namespace_grafana" {
  description = "Grafana namespace"
  value       = module.observability.namespace_grafana
}

output "namespace_prometheus" {
  description = "Prometheus namespace"
  value       = module.observability.namespace_prometheus
}

output "namespace_loki" {
  description = "Loki namespace"
  value       = module.observability.namespace_loki
}

output "s3_buckets" {
  description = "S3 bucket names for each component"
  value       = module.observability.s3_bucket_names
}

output "iam_role_arns" {
  description = "IAM role ARNs for IRSA"
  value       = module.observability.iam_role_arns
}

output "deployment_summary" {
  description = "Deployment summary"
  value = {
    cloud_provider = "aws"
    region         = var.aws_region
    environment    = var.environment
    project        = var.project
    grafana_url    = "https://${var.grafana_domain}"
    components = {
      grafana    = var.enable_grafana
      prometheus = var.enable_prometheus
      loki       = var.enable_loki
      mimir      = var.enable_mimir
      tempo      = var.enable_tempo
      pyroscope  = var.enable_pyroscope
    }
  }
}
```

### 3.6 terraform.tfvars (Template)

**AGENT: Generate this file with collected user inputs:**

```hcl
# terraform.tfvars - Environment Configuration
# Generated by AI Agent for AWS deployment

# ============================================================
# AWS CONFIGURATION
# ============================================================
aws_region            = "${COLLECTED_aws_region}"
eks_cluster_name      = "${COLLECTED_eks_cluster_name}"
eks_oidc_provider_arn = "${COLLECTED_eks_oidc_provider_arn}"
eks_oidc_provider_url = "${COLLECTED_eks_oidc_provider_url}"

# ============================================================
# ENVIRONMENT
# ============================================================
environment = "${COLLECTED_environment}"
project     = "${COLLECTED_project}"

# ============================================================
# COMPONENT TOGGLES
# ============================================================
enable_grafana    = ${DECISION_enable_grafana}
enable_prometheus = ${DECISION_enable_prometheus}
enable_loki       = ${DECISION_enable_loki}
enable_mimir      = ${DECISION_enable_mimir}
enable_tempo      = ${DECISION_enable_tempo}
enable_pyroscope  = ${DECISION_enable_pyroscope}

# ============================================================
# GRAFANA
# ============================================================
grafana_domain         = "${COLLECTED_grafana_domain}"
grafana_admin_password = "${COLLECTED_grafana_admin_password}"

# SSO Configuration (if enabled)
grafana_sso_enabled       = ${DECISION_sso_enabled}
grafana_sso_provider      = "${DECISION_sso_provider}"
grafana_sso_client_id     = "${COLLECTED_sso_client_id}"
grafana_sso_client_secret = "${COLLECTED_sso_client_secret}"
grafana_sso_allowed_domains = "${COLLECTED_sso_allowed_domains}"

# ============================================================
# ALERTING
# ============================================================
alerting_provider      = "${DECISION_alerting_provider}"
slack_webhook_general  = "${COLLECTED_slack_webhook_general}"
slack_webhook_critical = "${COLLECTED_slack_webhook_critical}"
slack_channel_general  = "${COLLECTED_slack_channel_general}"
slack_channel_critical = "${COLLECTED_slack_channel_critical}"

# ============================================================
# INGRESS
# ============================================================
enable_ingress = true
enable_tls     = true
cluster_issuer = "letsencrypt-prod"
ingress_class  = "${DECISION_ingress_class}"
ingress_scheme = "${DECISION_ingress_scheme}"

# ============================================================
# STORAGE & SIZING (Based on sizing profile)
# ============================================================
storage_class           = "gp3"
prometheus_storage_size = "${DECISION_prometheus_storage_size}"

grafana_resources = ${DECISION_grafana_resources_json}

loki_replicas = ${DECISION_loki_replicas_json}

mimir_replication_factor = ${DECISION_mimir_replication_factor}

# ============================================================
# TAGS
# ============================================================
tags = {
  Environment = "${COLLECTED_environment}"
  Project     = "${COLLECTED_project}"
  ManagedBy   = "terraform"
  DeployedBy  = "ai-agent"
}
```

### 3.7 Example Complete tfvars

```hcl
# Example: Production deployment with full stack and Slack alerting

aws_region            = "us-east-1"
eks_cluster_name      = "eks-prod-us-east-1"
eks_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
eks_oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"

environment = "production"
project     = "platform"

enable_grafana    = true
enable_prometheus = true
enable_loki       = true
enable_mimir      = true
enable_tempo      = true
enable_pyroscope  = true

grafana_domain         = "grafana.platform.company.com"
grafana_admin_password = "SuperSecurePassword123!"

grafana_sso_enabled         = true
grafana_sso_provider        = "google"
grafana_sso_client_id       = "123456789-abcdefg.apps.googleusercontent.com"
grafana_sso_client_secret   = "GOCSPX-xxxxxxxxxxxx"
grafana_sso_allowed_domains = "company.com"

alerting_provider      = "slack"
slack_webhook_general  = "https://hooks.slack.com/services/T00/B00/XXXX"
slack_webhook_critical = "https://hooks.slack.com/services/T00/B00/YYYY"
slack_channel_general  = "#alerts"
slack_channel_critical = "#alerts-critical"

enable_ingress = true
enable_tls     = true
cluster_issuer = "letsencrypt-prod"
ingress_class  = "nginx"
ingress_scheme = "internal"

storage_class           = "gp3"
prometheus_storage_size = "100Gi"

grafana_resources = {
  requests = {
    cpu    = "500m"
    memory = "512Mi"
  }
  limits = {
    cpu    = "2000m"
    memory = "2Gi"
  }
}

loki_replicas = {
  read    = 3
  write   = 3
  backend = 3
}

mimir_replication_factor = 3

tags = {
  Environment = "production"
  Project     = "platform"
  Team        = "platform-engineering"
  CostCenter  = "engineering"
  ManagedBy   = "terraform"
}
```

---

## 4. DEPLOYMENT STEPS

### 4.1 Initialize Terraform

```bash
# AGENT: Execute in the deployment directory

# Initialize Terraform
terraform init

# Expected output should include:
# - Provider installation success
# - Module download success
# - Backend initialization (if configured)
```

**AGENT: If init fails, check:**

- Network connectivity to GitHub and Terraform registry
- AWS credentials are valid
- S3 backend bucket exists (if using remote state)

### 4.2 Validate Configuration

```bash
# Validate Terraform configuration
terraform validate

# Expected output:
# Success! The configuration is valid.
```

### 4.3 Plan Deployment

```bash
# Generate execution plan
terraform plan -out=tfplan

# Review the plan - expected resources:
# - aws_s3_bucket (4-6)
# - aws_iam_role (4-6)
# - aws_iam_role_policy_attachment (4-6)
# - helm_release (4-6)
# - kubernetes_namespace (4-6)
```

**AGENT: Present plan summary to user:**

- Number of resources to create
- Estimated time (based on resource count)
- Any warnings or notes

### 4.4 Apply Configuration

```bash
# Apply the plan
terraform apply tfplan

# Or apply with auto-approve (use with caution)
# terraform apply -auto-approve
```

**AGENT: Monitor apply progress. Typical timing:**

- Namespaces: ~10 seconds
- S3 buckets: ~30 seconds
- IAM roles: ~30 seconds
- Helm releases: 5-10 minutes total

### 4.5 Verify Outputs

```bash
# Display outputs
terraform output

# Get specific outputs
terraform output grafana_url
terraform output deployment_summary
```

---

## 5. POST-DEPLOYMENT VALIDATION

### 5.1 Validation Script

**AGENT: Execute this complete validation script after deployment:**

```bash
#!/bin/bash
# post-deploy-validation.sh
# AWS Observability Stack Validation

set -e

GRAFANA_DOMAIN="${COLLECTED_grafana_domain}"
AWS_REGION="${COLLECTED_aws_region}"
TIMEOUT=300  # 5 minutes

echo "=== Validating Observability Stack Deployment ==="

# Function to check pod readiness
check_pods() {
  local namespace=$1
  local timeout=${2:-60}

  echo "Checking pods in namespace: $namespace"
  kubectl wait --for=condition=ready pods --all -n "$namespace" --timeout="${timeout}s" 2>/dev/null || {
    echo "WARNING: Some pods in $namespace are not ready"
    kubectl get pods -n "$namespace"
    return 1
  }
  echo "All pods in $namespace are ready"
}

# 1. Verify Helm releases
echo ""
echo "=== Helm Releases ==="
helm list -A | grep -E "(grafana|prometheus|loki|mimir|tempo|pyroscope)" || echo "No matching releases found"

# 2. Check namespaces
echo ""
echo "=== Namespaces ==="
for ns in grafana prometheus loki mimir tempo pyroscope; do
  if kubectl get namespace "$ns" &>/dev/null; then
    echo "[OK] Namespace $ns exists"
  else
    echo "[SKIP] Namespace $ns not found (component may be disabled)"
  fi
done

# 3. Check pods in each namespace
echo ""
echo "=== Pod Status ==="
for ns in grafana prometheus loki mimir tempo pyroscope; do
  if kubectl get namespace "$ns" &>/dev/null; then
    check_pods "$ns" 60 || true
  fi
done

# 4. Check Grafana ingress
echo ""
echo "=== Ingress Status ==="
kubectl get ingress -n grafana 2>/dev/null || echo "No ingress found in grafana namespace"

# 5. Check certificate status
echo ""
echo "=== Certificate Status ==="
kubectl get certificate -n grafana 2>/dev/null || echo "No certificates found"

# 6. Test Grafana health endpoint (if accessible)
echo ""
echo "=== Grafana Health Check ==="
if curl -s --connect-timeout 5 "https://${GRAFANA_DOMAIN}/api/health" 2>/dev/null; then
  echo ""
  echo "[OK] Grafana is responding"
else
  echo "[INFO] Grafana not accessible externally (may need DNS/VPN)"
  # Try internal service
  kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never --namespace=grafana -- \
    curl -s "http://grafana.grafana.svc.cluster.local:3000/api/health" 2>/dev/null || true
fi

# 7. Check Prometheus targets
echo ""
echo "=== Prometheus Targets ==="
kubectl exec -n prometheus -it $(kubectl get pod -n prometheus -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}') -- \
  wget -qO- "http://localhost:9090/api/v1/targets" 2>/dev/null | head -c 500 || echo "Could not fetch Prometheus targets"

# 8. Check S3 Buckets
echo ""
echo "=== S3 Buckets ==="
S3_BUCKETS=$(terraform output -json s3_buckets 2>/dev/null || echo "{}")
echo "$S3_BUCKETS" | jq -r 'to_entries[] | "\(.key): \(.value)"' 2>/dev/null || echo "Could not list S3 buckets"

# 9. Check IAM Roles
echo ""
echo "=== IAM Roles ==="
IAM_ROLES=$(terraform output -json iam_role_arns 2>/dev/null || echo "{}")
echo "$IAM_ROLES" | jq -r 'to_entries[] | "\(.key): \(.value)"' 2>/dev/null || echo "Could not list IAM roles"

echo ""
echo "=== Validation Complete ==="
```

### 5.2 Component-Specific Checks

**Grafana:**

```bash
# Check Grafana pod logs
kubectl logs -n grafana -l app.kubernetes.io/name=grafana --tail=50

# Verify datasources are configured
kubectl exec -n grafana -it $(kubectl get pod -n grafana -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}') -- \
  grafana-cli admin data-sources
```

**Prometheus:**

```bash
# Check Prometheus pod status
kubectl get pods -n prometheus

# Verify ServiceMonitors
kubectl get servicemonitors -A

# Check Prometheus rules
kubectl get prometheusrules -A
```

**Loki:**

```bash
# Check Loki pods
kubectl get pods -n loki

# Test Loki is receiving logs
kubectl exec -n loki -it $(kubectl get pod -n loki -l app.kubernetes.io/component=read -o jsonpath='{.items[0].metadata.name}') -- \
  wget -qO- "http://localhost:3100/ready"
```

**S3 Bucket Access:**

```bash
# Verify IRSA is working - check pods can access S3
kubectl exec -n loki -it $(kubectl get pod -n loki -l app.kubernetes.io/component=write -o jsonpath='{.items[0].metadata.name}') -- \
  aws s3 ls s3://${LOKI_BUCKET}/ 2>&1 | head -5
```

### 5.3 Validation Checklist

**AGENT: Mark each item as PASS/FAIL:**

| Check                 | Command                                    | Expected Result           |
| --------------------- | ------------------------------------------ | ------------------------- |
| Grafana pods ready    | `kubectl get pods -n grafana`              | All pods Running          |
| Prometheus pods ready | `kubectl get pods -n prometheus`           | All pods Running          |
| Loki pods ready       | `kubectl get pods -n loki`                 | All pods Running          |
| Ingress created       | `kubectl get ingress -n grafana`           | Ingress with correct host |
| TLS certificate       | `kubectl get certificate -n grafana`       | Ready=True                |
| S3 buckets exist      | `aws s3 ls \| grep observability`          | Buckets listed            |
| IAM roles created     | `aws iam list-roles \| grep observability` | Roles listed              |
| Grafana health        | `curl https://DOMAIN/api/health`           | `{"database":"ok"}`       |

---

## 6. OUTPUTS REFERENCE

| Output                 | Description                   | Example Value                 |
| ---------------------- | ----------------------------- | ----------------------------- |
| `grafana_url`          | Full Grafana URL              | `https://grafana.example.com` |
| `grafana_admin_user`   | Admin username                | `admin`                       |
| `namespace_grafana`    | Grafana namespace             | `grafana`                     |
| `namespace_prometheus` | Prometheus namespace          | `prometheus`                  |
| `namespace_loki`       | Loki namespace                | `loki`                        |
| `s3_buckets`           | S3 bucket names per component | Map of component to bucket    |
| `iam_role_arns`        | IAM role ARNs for IRSA        | Map of component to ARN       |
| `deployment_summary`   | Full deployment info          | JSON object                   |

---

## 7. TROUBLESHOOTING

### 7.1 Common Issues

```yaml
# AGENT: Use this structured troubleshooting guide

issue: "Pods stuck in Pending state"
symptoms:
  - kubectl get pods shows Pending
  - Events show scheduling issues
diagnosis_commands:
  - "kubectl describe pod <POD_NAME> -n <NAMESPACE>"
  - "kubectl get events -n <NAMESPACE> --sort-by='.lastTimestamp'"
common_causes:
  - Insufficient node resources
  - StorageClass not found
  - Node selector mismatch
solutions:
  - cause: "Insufficient resources"
    fix: "Scale node group: aws eks update-nodegroup-config --cluster-name ${EKS} --nodegroup-name ${NG} --scaling-config minSize=3,maxSize=6,desiredSize=3"
  - cause: "StorageClass not found"
    fix: "Create gp3 StorageClass or use gp2: kubectl get storageclass"
  - cause: "PVC not binding"
    fix: "Check PVC: kubectl get pvc -n <NAMESPACE> and ensure StorageClass exists"

---

issue: "Grafana not accessible via domain"
symptoms:
  - curl returns connection refused or timeout
  - Browser shows DNS error
diagnosis_commands:
  - "kubectl get ingress -n grafana -o yaml"
  - "kubectl get svc -n ingress-nginx"
  - "nslookup ${GRAFANA_DOMAIN}"
common_causes:
  - DNS not configured
  - Ingress controller not running
  - Load balancer pending
solutions:
  - cause: "DNS not configured"
    fix: |
      Get Load Balancer hostname:
      kubectl get svc -n ingress-nginx -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

      Create Route53 record:
      aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch '{
        "Changes": [{
          "Action": "UPSERT",
          "ResourceRecordSet": {
            "Name": "${GRAFANA_DOMAIN}",
            "Type": "CNAME",
            "TTL": 300,
            "ResourceRecords": [{"Value": "${LB_HOSTNAME}"}]
          }
        }]
      }'
  - cause: "Ingress controller down"
    fix: "kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller"

---

issue: "TLS certificate not issued"
symptoms:
  - Certificate shows Ready=False
  - Browser shows certificate error
diagnosis_commands:
  - "kubectl get certificate -n grafana"
  - "kubectl describe certificate -n grafana"
  - "kubectl get certificaterequest -n grafana"
  - "kubectl logs -n cert-manager -l app=cert-manager"
common_causes:
  - ClusterIssuer not found
  - DNS challenge failing
  - Rate limiting
solutions:
  - cause: "ClusterIssuer not found"
    fix: |
      Create ClusterIssuer:
      kubectl apply -f - <<EOF
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: letsencrypt-prod
      spec:
        acme:
          server: https://acme-v02.api.letsencrypt.org/directory
          email: admin@example.com
          privateKeySecretRef:
            name: letsencrypt-prod
          solvers:
            - http01:
                ingress:
                  class: nginx
      EOF
  - cause: "DNS challenge failing"
    fix: "Ensure domain resolves to ingress: nslookup ${GRAFANA_DOMAIN}"

---

issue: "IRSA not working - pods can't access S3"
symptoms:
  - Pods can't write to S3
  - "AccessDenied" or "NoCredentialProviders" errors
diagnosis_commands:
  - "kubectl describe pod <POD> -n <NS> | grep -A5 'serviceAccountName'"
  - "kubectl get serviceaccount -n <NS> -o yaml | grep eks.amazonaws.com"
  - "aws iam get-role --role-name <ROLE_NAME> --query 'Role.AssumeRolePolicyDocument'"
common_causes:
  - Missing annotation on ServiceAccount
  - Trust policy mismatch
  - OIDC provider not configured
solutions:
  - cause: "Missing serviceAccountName annotation"
    fix: "Verify SA has eks.amazonaws.com/role-arn annotation"
  - cause: "Trust policy mismatch"
    fix: |
      Verify trust policy:
      aws iam get-role --role-name <ROLE_NAME> --query 'Role.AssumeRolePolicyDocument'
      Ensure it matches: oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:sub
  - cause: "OIDC provider not configured"
    fix: |
      Verify OIDC provider exists:
      aws iam list-open-id-connect-providers | grep ${EKS_CLUSTER_NAME}

---

issue: "Prometheus not scraping targets"
symptoms:
  - Missing metrics in Grafana
  - Targets show as DOWN
diagnosis_commands:
  - "kubectl port-forward -n prometheus svc/prometheus-operated 9090:9090"
  - "curl localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'"
common_causes:
  - ServiceMonitor selector mismatch
  - NetworkPolicy blocking
  - Target pods not running
solutions:
  - cause: "ServiceMonitor not matching"
    fix: "Check ServiceMonitor selectors match service labels"
  - cause: "NetworkPolicy blocking"
    fix: "kubectl get networkpolicy -A and verify Prometheus can reach targets"
```

### 7.2 Log Collection Commands

```bash
# Collect all logs for support
NAMESPACE=grafana
kubectl logs -n $NAMESPACE --all-containers --timestamps -l app.kubernetes.io/instance=grafana > grafana-logs.txt

# Events
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' > events.txt

# Describe all pods
kubectl describe pods -n $NAMESPACE > pod-descriptions.txt
```

---

## APPENDIX A: Variable Reference

| Variable                 | Type   | Required | Default         | Description        |
| ------------------------ | ------ | -------- | --------------- | ------------------ |
| `aws_region`             | string | Yes      | -               | AWS region         |
| `eks_cluster_name`       | string | Yes      | -               | EKS cluster name   |
| `eks_oidc_provider_arn`  | string | Yes      | -               | OIDC Provider ARN  |
| `eks_oidc_provider_url`  | string | Yes      | -               | OIDC Provider URL  |
| `environment`            | string | No       | `production`    | Environment name   |
| `project`                | string | No       | `observability` | Project name       |
| `enable_grafana`         | bool   | No       | `true`          | Enable Grafana     |
| `enable_prometheus`      | bool   | No       | `true`          | Enable Prometheus  |
| `enable_loki`            | bool   | No       | `true`          | Enable Loki        |
| `enable_mimir`           | bool   | No       | `true`          | Enable Mimir       |
| `enable_tempo`           | bool   | No       | `true`          | Enable Tempo       |
| `enable_pyroscope`       | bool   | No       | `true`          | Enable Pyroscope   |
| `grafana_domain`         | string | Yes      | -               | Grafana FQDN       |
| `grafana_admin_password` | string | Yes      | -               | Admin password     |
| `alerting_provider`      | string | No       | `none`          | Alert provider     |
| `ingress_scheme`         | string | No       | `internal`      | Ingress visibility |
| `s3_kms_key_arn`         | string | No       | `""`            | KMS key for S3     |

## APPENDIX B: Sizing Profiles

### Development

```hcl
grafana_resources = {
  requests = { cpu = "100m", memory = "128Mi" }
  limits   = { cpu = "500m", memory = "512Mi" }
}
prometheus_storage_size  = "10Gi"
loki_replicas           = { read = 1, write = 1, backend = 1 }
mimir_replication_factor = 1
```

### Staging

```hcl
grafana_resources = {
  requests = { cpu = "200m", memory = "256Mi" }
  limits   = { cpu = "1000m", memory = "1Gi" }
}
prometheus_storage_size  = "50Gi"
loki_replicas           = { read = 2, write = 2, backend = 2 }
mimir_replication_factor = 2
```

### Production

```hcl
grafana_resources = {
  requests = { cpu = "500m", memory = "512Mi" }
  limits   = { cpu = "2000m", memory = "2Gi" }
}
prometheus_storage_size  = "100Gi"
loki_replicas           = { read = 3, write = 3, backend = 3 }
mimir_replication_factor = 3
```

## APPENDIX C: Estimated Costs (USD/month)

| Profile     | S3 Storage | Data Transfer | Total Estimate |
| ----------- | ---------- | ------------- | -------------- |
| Development | ~$5        | ~$5           | ~$10-20        |
| Staging     | ~$15       | ~$15          | ~$30-50        |
| Production  | ~$50+      | ~$50+         | ~$100-200+     |

_Note: Costs exclude EKS compute, NAT Gateway, and data transfer to internet._

---

**END OF DOCUMENT**
