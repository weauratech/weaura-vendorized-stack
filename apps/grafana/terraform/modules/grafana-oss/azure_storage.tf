# ============================================================
# Azure Storage - Observability Stack Storage
# ============================================================
# Storage Account and Blob Containers for Loki, Mimir, and Tempo.
# Each component uses dedicated containers.
# Only created when cloud_provider = "azure"
# ============================================================

# -----------------------------
# Storage Account
# -----------------------------
resource "azurerm_storage_account" "this" {
  count = local.is_azure && length(local.enabled_azure_containers) > 0 ? 1 : 0

  name                     = local.azure_storage_account
  resource_group_name      = var.azure_resource_group_name
  location                 = var.azure_location
  account_tier             = "Standard"
  account_replication_type = var.azure_storage_replication_type
  account_kind             = "StorageV2"

  # Enable hierarchical namespace for better performance with observability workloads
  is_hns_enabled = true

  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true

  # Blob properties for observability data
  # Note: versioning_enabled must be false when is_hns_enabled is true (ADLS Gen2)
  blob_properties {
    versioning_enabled = false

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = merge(local.default_tags, {
    Purpose = "observability-storage"
  })
}

# -----------------------------
# Blob Containers (for_each)
# -----------------------------
resource "azurerm_storage_container" "this" {
  for_each = local.enabled_azure_containers

  name                  = each.value.container_name
  storage_account_name  = azurerm_storage_account.this[0].name
  container_access_type = "private"
}

# -----------------------------
# Role Assignments - Storage Blob Data Contributor
# -----------------------------
# Grant each managed identity access to its containers

resource "azurerm_role_assignment" "storage_blob_contributor" {
  for_each = local.enabled_workload_identities

  scope                = azurerm_storage_account.this[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.workload_identity[each.key].principal_id
}

# -----------------------------
# Management Policy for Lifecycle (optional)
# -----------------------------
resource "azurerm_storage_management_policy" "this" {
  count = local.is_azure && length(local.enabled_azure_containers) > 0 && var.azure_storage_enable_lifecycle ? 1 : 0

  storage_account_id = azurerm_storage_account.this[0].id

  # Loki chunks lifecycle
  dynamic "rule" {
    for_each = var.enable_loki && local.is_azure ? [1] : []
    content {
      name    = "loki-chunks-lifecycle"
      enabled = true

      filters {
        prefix_match = ["loki-chunks/"]
        blob_types   = ["blockBlob"]
      }

      actions {
        base_blob {
          tier_to_cool_after_days_since_modification_greater_than    = 30
          tier_to_archive_after_days_since_modification_greater_than = 90
          delete_after_days_since_modification_greater_than          = 365
        }
        snapshot {
          delete_after_days_since_creation_greater_than = 30
        }
        version {
          delete_after_days_since_creation = 30
        }
      }
    }
  }

  # Mimir blocks lifecycle
  dynamic "rule" {
    for_each = var.enable_mimir && local.is_azure ? [1] : []
    content {
      name    = "mimir-blocks-lifecycle"
      enabled = true

      filters {
        prefix_match = ["mimir-blocks/"]
        blob_types   = ["blockBlob"]
      }

      actions {
        base_blob {
          tier_to_cool_after_days_since_modification_greater_than    = 30
          tier_to_archive_after_days_since_modification_greater_than = 90
          delete_after_days_since_modification_greater_than          = 730
        }
        snapshot {
          delete_after_days_since_creation_greater_than = 30
        }
        version {
          delete_after_days_since_creation = 30
        }
      }
    }
  }

  # Tempo traces lifecycle
  dynamic "rule" {
    for_each = var.enable_tempo && local.is_azure ? [1] : []
    content {
      name    = "tempo-traces-lifecycle"
      enabled = true

      filters {
        prefix_match = ["tempo/"]
        blob_types   = ["blockBlob"]
      }

      actions {
        base_blob {
          tier_to_cool_after_days_since_modification_greater_than    = 30
          tier_to_archive_after_days_since_modification_greater_than = 90
          delete_after_days_since_modification_greater_than          = 180
        }
        snapshot {
          delete_after_days_since_creation_greater_than = 30
        }
        version {
          delete_after_days_since_creation = 30
        }
      }
    }
  }
}
