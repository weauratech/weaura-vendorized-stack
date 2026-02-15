# ============================================================
# AWS Complete Example - Grafana OSS Module
# ============================================================
# Full observability stack deployment on AWS EKS.
# Includes all components with Slack alerting.
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }
  }
}

# ============================================================
# PROVIDERS
# ============================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
      ManagedBy   = "terraform"
    }
  }
}

# Get EKS cluster data
data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.eks_cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "grafana" {
  url  = "https://${var.grafana_domain}"
  auth = "${var.grafana_admin_user}:${var.grafana_admin_password}"
}

# ============================================================
# VARIABLES
# ============================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "observability"
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "eks_oidc_provider_url" {
  description = "EKS OIDC provider URL"
  type        = string
}

variable "grafana_domain" {
  description = "Grafana domain"
  type        = string
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "slack_webhook_general" {
  description = "Slack webhook for general alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_webhook_critical" {
  description = "Slack webhook for critical alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_webhook_infrastructure" {
  description = "Slack webhook for infrastructure alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_webhook_application" {
  description = "Slack webhook for application alerts"
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================
# MODULE
# ============================================================

module "grafana_oss" {
  source = "../../"

  # Cloud provider
  cloud_provider = "aws"

  # Environment
  environment = var.environment
  project     = var.project

  # AWS Configuration
  aws_region            = var.aws_region
  eks_cluster_name      = var.eks_cluster_name
  eks_oidc_provider_arn = var.eks_oidc_provider_arn
  eks_oidc_provider_url = var.eks_oidc_provider_url

  # Enable all components
  enable_grafana    = true
  enable_prometheus = true
  enable_loki       = true
  enable_mimir      = true
  enable_tempo      = true
  enable_pyroscope  = true

  # Grafana configuration
  grafana_domain         = var.grafana_domain
  grafana_admin_password = var.grafana_admin_password
  grafana_storage_size   = "50Gi"
  grafana_plugins        = ["grafana-pyroscope-app", "grafana-clock-panel", "grafana-piechart-panel"]

  grafana_resources = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "2Gi"
    }
  }

  # Prometheus configuration
  prometheus_retention    = "7d"
  prometheus_storage_size = "100Gi"

  prometheus_resources = {
    requests = {
      cpu    = "1000m"
      memory = "4Gi"
    }
    limits = {
      cpu    = "4000m"
      memory = "8Gi"
    }
  }

  # Loki configuration
  loki_replicas = {
    write   = 3
    read    = 3
    backend = 3
  }

  # Mimir configuration
  mimir_replication_factor = 3

  # Alerting (Slack)
  alerting_provider            = "slack"
  slack_webhook_general        = var.slack_webhook_general
  slack_webhook_critical       = var.slack_webhook_critical
  slack_webhook_infrastructure = var.slack_webhook_infrastructure
  slack_webhook_application    = var.slack_webhook_application

  slack_channel_general        = "#alerts-general"
  slack_channel_critical       = "#alerts-critical"
  slack_channel_infrastructure = "#alerts-infrastructure"
  slack_channel_application    = "#alerts-application"

  # Kubernetes features
  enable_resource_quotas  = true
  enable_limit_ranges     = true
  enable_network_policies = true

  # Storage configuration
  create_storage = true
  storage_class  = "gp3"

  # Ingress
  ingress_class  = "nginx"
  ingress_scheme = "internal"

  # Custom folders
  grafana_folders = {
    "custom-dashboards" = {
      title = "Custom Dashboards"
    }
    "slos" = {
      title = "SLO Dashboards"
    }
  }

  # Tags
  tags = {
    Team = "platform"
    Cost = "observability"
  }

  labels = {
    team = "platform"
  }
}

# ============================================================
# OUTPUTS
# ============================================================

output "grafana_url" {
  description = "Grafana URL"
  value       = module.grafana_oss.grafana_url
}

output "datasource_urls" {
  description = "All datasource URLs"
  value       = module.grafana_oss.datasource_urls
}

output "namespaces" {
  description = "Component namespaces"
  value       = module.grafana_oss.namespaces
}

output "s3_bucket_names" {
  description = "S3 bucket names"
  value       = module.grafana_oss.aws_s3_bucket_names
}

output "iam_role_arns" {
  description = "IAM role ARNs for IRSA"
  value       = module.grafana_oss.aws_iam_role_arns
}

output "module_summary" {
  description = "Module deployment summary"
  value       = module.grafana_oss.module_summary
}
