# Azure Deployment Guide: Grafana OSS Observability Stack

```yaml
# METADATA - AI AGENT PARSING CONTEXT
document_type: ai-agent-deployment-guide
cloud_provider: azure
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

| Resource                 | Requirement                        | How to Verify                           |
| ------------------------ | ---------------------------------- | --------------------------------------- |
| AKS Cluster              | Kubernetes 1.27+ with OIDC enabled | `az aks show --query kubernetesVersion` |
| Resource Group           | Existing or new                    | `az group show --name <RG_NAME>`        |
| Azure Subscription       | Contributor permissions            | `az account show`                       |
| NGINX Ingress Controller | Installed in cluster               | `kubectl get pods -n ingress-nginx`     |
| cert-manager             | Installed for TLS                  | `kubectl get pods -n cert-manager`      |
| StorageClass             | `managed-csi` or equivalent        | `kubectl get storageclass`              |

### 1.2 Required Permissions

The executing identity (user or service principal) needs:

| Azure Role                | Scope                | Purpose                                    |
| ------------------------- | -------------------- | ------------------------------------------ |
| Contributor               | Resource Group       | Create Storage Account, Managed Identities |
| Key Vault Secrets Officer | Key Vault (if using) | Read secrets for webhooks                  |
| AKS Cluster Admin         | AKS Cluster          | Deploy Helm charts                         |

### 1.3 Required Tools

| Tool      | Minimum Version | Install Command          |
| --------- | --------------- | ------------------------ |
| terraform | 1.5.0           | `brew install terraform` |
| kubectl   | 1.27            | `brew install kubectl`   |
| az cli    | 2.50            | `brew install azure-cli` |
| helm      | 3.12            | `brew install helm`      |

### 1.4 Prerequisite Validation Commands

```bash
# AGENT: Execute these commands to validate prerequisites
# All commands must succeed before proceeding

# 1. Verify Azure CLI authentication
az account show --query "{subscriptionId:id, tenantId:tenantId, name:name}" -o json

# 2. Verify AKS cluster access
az aks show --resource-group "${RESOURCE_GROUP}" --name "${AKS_CLUSTER_NAME}" --query "{name:name, kubernetesVersion:kubernetesVersion, oidcIssuerEnabled:oidcIssuerProfile.enabled}" -o json

# 3. Get OIDC Issuer URL (required for Workload Identity)
az aks show --resource-group "${RESOURCE_GROUP}" --name "${AKS_CLUSTER_NAME}" --query "oidcIssuerProfile.issuerUrl" -o tsv

# 4. Verify kubectl context
kubectl cluster-info

# 5. Verify NGINX Ingress Controller
kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# 6. Verify cert-manager
kubectl get pods -n cert-manager

# 7. Verify StorageClass exists
kubectl get storageclass managed-csi

# 8. Verify Terraform version
terraform version
```

**AGENT DECISION POINT - Missing Prerequisites:**
If any prerequisite check fails, present these options to the user:

| Missing Component | Options                                                           |
| ----------------- | ----------------------------------------------------------------- |
| NGINX Ingress     | 1. Install now (provide Helm command) 2. Skip and configure later |
| cert-manager      | 1. Install now (provide Helm command) 2. Disable TLS              |
| OIDC not enabled  | 1. Enable OIDC on AKS (requires cluster update)                   |

---

## 2. INFORMATION GATHERING

### 2.1 Required Information

**AGENT: Ask the user each question below. All fields in this section are REQUIRED.**

| Variable                    | Question to Ask User                                                     | Type   | Validation                       |
| --------------------------- | ------------------------------------------------------------------------ | ------ | -------------------------------- |
| `azure_subscription_id`     | "What is your Azure Subscription ID?"                                    | string | UUID format                      |
| `azure_tenant_id`           | "What is your Azure Tenant ID (Azure AD)?"                               | string | UUID format                      |
| `azure_resource_group_name` | "What is the name of your Azure Resource Group?"                         | string | Non-empty                        |
| `azure_location`            | "Which Azure region/location? (e.g., eastus, westeurope)"                | string | Valid Azure region               |
| `aks_cluster_name`          | "What is the name of your AKS cluster?"                                  | string | Non-empty                        |
| `aks_oidc_issuer_url`       | "What is the OIDC Issuer URL for your AKS cluster?"                      | string | URL starting with https://       |
| `grafana_domain`            | "What domain will Grafana be accessible at? (e.g., grafana.example.com)" | string | Valid FQDN                       |
| `grafana_admin_password`    | "Set the Grafana admin password (min 12 characters):"                    | string | min 12 chars                     |
| `environment`               | "Which environment is this? (dev/staging/production)"                    | string | One of: dev, staging, production |
| `project`                   | "What is the project name? (used for resource naming)"                   | string | Alphanumeric with hyphens        |

**AGENT: Auto-retrieve these values if possible:**

```bash
# Get Subscription ID
az account show --query id -o tsv

# Get Tenant ID
az account show --query tenantId -o tsv

# Get OIDC Issuer URL
az aks show --resource-group "${RESOURCE_GROUP}" --name "${AKS_CLUSTER_NAME}" --query "oidcIssuerProfile.issuerUrl" -o tsv
```

### 2.2 Optional Configuration

**AGENT: Present these as optional customizations. Use defaults if user doesn't specify.**

| Variable                     | Question                                                                    | Default            | Notes                                                       |
| ---------------------------- | --------------------------------------------------------------------------- | ------------------ | ----------------------------------------------------------- |
| `azure_storage_account_name` | "Storage account name for long-term data? (leave empty for auto-generated)" | Auto-generated     | Must be globally unique, 3-24 chars, lowercase alphanumeric |
| `storage_class`              | "Which StorageClass for persistent volumes?"                                | `managed-csi`      | Must exist in cluster                                       |
| `grafana_chart_version`      | "Grafana Helm chart version?"                                               | `8.12.1`           |                                                             |
| `prometheus_chart_version`   | "Prometheus chart version?"                                                 | `72.6.2`           |                                                             |
| `cluster_issuer`             | "cert-manager ClusterIssuer name?"                                          | `letsencrypt-prod` |                                                             |
| `ingress_class`              | "Ingress class name?"                                                       | `nginx`            |                                                             |

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
  - id: azure_ad
    label: "Azure AD (Recommended for Azure)"
    description: "Use Azure Active Directory for authentication"
    sets:
      grafana_sso_enabled: true
      grafana_sso_provider: "azuread"
    required_inputs:
      - variable: grafana_sso_client_id
        question: "Azure AD Application (client) ID:"
      - variable: grafana_sso_client_secret
        question: "Azure AD Client secret:"
      - variable: grafana_sso_allowed_domains
        question: "Allowed email domains (comma-separated, e.g., 'company.com,corp.com'):"
  - id: google
    label: "Google Workspace"
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
        question: "Allowed email domains:"
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
  - id: teams
    label: "Microsoft Teams (Recommended for Azure)"
    description: "Send alerts to Teams channels"
    sets:
      alerting_provider: "teams"
    required_inputs:
      - variable: teams_webhook_general
        question: "Teams webhook URL for general alerts:"
      - variable: teams_webhook_critical
        question: "Teams webhook URL for critical alerts (optional, uses general if empty):"
  - id: slack
    label: "Slack"
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
```

#### Decision 5: Ingress Scheme

```yaml
decision: ingress_scheme
question: "Should Grafana be publicly accessible or internal only?"
options:
  - id: internal
    label: "Internal Only (Recommended)"
    description: "Accessible only within private network/VPN"
    sets:
      ingress_scheme: "internal"
  - id: internet_facing
    label: "Internet Facing"
    description: "Publicly accessible (ensure SSO is enabled)"
    sets:
      ingress_scheme: "internet-facing"
```

---

## 3. TERRAFORM CONFIGURATION

### 3.1 Directory Structure

**AGENT: Create this directory structure:**

```bash
mkdir -p observability-azure/{environments/production,modules}
cd observability-azure
```

```
observability-azure/
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
# providers.tf - Azure Provider Configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
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
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "tfstateXXXXXX"
  #   container_name       = "tfstate"
  #   key                  = "observability/terraform.tfstate"
  # }
}

# Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
}

# Azure AD Provider (for Workload Identity)
provider "azuread" {
  tenant_id = var.azure_tenant_id
}

# Data source for AKS cluster
data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = var.azure_resource_group_name
}

# Kubernetes Provider
provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.aks.kube_config[0].host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--login",
      "azurecli",
      "--server-id",
      "6dae42f8-4368-4678-94ff-3960e28e3630" # Azure Kubernetes Service AAD Server
    ]
  }
}

# Helm Provider
provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.aks.kube_config[0].host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--login",
        "azurecli",
        "--server-id",
        "6dae42f8-4368-4678-94ff-3960e28e3630"
      ]
    }
  }
}
```

### 3.3 variables.tf

```hcl
# variables.tf - Input Variables

# ============================================================
# AZURE CONFIGURATION (Required)
# ============================================================

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "azure_resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
}

variable "azure_location" {
  description = "Azure region/location"
  type        = string
  default     = "eastus"
}

variable "aks_cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "AKS OIDC Issuer URL for Workload Identity"
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
  description = "SSO provider (azuread, google, okta)"
  type        = string
  default     = "azuread"
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

# ============================================================
# ALERTING CONFIGURATION
# ============================================================

variable "alerting_provider" {
  description = "Alerting provider (teams, slack, none)"
  type        = string
  default     = "none"
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
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}

variable "ingress_scheme" {
  description = "Ingress scheme (internal or internet-facing)"
  type        = string
  default     = "internal"
}

# ============================================================
# STORAGE CONFIGURATION
# ============================================================

variable "storage_class" {
  description = "Kubernetes StorageClass for PVCs"
  type        = string
  default     = "managed-csi"
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
  cloud_provider = "azure"

  # Azure Configuration
  azure_subscription_id     = var.azure_subscription_id
  azure_tenant_id           = var.azure_tenant_id
  azure_resource_group_name = var.azure_resource_group_name
  azure_location            = var.azure_location
  aks_cluster_name          = var.aks_cluster_name
  aks_oidc_issuer_url       = var.aks_oidc_issuer_url

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

  # Alerting
  alerting_provider      = var.alerting_provider
  teams_webhook_general  = var.teams_webhook_general
  teams_webhook_critical = var.teams_webhook_critical
  slack_webhook_general  = var.slack_webhook_general
  slack_webhook_critical = var.slack_webhook_critical

  # Ingress
  enable_ingress = var.enable_ingress
  enable_tls     = var.enable_tls
  cluster_issuer = var.cluster_issuer
  ingress_class  = var.ingress_class
  ingress_scheme = var.ingress_scheme

  # Storage
  storage_class            = var.storage_class
  prometheus_storage_size  = var.prometheus_storage_size

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

output "storage_account_name" {
  description = "Azure Storage Account name"
  value       = module.observability.azure_storage_account_name
}

output "managed_identity_ids" {
  description = "Managed Identity IDs for each component"
  value       = module.observability.azure_managed_identity_ids
}

output "deployment_summary" {
  description = "Deployment summary"
  value = {
    cloud_provider = "azure"
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
# Generated by AI Agent for Azure deployment

# ============================================================
# AZURE CONFIGURATION
# ============================================================
azure_subscription_id     = "${COLLECTED_azure_subscription_id}"
azure_tenant_id           = "${COLLECTED_azure_tenant_id}"
azure_resource_group_name = "${COLLECTED_azure_resource_group_name}"
azure_location            = "${COLLECTED_azure_location}"
aks_cluster_name          = "${COLLECTED_aks_cluster_name}"
aks_oidc_issuer_url       = "${COLLECTED_aks_oidc_issuer_url}"

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
teams_webhook_general  = "${COLLECTED_teams_webhook_general}"
teams_webhook_critical = "${COLLECTED_teams_webhook_critical}"

# ============================================================
# INGRESS
# ============================================================
enable_ingress = true
enable_tls     = true
cluster_issuer = "letsencrypt-prod"
ingress_class  = "nginx"
ingress_scheme = "${DECISION_ingress_scheme}"

# ============================================================
# STORAGE & SIZING (Based on sizing profile)
# ============================================================
storage_class           = "managed-csi"
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
# Example: Production deployment with full stack and Teams alerting

azure_subscription_id     = "12345678-1234-1234-1234-123456789abc"
azure_tenant_id           = "87654321-4321-4321-4321-cba987654321"
azure_resource_group_name = "rg-observability-prod"
azure_location            = "eastus"
aks_cluster_name          = "aks-prod-eastus"
aks_oidc_issuer_url       = "https://eastus.oic.prod-aks.azure.com/87654321-4321-4321-4321-cba987654321/12345678-1234-1234-1234-123456789abc/"

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
grafana_sso_provider        = "azuread"
grafana_sso_client_id       = "app-client-id-here"
grafana_sso_client_secret   = "app-client-secret-here"
grafana_sso_allowed_domains = "company.com"

alerting_provider      = "teams"
teams_webhook_general  = "https://company.webhook.office.com/webhookb2/..."
teams_webhook_critical = "https://company.webhook.office.com/webhookb2/..."

enable_ingress = true
enable_tls     = true
cluster_issuer = "letsencrypt-prod"
ingress_class  = "nginx"
ingress_scheme = "internal"

storage_class           = "managed-csi"
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
- Azure credentials are valid
- Backend storage account exists (if using remote state)

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
# - azurerm_storage_account (1)
# - azurerm_storage_container (4-6)
# - azurerm_user_assigned_identity (4-6)
# - azurerm_federated_identity_credential (4-6)
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
- Storage Account: ~30 seconds
- Managed Identities: ~30 seconds
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
# Azure Observability Stack Validation

set -e

GRAFANA_DOMAIN="${COLLECTED_grafana_domain}"
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

# 8. Check Storage Account
echo ""
echo "=== Azure Storage Account ==="
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name 2>/dev/null || echo "")
if [ -n "$STORAGE_ACCOUNT" ]; then
  az storage account show --name "$STORAGE_ACCOUNT" --query "{name:name, location:location, sku:sku.name}" -o table
fi

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

### 5.3 Validation Checklist

**AGENT: Mark each item as PASS/FAIL:**

| Check                  | Command                              | Expected Result           |
| ---------------------- | ------------------------------------ | ------------------------- |
| Grafana pods ready     | `kubectl get pods -n grafana`        | All pods Running          |
| Prometheus pods ready  | `kubectl get pods -n prometheus`     | All pods Running          |
| Loki pods ready        | `kubectl get pods -n loki`           | All pods Running          |
| Ingress created        | `kubectl get ingress -n grafana`     | Ingress with correct host |
| TLS certificate        | `kubectl get certificate -n grafana` | Ready=True                |
| Storage account exists | `az storage account show`            | Account exists            |
| Grafana health         | `curl https://DOMAIN/api/health`     | `{"database":"ok"}`       |

---

## 6. OUTPUTS REFERENCE

| Output                 | Description            | Example Value                 |
| ---------------------- | ---------------------- | ----------------------------- |
| `grafana_url`          | Full Grafana URL       | `https://grafana.example.com` |
| `grafana_admin_user`   | Admin username         | `admin`                       |
| `namespace_grafana`    | Grafana namespace      | `grafana`                     |
| `namespace_prometheus` | Prometheus namespace   | `prometheus`                  |
| `namespace_loki`       | Loki namespace         | `loki`                        |
| `storage_account_name` | Azure Storage Account  | `obsplatformprod1234`         |
| `managed_identity_ids` | Component identity IDs | Map of component to ID        |
| `deployment_summary`   | Full deployment info   | JSON object                   |

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
    fix: "Scale node pool: az aks nodepool scale --resource-group ${RG} --cluster-name ${AKS} --name agentpool --node-count 3"
  - cause: "StorageClass not found"
    fix: "Create StorageClass or use existing: kubectl get storageclass"
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
      Get Load Balancer IP:
      kubectl get svc -n ingress-nginx -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'

      Create DNS record in Azure DNS:
      az network dns record-set a add-record --resource-group ${DNS_RG} --zone-name ${ZONE} --record-set-name grafana --ipv4-address ${LB_IP}
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

issue: "Workload Identity not working"
symptoms:
  - Pods can't access Azure Storage
  - "DefaultAzureCredential failed" errors
diagnosis_commands:
  - "kubectl describe pod <POD> -n <NS> | grep -A5 'serviceAccountName'"
  - "kubectl get serviceaccount -n <NS> -o yaml"
  - "az identity federated-credential list --identity-name <IDENTITY> --resource-group ${RG}"
common_causes:
  - Missing federated credential
  - Wrong serviceAccountName
  - OIDC issuer mismatch
solutions:
  - cause: "Missing serviceAccountName annotation"
    fix: "Verify SA has azure.workload.identity/client-id annotation"
  - cause: "OIDC issuer mismatch"
    fix: |
      Verify OIDC issuer matches:
      az aks show -g ${RG} -n ${AKS} --query oidcIssuerProfile.issuerUrl -o tsv
      Compare with federated credential subject issuer

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

| Variable                    | Type   | Required | Default         | Description           |
| --------------------------- | ------ | -------- | --------------- | --------------------- |
| `azure_subscription_id`     | string | Yes      | -               | Azure Subscription ID |
| `azure_tenant_id`           | string | Yes      | -               | Azure AD Tenant ID    |
| `azure_resource_group_name` | string | Yes      | -               | Resource Group name   |
| `azure_location`            | string | No       | `eastus`        | Azure region          |
| `aks_cluster_name`          | string | Yes      | -               | AKS cluster name      |
| `aks_oidc_issuer_url`       | string | Yes      | -               | AKS OIDC issuer URL   |
| `environment`               | string | No       | `production`    | Environment name      |
| `project`                   | string | No       | `observability` | Project name          |
| `enable_grafana`            | bool   | No       | `true`          | Enable Grafana        |
| `enable_prometheus`         | bool   | No       | `true`          | Enable Prometheus     |
| `enable_loki`               | bool   | No       | `true`          | Enable Loki           |
| `enable_mimir`              | bool   | No       | `true`          | Enable Mimir          |
| `enable_tempo`              | bool   | No       | `true`          | Enable Tempo          |
| `enable_pyroscope`          | bool   | No       | `true`          | Enable Pyroscope      |
| `grafana_domain`            | string | Yes      | -               | Grafana FQDN          |
| `grafana_admin_password`    | string | Yes      | -               | Admin password        |
| `alerting_provider`         | string | No       | `none`          | Alert provider        |
| `ingress_scheme`            | string | No       | `internal`      | Ingress visibility    |

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

| Profile     | Storage Account | Managed Identities | Total Estimate |
| ----------- | --------------- | ------------------ | -------------- |
| Development | ~$5             | ~$0                | ~$5-10         |
| Staging     | ~$15            | ~$0                | ~$15-25        |
| Production  | ~$50+           | ~$0                | ~$50-100+      |

_Note: Costs exclude AKS compute, network, and data transfer._

---

**END OF DOCUMENT**
