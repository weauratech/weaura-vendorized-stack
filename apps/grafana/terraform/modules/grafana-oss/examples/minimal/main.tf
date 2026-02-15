# ============================================================
# Minimal Example - Grafana OSS Module
# ============================================================
# Minimal deployment with just Grafana and Prometheus.
# Can be used on either AWS or Azure.
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
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

# Note: Configure these providers based on your cloud platform
# See aws-complete or azure-complete examples for full provider setup

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

provider "grafana" {
  url  = "https://${var.grafana_domain}"
  auth = "admin:${var.grafana_admin_password}"
}

# ============================================================
# VARIABLES
# ============================================================

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "cloud_provider" {
  description = "Cloud provider (aws or azure)"
  type        = string
  default     = "aws"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "observability"
}

variable "grafana_domain" {
  description = "Grafana domain"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

# AWS-specific (only needed if cloud_provider = "aws")
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "eks_cluster_name" {
  description = "EKS cluster name (AWS only)"
  type        = string
  default     = ""
}

variable "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN (AWS only)"
  type        = string
  default     = ""
}

variable "eks_oidc_provider_url" {
  description = "EKS OIDC provider URL (AWS only)"
  type        = string
  default     = ""
}

# Azure-specific (only needed if cloud_provider = "azure")
variable "azure_subscription_id" {
  description = "Azure subscription ID (Azure only)"
  type        = string
  default     = ""
}

variable "azure_tenant_id" {
  description = "Azure tenant ID (Azure only)"
  type        = string
  default     = ""
}

variable "azure_resource_group_name" {
  description = "Azure resource group name (Azure only)"
  type        = string
  default     = ""
}

variable "azure_location" {
  description = "Azure location (Azure only)"
  type        = string
  default     = "eastus"
}

variable "aks_cluster_name" {
  description = "AKS cluster name (Azure only)"
  type        = string
  default     = ""
}

variable "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL (Azure only)"
  type        = string
  default     = ""
}

# ============================================================
# MODULE
# ============================================================

module "grafana_oss" {
  source = "../../"

  # Cloud provider
  cloud_provider = var.cloud_provider

  # Environment
  environment = var.environment
  project     = var.project

  # AWS Configuration (conditionally used)
  aws_region            = var.aws_region
  eks_cluster_name      = var.eks_cluster_name
  eks_oidc_provider_arn = var.eks_oidc_provider_arn
  eks_oidc_provider_url = var.eks_oidc_provider_url

  # Azure Configuration (conditionally used)
  azure_subscription_id     = var.azure_subscription_id
  azure_tenant_id           = var.azure_tenant_id
  azure_resource_group_name = var.azure_resource_group_name
  azure_location            = var.azure_location
  aks_cluster_name          = var.aks_cluster_name
  aks_oidc_issuer_url       = var.aks_oidc_issuer_url

  # Enable only Grafana and Prometheus
  enable_grafana    = true
  enable_prometheus = true
  enable_loki       = false
  enable_mimir      = false
  enable_tempo      = false
  enable_pyroscope  = false

  # Grafana configuration
  grafana_domain         = var.grafana_domain
  grafana_admin_password = var.grafana_admin_password
  grafana_storage_size   = "10Gi"

  grafana_resources = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }

  # Prometheus configuration
  prometheus_retention    = "3d"
  prometheus_storage_size = "20Gi"

  prometheus_resources = {
    requests = {
      cpu    = "200m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }

  # Disable alerting for minimal setup
  alerting_provider = "none"

  # Minimal Kubernetes features
  enable_resource_quotas  = false
  enable_limit_ranges     = false
  enable_network_policies = false

  # No object storage needed (local storage only)
  create_storage = false

  # Ingress
  ingress_class = "nginx"

  # Tags
  tags = {
    Environment = var.environment
  }
}

# ============================================================
# OUTPUTS
# ============================================================

output "grafana_url" {
  description = "Grafana URL"
  value       = module.grafana_oss.grafana_url
}

output "prometheus_url" {
  description = "Prometheus internal URL"
  value       = module.grafana_oss.prometheus_url
}

output "namespaces" {
  description = "Component namespaces"
  value       = module.grafana_oss.namespaces
}

output "module_summary" {
  description = "Module deployment summary"
  value       = module.grafana_oss.module_summary
}
