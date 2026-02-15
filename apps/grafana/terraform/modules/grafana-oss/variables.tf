# ============================================================
# Variables - Grafana OSS Module (Multi-Cloud)
# ============================================================
# Input variables for the observability module.
# Supports both AWS and Azure cloud providers.
# ============================================================

# ============================================================
# CLOUD PROVIDER SELECTION
# ============================================================

variable "cloud_provider" {
  description = "Cloud provider to deploy to (aws or azure)"
  type        = string

  validation {
    condition     = contains(["aws", "azure"], var.cloud_provider)
    error_message = "cloud_provider must be 'aws' or 'azure'."
  }
}

# ============================================================
# COMPONENT TOGGLES
# ============================================================

variable "enable_grafana" {
  description = "Enable Grafana deployment"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Enable Prometheus (kube-prometheus-stack) deployment"
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Enable Loki deployment"
  type        = bool
  default     = true
}

variable "enable_mimir" {
  description = "Enable Mimir deployment"
  type        = bool
  default     = true
}

variable "enable_tempo" {
  description = "Enable Tempo deployment"
  type        = bool
  default     = true
}

variable "enable_pyroscope" {
  description = "Enable Pyroscope deployment"
  type        = bool
  default     = true
}

variable "enable_resource_quotas" {
  description = "Enable Kubernetes ResourceQuotas for each namespace. Disabled by default to avoid conflicts with Helm atomic deployments."
  type        = bool
  default     = false
}

variable "enable_limit_ranges" {
  description = "Enable Kubernetes LimitRanges for each namespace"
  type        = bool
  default     = true
}

variable "enable_network_policies" {
  description = "Enable Kubernetes NetworkPolicies for each namespace"
  type        = bool
  default     = true
}

# ============================================================
# ENVIRONMENT & NAMING
# ============================================================

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "project" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "observability"
}

variable "name_prefix" {
  description = "Prefix for all resource names (defaults to project name)"
  type        = string
  default     = ""
}

# ============================================================
# AWS CONFIGURATION
# ============================================================

variable "aws_region" {
  description = "AWS region (required when cloud_provider is 'aws')"
  type        = string
  default     = "us-east-1"
}

variable "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA (required when cloud_provider is 'aws')"
  type        = string
  default     = ""
}

variable "eks_oidc_provider_url" {
  description = "EKS OIDC provider URL without https:// (required when cloud_provider is 'aws')"
  type        = string
  default     = ""
}

variable "eks_cluster_name" {
  description = "EKS cluster name (required when cloud_provider is 'aws')"
  type        = string
  default     = ""
}

# ============================================================
# AZURE CONFIGURATION
# ============================================================

variable "azure_resource_group_name" {
  description = "Azure resource group name (required when cloud_provider is 'azure')"
  type        = string
  default     = ""
}

variable "azure_location" {
  description = "Azure location/region (required when cloud_provider is 'azure')"
  type        = string
  default     = "eastus"
}

variable "aks_cluster_name" {
  description = "AKS cluster name (required when cloud_provider is 'azure')"
  type        = string
  default     = ""
}

variable "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL for Workload Identity (required when cloud_provider is 'azure')"
  type        = string
  default     = ""
}

variable "azure_tenant_id" {
  description = "Azure tenant ID (required when cloud_provider is 'azure')"
  type        = string
  default     = ""
}

variable "azure_subscription_id" {
  description = "Azure subscription ID (required when cloud_provider is 'azure')"
  type        = string
  default     = ""
}

# ============================================================
# STORAGE CONFIGURATION
# ============================================================

variable "create_storage" {
  description = "Create storage resources (S3 buckets for AWS, Blob containers for Azure)"
  type        = bool
  default     = true
}

variable "storage_class" {
  description = "Kubernetes StorageClass for persistent volumes"
  type        = string
  default     = "gp3"
}

# AWS S3 Bucket Names
variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket names (AWS only)"
  type        = string
  default     = ""
}

variable "s3_kms_key_arn" {
  description = "KMS key ARN for S3 bucket encryption. If empty, uses AES256 (AWS-managed keys). Providing a CMK improves security posture."
  type        = string
  default     = ""
}

variable "s3_buckets" {
  description = "S3 bucket names for each component (AWS only, optional if create_storage is true)"
  type = object({
    loki_chunks  = optional(string, "")
    loki_ruler   = optional(string, "")
    mimir_blocks = optional(string, "")
    mimir_ruler  = optional(string, "")
    tempo        = optional(string, "")
  })
  default = {}
}

# Azure Storage Configuration
variable "azure_storage_account_name" {
  description = "Azure storage account name (Azure only, auto-generated if empty)"
  type        = string
  default     = ""
}

variable "azure_storage_container_prefix" {
  description = "Prefix for Azure Blob container names (Azure only)"
  type        = string
  default     = ""
}

variable "azure_storage_replication_type" {
  description = "Azure storage account replication type (Azure only)"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.azure_storage_replication_type)
    error_message = "Replication type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "azure_storage_enable_lifecycle" {
  description = "Enable lifecycle management policies for Azure storage (Azure only)"
  type        = bool
  default     = true
}

# ============================================================
# SECRETS CONFIGURATION
# ============================================================

# AWS Secrets Manager
variable "aws_secrets_path_prefix" {
  description = "Prefix for AWS Secrets Manager paths (AWS only)"
  type        = string
  default     = ""
}

variable "aws_secrets_path_slack_webhooks" {
  description = "AWS Secrets Manager path for Slack webhooks (AWS + Slack only)"
  type        = string
  default     = ""
}

variable "aws_secrets_path_grafana_admin" {
  description = "AWS Secrets Manager path for Grafana admin password (AWS only)"
  type        = string
  default     = ""
}

# Azure Key Vault
variable "azure_key_vault_name" {
  description = "Azure Key Vault name for secrets (Azure only)"
  type        = string
  default     = ""
}

variable "azure_key_vault_resource_group" {
  description = "Resource group containing the Azure Key Vault (Azure only, defaults to azure_resource_group_name)"
  type        = string
  default     = ""
}

variable "azure_keyvault_secret_teams_webhooks" {
  description = "Azure Key Vault secret name for Teams webhooks (Azure + Teams only)"
  type        = string
  default     = ""
}

variable "azure_keyvault_secret_grafana_admin" {
  description = "Azure Key Vault secret name for Grafana admin password (Azure only)"
  type        = string
  default     = ""
}

# ============================================================
# GRAFANA CONFIGURATION
# ============================================================

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_persistence_enabled" {
  description = "Enable persistent storage for Grafana"
  type        = bool
  default     = true
}

variable "grafana_chart_version" {
  description = "Grafana Helm chart version"
  type        = string
  default     = "10.3.1"
}

variable "grafana_domain" {
  description = "Grafana domain for ingress"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.grafana_domain))
    error_message = "Grafana domain must be a valid DNS hostname."
  }
}

variable "grafana_base_url" {
  description = "Base URL for Grafana (for alert action links). Defaults to https://<grafana_domain>"
  type        = string
  default     = ""
}

variable "grafana_storage_size" {
  description = "Grafana PVC size"
  type        = string
  default     = "40Gi"

  validation {
    condition     = can(regex("^[0-9]+(Mi|Gi|Ti)$", var.grafana_storage_size))
    error_message = "Storage size must be in Kubernetes format (e.g., '512Mi', '40Gi', '1Ti')."
  }
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_plugins" {
  description = "List of Grafana plugins to install"
  type        = list(string)
  default     = ["grafana-pyroscope-app", "grafana-clock-panel"]
}

variable "grafana_node_selector" {
  description = "Node selector for Grafana pods"
  type        = map(string)
  default     = {}
}

variable "grafana_resources" {
  description = "Resource requests and limits for Grafana"
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
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

# ============================================================
# GRAFANA SSO CONFIGURATION
# ============================================================

variable "grafana_sso_enabled" {
  description = "Enable SSO authentication for Grafana"
  type        = bool
  default     = false
}

variable "grafana_sso_provider" {
  description = "SSO provider (google, azure, okta)"
  type        = string
  default     = "google"

  validation {
    condition     = contains(["google", "azure", "okta"], var.grafana_sso_provider)
    error_message = "SSO provider must be one of: google, azure, okta."
  }
}

variable "grafana_sso_client_id" {
  description = "SSO OAuth Client ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_sso_client_secret" {
  description = "SSO OAuth Client Secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_sso_allowed_domains" {
  description = "Allowed domains for SSO (comma-separated)"
  type        = string
  default     = ""
}

variable "grafana_oauth_auth_url" {
  description = "OAuth authorization URL"
  type        = string
  default     = ""
}

variable "grafana_oauth_token_url" {
  description = "OAuth token URL"
  type        = string
  default     = ""
}

variable "grafana_oauth_api_url" {
  description = "OAuth API/userinfo URL"
  type        = string
  default     = ""
}

variable "grafana_oauth_role_attribute_path" {
  description = "JMESPath expression for role mapping"
  type        = string
  default     = "contains(groups[*], 'admin') && 'Admin' || 'Viewer'"
}

variable "enable_cloudwatch_datasource" {
  description = "Enable CloudWatch datasource in Grafana (AWS only)"
  type        = bool
  default     = false
}

variable "enable_azure_monitor_datasource" {
  description = "Enable Azure Monitor datasource in Grafana (Azure only)"
  type        = bool
  default     = false
}

variable "grafana_enable_alerting" {
  description = "Enable Grafana Unified Alerting"
  type        = bool
  default     = true
}

# ============================================================
# PROMETHEUS CONFIGURATION
# ============================================================

variable "prometheus_chart_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "68.2.1"
}

variable "prometheus_retention" {
  description = "Local retention period for Prometheus"
  type        = string
  default     = "7d"
}

variable "prometheus_retention_size" {
  description = "Maximum size of Prometheus TSDB"
  type        = string
  default     = "50GB"
}

variable "prometheus_enable_node_exporter" {
  description = "Enable node-exporter in kube-prometheus-stack"
  type        = bool
  default     = true
}

variable "prometheus_enable_kube_state_metrics" {
  description = "Enable kube-state-metrics in kube-prometheus-stack"
  type        = bool
  default     = true
}

variable "prometheus_service_monitor_selector" {
  description = "ServiceMonitor selector labels"
  type        = map(string)
  default     = {}
}

variable "prometheus_storage_size" {
  description = "Prometheus PVC size"
  type        = string
  default     = "80Gi"

  validation {
    condition     = can(regex("^[0-9]+(Mi|Gi|Ti)$", var.prometheus_storage_size))
    error_message = "Storage size must be in Kubernetes format."
  }
}

variable "prometheus_resources" {
  description = "Resource requests and limits for Prometheus"
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
      cpu    = "500m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}

# ============================================================
# LOKI CONFIGURATION
# ============================================================

variable "loki_chart_version" {
  description = "Loki Helm chart version"
  type        = string
  default     = "6.48.0"
}

variable "loki_retention_period" {
  description = "Loki log retention period"
  type        = string
  default     = "744h"
}

variable "loki_replicas" {
  description = "Number of replicas for Loki components"
  type = object({
    write   = number
    read    = number
    backend = number
  })
  default = {
    write   = 3
    read    = 3
    backend = 3
  }
}

variable "loki_resources" {
  description = "Resource requests and limits for Loki components"
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
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

# ============================================================
# MIMIR CONFIGURATION
# ============================================================

variable "mimir_chart_version" {
  description = "Mimir Helm chart version"
  type        = string
  default     = "4.1.0"
}

variable "mimir_replication_factor" {
  description = "Replication factor for Mimir ingesters"
  type        = number
  default     = 1
}

variable "mimir_retention_period" {
  description = "Mimir metrics retention period"
  type        = string
  default     = "365d"
}

variable "mimir_resources" {
  description = "Resource requests and limits for Mimir components"
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
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "1Gi"
    }
  }
}

# ============================================================
# TEMPO CONFIGURATION
# ============================================================

variable "tempo_chart_version" {
  description = "Tempo Helm chart version"
  type        = string
  default     = "1.59.0"
}

variable "tempo_retention_period" {
  description = "Tempo traces retention period"
  type        = string
  default     = "168h"
}

variable "tempo_resources" {
  description = "Resource requests and limits for Tempo components"
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
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

# ============================================================
# PYROSCOPE CONFIGURATION
# ============================================================

variable "pyroscope_chart_version" {
  description = "Pyroscope Helm chart version"
  type        = string
  default     = "1.16.0"
}

variable "pyroscope_replicas" {
  description = "Number of Pyroscope replicas"
  type        = number
  default     = 1
}

variable "pyroscope_persistence_size" {
  description = "Pyroscope PVC size"
  type        = string
  default     = "50Gi"
}

variable "pyroscope_enable_alloy" {
  description = "Enable Grafana Alloy agent for Pyroscope"
  type        = bool
  default     = true
}

variable "excluded_profiling_namespaces" {
  description = "List of namespaces to exclude from profiling"
  type        = list(string)
  default     = ["kube-system", "kube-public", "kube-node-lease", "cert-manager", "ingress-nginx"]
}

variable "pyroscope_resources" {
  description = "Resource requests and limits for Pyroscope"
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
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
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
  description = "Cert-manager cluster issuer name"
  type        = string
  default     = "letsencrypt-prod"
}

variable "ingress_class" {
  description = "Ingress class name (e.g., nginx, nginx-private)"
  type        = string
  default     = "nginx"
}

variable "ingress_annotations" {
  description = "Additional annotations for ingress resources"
  type        = map(string)
  default     = {}
}

variable "tls_secret_name" {
  description = "Name of the TLS secret for ingress (if using cert-manager or pre-created secret)"
  type        = string
  default     = ""
}

# External Secrets for TLS (Azure KeyVault / AWS Secrets Manager)
variable "enable_tls_external_secret" {
  description = "Enable creation of ExternalSecret for TLS certificate sync from Azure KeyVault or AWS Secrets Manager"
  type        = bool
  default     = false
}

variable "tls_external_secret_config" {
  description = "Configuration for TLS ExternalSecret"
  type = object({
    cluster_secret_store_name = optional(string, "")
    key_vault_cert_name       = optional(string, "")
    secret_refresh_interval   = optional(string, "1h")
  })
  default = {}
}

# AWS-specific ingress
variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS (AWS ALB ingress only)"
  type        = string
  default     = ""
}

variable "ingress_scheme" {
  description = "ALB scheme - internal or internet-facing (AWS ALB ingress only)"
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["internal", "internet-facing"], var.ingress_scheme)
    error_message = "Ingress scheme must be 'internal' or 'internet-facing'."
  }
}

# ============================================================
# ALERTING CONFIGURATION
# ============================================================

variable "alerting_provider" {
  description = "Alerting provider (slack or teams)"
  type        = string
  default     = "slack"

  validation {
    condition     = contains(["slack", "teams", "none"], var.alerting_provider)
    error_message = "alerting_provider must be 'slack', 'teams', or 'none'."
  }
}

# Slack Configuration
variable "slack_webhook_general" {
  description = "Slack webhook URL for general alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_webhook_critical" {
  description = "Slack webhook URL for critical alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_webhook_infrastructure" {
  description = "Slack webhook URL for infrastructure alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_webhook_application" {
  description = "Slack webhook URL for application alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_channel_general" {
  description = "Slack channel for general alerts"
  type        = string
  default     = "#alerts-general"
}

variable "slack_channel_critical" {
  description = "Slack channel for critical alerts"
  type        = string
  default     = "#alerts-critical"
}

variable "slack_channel_infrastructure" {
  description = "Slack channel for infrastructure alerts"
  type        = string
  default     = "#alerts-infrastructure"
}

variable "slack_channel_application" {
  description = "Slack channel for application alerts"
  type        = string
  default     = "#alerts-application"
}

# Microsoft Teams Configuration
variable "teams_webhook_general" {
  description = "Microsoft Teams webhook URL for general alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "teams_webhook_critical" {
  description = "Microsoft Teams webhook URL for critical alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "teams_webhook_infrastructure" {
  description = "Microsoft Teams webhook URL for infrastructure alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "teams_webhook_application" {
  description = "Microsoft Teams webhook URL for application alerts"
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================
# GRAFANA DASHBOARDS & FOLDERS
# ============================================================

variable "dashboards_path" {
  description = "Path to dashboards directory. If empty, dashboard provisioning is disabled."
  type        = string
  default     = ""
}

variable "grafana_folders" {
  description = "Map of Grafana folders to create. Key is the folder UID."
  type = map(object({
    title            = string
    dashboard_subdir = optional(string, "")
  }))
  default = {}
}

# ============================================================
# TAGS & LABELS
# ============================================================

variable "tags" {
  description = "Additional tags to apply to all cloud resources"
  type        = map(string)
  default     = {}
}

variable "labels" {
  description = "Additional labels to apply to all Kubernetes resources"
  type        = map(string)
  default     = {}
}

# ============================================================
# NODE SCHEDULING CONFIGURATION
# ============================================================

variable "global_node_selector" {
  description = "Node selector applied to all observability components"
  type        = map(string)
  default     = {}
}

variable "global_tolerations" {
  description = "Tolerations applied to all observability components"
  type = list(object({
    key      = string
    operator = string
    value    = optional(string)
    effect   = string
  }))
  default = []
}

# ============================================================
# GRAFANA RESOURCES TOGGLE
# ============================================================

variable "enable_grafana_resources" {
  description = "Enable Grafana resources (folders, alerting, dashboards). Set to false for initial deploy when Grafana is not yet accessible from the pipeline agent."
  type        = bool
  default     = false
}
