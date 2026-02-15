# ============================================================
# Azure Identity - Workload Identity for Observability Stack
# ============================================================
# User Assigned Managed Identities and Federated Credentials
# for Loki, Mimir, and Tempo.
# Each component receives a dedicated identity with access to its storage.
# Only created when cloud_provider = "azure"
# ============================================================

# -----------------------------
# User Assigned Managed Identities (for_each)
# -----------------------------
resource "azurerm_user_assigned_identity" "workload_identity" {
  for_each = local.enabled_workload_identities

  name                = local.managed_identity_names[each.key]
  resource_group_name = var.azure_resource_group_name
  location            = var.azure_location

  tags = merge(local.default_tags, {
    Component = each.key
    Namespace = each.value.namespace
  })
}

# -----------------------------
# Federated Identity Credentials (for_each)
# -----------------------------
# Creates federated credentials for each component's service accounts
# to enable Kubernetes workload identity

resource "azurerm_federated_identity_credential" "workload_identity" {
  for_each = local.enabled_workload_identities

  name                = "${each.key}-federated"
  resource_group_name = var.azure_resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload_identity[each.key].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:${each.value.namespace}:${each.key}"
}

# -----------------------------
# Additional Federated Credentials for Component Service Accounts
# -----------------------------
# Some components use multiple service accounts (e.g., loki-read, loki-write, etc.)
# Create additional federated credentials with wildcard pattern

resource "azurerm_federated_identity_credential" "workload_identity_wildcard" {
  for_each = local.enabled_workload_identities

  name                = "${each.key}-federated-all"
  resource_group_name = var.azure_resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload_identity[each.key].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  # Note: Azure doesn't support true wildcards, so we create specific credentials
  # for common sub-components
  subject = "system:serviceaccount:${each.value.namespace}:${each.key}-backend"
}

# Loki-specific additional service accounts
resource "azurerm_federated_identity_credential" "loki_read" {
  count = local.is_azure && var.enable_loki ? 1 : 0

  name                = "loki-federated-read"
  resource_group_name = var.azure_resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload_identity["loki"].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:loki:loki-read"
}

resource "azurerm_federated_identity_credential" "loki_write" {
  count = local.is_azure && var.enable_loki ? 1 : 0

  name                = "loki-federated-write"
  resource_group_name = var.azure_resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload_identity["loki"].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:loki:loki-write"
}

# Mimir-specific additional service accounts
resource "azurerm_federated_identity_credential" "mimir_compactor" {
  count = local.is_azure && var.enable_mimir ? 1 : 0

  name                = "mimir-federated-compactor"
  resource_group_name = var.azure_resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload_identity["mimir"].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:mimir:mimir-compactor"
}

resource "azurerm_federated_identity_credential" "mimir_ingester" {
  count = local.is_azure && var.enable_mimir ? 1 : 0

  name                = "mimir-federated-ingester"
  resource_group_name = var.azure_resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload_identity["mimir"].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:mimir:mimir-ingester"
}

resource "azurerm_federated_identity_credential" "mimir_store_gateway" {
  count = local.is_azure && var.enable_mimir ? 1 : 0

  name                = "mimir-federated-store-gateway"
  resource_group_name = var.azure_resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload_identity["mimir"].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:mimir:mimir-store-gateway"
}

# Tempo-specific additional service accounts
resource "azurerm_federated_identity_credential" "tempo_compactor" {
  count = local.is_azure && var.enable_tempo ? 1 : 0

  name                = "tempo-federated-compactor"
  resource_group_name = var.azure_resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload_identity["tempo"].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:tempo:tempo-compactor"
}

resource "azurerm_federated_identity_credential" "tempo_ingester" {
  count = local.is_azure && var.enable_tempo ? 1 : 0

  name                = "tempo-federated-ingester"
  resource_group_name = var.azure_resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload_identity["tempo"].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:tempo:tempo-ingester"
}
