# ============================================================
# Azure Complete Example - Grafana OSS Module
# ============================================================
# Full observability stack deployment on Azure AKS.
# Includes all components with Microsoft Teams alerting.
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.45"
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

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "azuread" {
  tenant_id = var.azure_tenant_id
}

# Get AKS cluster data
data "azurerm_kubernetes_cluster" "this" {
  name                = var.aks_cluster_name
  resource_group_name = var.azure_resource_group_name
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.this.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
  }
}

provider "grafana" {
  url  = "https://${var.grafana_domain}"
  auth = "${var.grafana_admin_user}:${var.grafana_admin_password}"
}

# ============================================================
# VARIABLES
# ============================================================

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "azure_resource_group_name" {
  description = "Azure resource group name"
  type        = string
}

variable "azure_location" {
  description = "Azure location"
  type        = string
  default     = "eastus"
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

variable "aks_cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL"
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

variable "teams_webhook_general" {
  description = "Teams webhook for general alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "teams_webhook_critical" {
  description = "Teams webhook for critical alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "teams_webhook_infrastructure" {
  description = "Teams webhook for infrastructure alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "teams_webhook_application" {
  description = "Teams webhook for application alerts"
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
  cloud_provider = "azure"

  # Environment
  environment = var.environment
  project     = var.project

  # Azure Configuration
  azure_subscription_id     = var.azure_subscription_id
  azure_tenant_id           = var.azure_tenant_id
  azure_resource_group_name = var.azure_resource_group_name
  azure_location            = var.azure_location
  aks_cluster_name          = var.aks_cluster_name
  aks_oidc_issuer_url       = var.aks_oidc_issuer_url

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
  grafana_plugins        = ["grafana-pyroscope-app", "grafana-clock-panel", "grafana-piechart-panel", "grafana-azure-monitor-datasource"]

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

  # Alerting (Microsoft Teams)
  alerting_provider            = "teams"
  teams_webhook_general        = var.teams_webhook_general
  teams_webhook_critical       = var.teams_webhook_critical
  teams_webhook_infrastructure = var.teams_webhook_infrastructure
  teams_webhook_application    = var.teams_webhook_application

  # Kubernetes features
  enable_resource_quotas  = true
  enable_limit_ranges     = true
  enable_network_policies = true

  # Storage configuration
  create_storage                 = true
  azure_storage_replication_type = "ZRS"
  storage_class                  = "managed-premium"

  # Ingress
  ingress_class = "nginx"

  # Custom folders
  grafana_folders = {
    "azure-dashboards" = {
      title = "Azure Dashboards"
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

output "storage_account" {
  description = "Azure Storage Account name"
  value       = module.grafana_oss.azure_storage_account_name
}

output "storage_containers" {
  description = "Azure Blob container names"
  value       = module.grafana_oss.azure_storage_containers
}

output "managed_identity_ids" {
  description = "Managed Identity client IDs"
  value       = module.grafana_oss.azure_managed_identity_ids
}

output "module_summary" {
  description = "Module deployment summary"
  value       = module.grafana_oss.module_summary
}
