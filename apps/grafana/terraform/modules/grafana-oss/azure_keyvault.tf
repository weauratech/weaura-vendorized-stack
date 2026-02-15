# ============================================================
# Azure Key Vault - Data Sources
# ============================================================
# References existing secrets in Azure Key Vault.
# Secrets are created and managed externally (manually or via CI/CD).
# Only used when cloud_provider = "azure"
#
# IMPORTANT: These are DATA SOURCES, not managed resources.
# Secret values must be populated manually or via CI/CD.
# ============================================================

# -----------------------------
# Key Vault Data Source
# -----------------------------
data "azurerm_key_vault" "this" {
  count = local.is_azure && var.azure_key_vault_name != "" ? 1 : 0

  name                = var.azure_key_vault_name
  resource_group_name = var.azure_key_vault_resource_group != "" ? var.azure_key_vault_resource_group : var.azure_resource_group_name
}

# -----------------------------
# Teams Webhooks Secret (Data Source)
# -----------------------------
# Stores Microsoft Teams webhooks for different alert channels.
# Expected JSON structure:
# {
#   "general_webhook": "https://outlook.office.com/webhook/...",
#   "critical_webhook": "https://outlook.office.com/webhook/...",
#   "infra_webhook": "https://outlook.office.com/webhook/...",
#   "app_webhook": "https://outlook.office.com/webhook/..."
# }
# These webhooks are used by Grafana Unified Alerting contact points.

data "azurerm_key_vault_secret" "teams_webhooks" {
  count = local.is_azure && local.is_teams && var.azure_keyvault_secret_teams_webhooks != "" ? 1 : 0

  name         = var.azure_keyvault_secret_teams_webhooks
  key_vault_id = data.azurerm_key_vault.this[0].id
}

# -----------------------------
# Grafana Admin Password Secret (Data Source)
# -----------------------------
# Grafana admin password (optional - can use variable directly instead).

data "azurerm_key_vault_secret" "grafana_admin" {
  count = local.is_azure && var.enable_grafana && var.azure_keyvault_secret_grafana_admin != "" ? 1 : 0

  name         = var.azure_keyvault_secret_grafana_admin
  key_vault_id = data.azurerm_key_vault.this[0].id
}

# -----------------------------
# Local values for secret access
# -----------------------------
locals {
  # Teams webhooks from Key Vault (Azure + Teams)
  azure_teams_webhooks = local.is_azure && local.is_teams && length(data.azurerm_key_vault_secret.teams_webhooks) > 0 ? jsondecode(data.azurerm_key_vault_secret.teams_webhooks[0].value) : {}

  # Grafana admin password from Key Vault (optional)
  azure_grafana_admin_password = local.is_azure && length(data.azurerm_key_vault_secret.grafana_admin) > 0 ? data.azurerm_key_vault_secret.grafana_admin[0].value : null

  # Unified secret access (cloud-agnostic)
  grafana_admin_password_resolved = coalesce(
    local.is_aws ? local.aws_grafana_admin_password : null,
    local.is_azure ? local.azure_grafana_admin_password : null,
    var.grafana_admin_password
  )

  # Alerting webhooks (cloud-agnostic)
  alerting_webhooks = local.is_slack ? local.aws_slack_webhooks : (local.is_teams ? local.azure_teams_webhooks : {})
}
