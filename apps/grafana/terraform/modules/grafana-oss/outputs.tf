# ============================================================
# Outputs - Grafana OSS Module (Multi-Cloud)
# ============================================================
# Module outputs for integration with other systems.
# Provides cloud-agnostic and cloud-specific values.
# ============================================================

# ============================================================
# GRAFANA OUTPUTS
# ============================================================

output "grafana_url" {
  description = "Grafana URL"
  value       = var.enable_grafana ? "https://${var.grafana_domain}" : null
}

output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = var.enable_grafana ? "admin" : null
}

output "grafana_namespace" {
  description = "Kubernetes namespace where Grafana is deployed"
  value       = var.enable_grafana ? local.namespaces.grafana : null
}

output "grafana_helm_release_name" {
  description = "Grafana Helm release name"
  value       = var.enable_grafana ? helm_release.grafana[0].name : null
}

output "grafana_helm_release_version" {
  description = "Grafana Helm chart version deployed"
  value       = var.enable_grafana ? helm_release.grafana[0].version : null
}

# ============================================================
# PROMETHEUS OUTPUTS
# ============================================================

output "prometheus_url" {
  description = "Prometheus internal service URL"
  value       = var.enable_prometheus ? local.datasource_urls.prometheus : null
}

output "prometheus_namespace" {
  description = "Kubernetes namespace where Prometheus is deployed"
  value       = var.enable_prometheus ? local.namespaces.prometheus : null
}

output "prometheus_helm_release_name" {
  description = "Prometheus Helm release name"
  value       = var.enable_prometheus ? helm_release.prometheus[0].name : null
}

# ============================================================
# LOKI OUTPUTS
# ============================================================

output "loki_url" {
  description = "Loki internal service URL"
  value       = var.enable_loki ? local.datasource_urls.loki : null
}

output "loki_namespace" {
  description = "Kubernetes namespace where Loki is deployed"
  value       = var.enable_loki ? local.namespaces.loki : null
}

output "loki_helm_release_name" {
  description = "Loki Helm release name"
  value       = var.enable_loki ? helm_release.loki[0].name : null
}

# ============================================================
# MIMIR OUTPUTS
# ============================================================

output "mimir_url" {
  description = "Mimir internal service URL (query endpoint)"
  value       = var.enable_mimir ? local.datasource_urls.mimir : null
}

output "mimir_push_url" {
  description = "Mimir push endpoint for remote write"
  value       = var.enable_mimir ? local.datasource_urls.mimir_push : null
}

output "mimir_namespace" {
  description = "Kubernetes namespace where Mimir is deployed"
  value       = var.enable_mimir ? local.namespaces.mimir : null
}

output "mimir_helm_release_name" {
  description = "Mimir Helm release name"
  value       = var.enable_mimir ? helm_release.mimir[0].name : null
}

# ============================================================
# TEMPO OUTPUTS
# ============================================================

output "tempo_url" {
  description = "Tempo internal service URL"
  value       = var.enable_tempo ? local.datasource_urls.tempo : null
}

output "tempo_namespace" {
  description = "Kubernetes namespace where Tempo is deployed"
  value       = var.enable_tempo ? local.namespaces.tempo : null
}

output "tempo_helm_release_name" {
  description = "Tempo Helm release name"
  value       = var.enable_tempo ? helm_release.tempo[0].name : null
}

# ============================================================
# PYROSCOPE OUTPUTS
# ============================================================

output "pyroscope_url" {
  description = "Pyroscope internal service URL"
  value       = var.enable_pyroscope ? local.datasource_urls.pyroscope : null
}

output "pyroscope_namespace" {
  description = "Kubernetes namespace where Pyroscope is deployed"
  value       = var.enable_pyroscope ? local.namespaces.pyroscope : null
}

output "pyroscope_helm_release_name" {
  description = "Pyroscope Helm release name"
  value       = var.enable_pyroscope ? helm_release.pyroscope[0].name : null
}

# ============================================================
# DATASOURCE URLS (Consolidated)
# ============================================================

output "datasource_urls" {
  description = "Map of all datasource URLs for Grafana configuration"
  value = {
    prometheus = var.enable_prometheus ? local.datasource_urls.prometheus : null
    mimir      = var.enable_mimir ? local.datasource_urls.mimir : null
    mimir_push = var.enable_mimir ? local.datasource_urls.mimir_push : null
    loki       = var.enable_loki ? local.datasource_urls.loki : null
    tempo      = var.enable_tempo ? local.datasource_urls.tempo : null
    pyroscope  = var.enable_pyroscope ? local.datasource_urls.pyroscope : null
  }
}

# ============================================================
# KUBERNETES OUTPUTS
# ============================================================

output "namespaces" {
  description = "Map of component namespaces"
  value = {
    grafana    = var.enable_grafana ? local.namespaces.grafana : null
    prometheus = var.enable_prometheus ? local.namespaces.prometheus : null
    loki       = var.enable_loki ? local.namespaces.loki : null
    mimir      = var.enable_mimir ? local.namespaces.mimir : null
    tempo      = var.enable_tempo ? local.namespaces.tempo : null
    pyroscope  = var.enable_pyroscope ? local.namespaces.pyroscope : null
  }
}

# ============================================================
# AWS OUTPUTS
# ============================================================

output "aws_s3_bucket_arns" {
  description = "ARNs of S3 buckets created (AWS only)"
  value = local.is_aws ? {
    loki_chunks  = var.enable_loki && var.create_storage ? aws_s3_bucket.this["loki_chunks"].arn : null
    loki_ruler   = var.enable_loki && var.create_storage ? aws_s3_bucket.this["loki_ruler"].arn : null
    mimir_blocks = var.enable_mimir && var.create_storage ? aws_s3_bucket.this["mimir_blocks"].arn : null
    mimir_ruler  = var.enable_mimir && var.create_storage ? aws_s3_bucket.this["mimir_ruler"].arn : null
    tempo        = var.enable_tempo && var.create_storage ? aws_s3_bucket.this["tempo"].arn : null
  } : null
}

output "aws_s3_bucket_names" {
  description = "Names of S3 buckets created (AWS only)"
  value = local.is_aws ? {
    loki_chunks  = var.enable_loki && var.create_storage ? aws_s3_bucket.this["loki_chunks"].id : null
    loki_ruler   = var.enable_loki && var.create_storage ? aws_s3_bucket.this["loki_ruler"].id : null
    mimir_blocks = var.enable_mimir && var.create_storage ? aws_s3_bucket.this["mimir_blocks"].id : null
    mimir_ruler  = var.enable_mimir && var.create_storage ? aws_s3_bucket.this["mimir_ruler"].id : null
    tempo        = var.enable_tempo && var.create_storage ? aws_s3_bucket.this["tempo"].id : null
  } : null
}

output "aws_iam_role_arns" {
  description = "ARNs of IAM roles for IRSA (AWS only)"
  value = local.is_aws ? {
    loki  = var.enable_loki ? aws_iam_role.irsa["loki"].arn : null
    mimir = var.enable_mimir ? aws_iam_role.irsa["mimir"].arn : null
    tempo = var.enable_tempo ? aws_iam_role.irsa["tempo"].arn : null
  } : null
}

# ============================================================
# AZURE OUTPUTS
# ============================================================

output "azure_storage_account_name" {
  description = "Azure Storage Account name (Azure only)"
  value       = local.is_azure && var.create_storage ? azurerm_storage_account.this[0].name : null
}

output "azure_storage_account_id" {
  description = "Azure Storage Account ID (Azure only)"
  value       = local.is_azure && var.create_storage ? azurerm_storage_account.this[0].id : null
}

output "azure_storage_containers" {
  description = "Azure Blob container names (Azure only)"
  value = local.is_azure && var.create_storage ? {
    loki_chunks  = var.enable_loki ? azurerm_storage_container.this["loki_chunks"].name : null
    loki_ruler   = var.enable_loki ? azurerm_storage_container.this["loki_ruler"].name : null
    mimir_blocks = var.enable_mimir ? azurerm_storage_container.this["mimir_blocks"].name : null
    mimir_ruler  = var.enable_mimir ? azurerm_storage_container.this["mimir_ruler"].name : null
    tempo        = var.enable_tempo ? azurerm_storage_container.this["tempo"].name : null
  } : null
}

output "azure_managed_identity_ids" {
  description = "Azure Managed Identity client IDs for Workload Identity (Azure only)"
  value = local.is_azure ? {
    loki  = var.enable_loki ? azurerm_user_assigned_identity.workload_identity["loki"].client_id : null
    mimir = var.enable_mimir ? azurerm_user_assigned_identity.workload_identity["mimir"].client_id : null
    tempo = var.enable_tempo ? azurerm_user_assigned_identity.workload_identity["tempo"].client_id : null
  } : null
}

output "azure_managed_identity_principal_ids" {
  description = "Azure Managed Identity principal IDs (Azure only)"
  value = local.is_azure ? {
    loki  = var.enable_loki ? azurerm_user_assigned_identity.workload_identity["loki"].principal_id : null
    mimir = var.enable_mimir ? azurerm_user_assigned_identity.workload_identity["mimir"].principal_id : null
    tempo = var.enable_tempo ? azurerm_user_assigned_identity.workload_identity["tempo"].principal_id : null
  } : null
}

# ============================================================
# CLOUD-AGNOSTIC STORAGE OUTPUTS
# ============================================================

output "storage_configuration" {
  description = "Cloud-agnostic storage configuration summary"
  value = {
    cloud_provider = var.cloud_provider
    storage_type   = local.is_aws ? "s3" : "azure-blob"
    region         = local.cloud_region

    # Storage identifiers (cloud-specific)
    aws = local.is_aws ? {
      bucket_names = {
        loki_chunks  = var.enable_loki && var.create_storage ? aws_s3_bucket.this["loki_chunks"].id : null
        loki_ruler   = var.enable_loki && var.create_storage ? aws_s3_bucket.this["loki_ruler"].id : null
        mimir_blocks = var.enable_mimir && var.create_storage ? aws_s3_bucket.this["mimir_blocks"].id : null
        mimir_ruler  = var.enable_mimir && var.create_storage ? aws_s3_bucket.this["mimir_ruler"].id : null
        tempo        = var.enable_tempo && var.create_storage ? aws_s3_bucket.this["tempo"].id : null
      }
    } : null

    azure = local.is_azure ? {
      storage_account = var.create_storage ? azurerm_storage_account.this[0].name : null
      containers = {
        loki_chunks  = var.enable_loki && var.create_storage ? azurerm_storage_container.this["loki_chunks"].name : null
        loki_ruler   = var.enable_loki && var.create_storage ? azurerm_storage_container.this["loki_ruler"].name : null
        mimir_blocks = var.enable_mimir && var.create_storage ? azurerm_storage_container.this["mimir_blocks"].name : null
        mimir_ruler  = var.enable_mimir && var.create_storage ? azurerm_storage_container.this["mimir_ruler"].name : null
        tempo        = var.enable_tempo && var.create_storage ? azurerm_storage_container.this["tempo"].name : null
      }
    } : null
  }
}

# ============================================================
# GRAFANA FOLDER OUTPUTS
# ============================================================

output "grafana_folder_uids" {
  description = "UIDs of Grafana folders created"
  value = var.enable_grafana && var.enable_grafana_resources ? {
    infrastructure = grafana_folder.infrastructure[0].uid
    kubernetes     = grafana_folder.kubernetes[0].uid
    applications   = grafana_folder.applications[0].uid
    sre            = grafana_folder.sre[0].uid
    alerts         = grafana_folder.alerts[0].uid
    prometheus     = var.enable_prometheus ? grafana_folder.prometheus[0].uid : null
    loki           = var.enable_loki ? grafana_folder.loki[0].uid : null
    mimir          = var.enable_mimir ? grafana_folder.mimir[0].uid : null
    tempo          = var.enable_tempo ? grafana_folder.tempo[0].uid : null
    pyroscope      = var.enable_pyroscope ? grafana_folder.pyroscope[0].uid : null
    custom         = { for k, v in grafana_folder.custom : k => v.uid }
  } : null
}

# ============================================================
# ALERTING OUTPUTS
# ============================================================

output "alerting_configuration" {
  description = "Alerting configuration summary"
  value = {
    provider            = var.alerting_provider
    enabled             = var.alerting_provider != "none"
    default_contact     = var.alerting_provider != "none" ? local.default_contact_point : null
    notification_policy = var.enable_grafana && var.enable_grafana_resources && var.alerting_provider != "none" ? grafana_notification_policy.main[0].id : null
  }
}

# ============================================================
# HELM RELEASES STATUS
# ============================================================

output "helm_releases" {
  description = "Status of all Helm releases"
  value = {
    grafana = var.enable_grafana ? {
      name      = helm_release.grafana[0].name
      namespace = helm_release.grafana[0].namespace
      version   = helm_release.grafana[0].version
      status    = helm_release.grafana[0].status
    } : null

    prometheus = var.enable_prometheus ? {
      name      = helm_release.prometheus[0].name
      namespace = helm_release.prometheus[0].namespace
      version   = helm_release.prometheus[0].version
      status    = helm_release.prometheus[0].status
    } : null

    loki = var.enable_loki ? {
      name      = helm_release.loki[0].name
      namespace = helm_release.loki[0].namespace
      version   = helm_release.loki[0].version
      status    = helm_release.loki[0].status
    } : null

    mimir = var.enable_mimir ? {
      name      = helm_release.mimir[0].name
      namespace = helm_release.mimir[0].namespace
      version   = helm_release.mimir[0].version
      status    = helm_release.mimir[0].status
    } : null

    tempo = var.enable_tempo ? {
      name      = helm_release.tempo[0].name
      namespace = helm_release.tempo[0].namespace
      version   = helm_release.tempo[0].version
      status    = helm_release.tempo[0].status
    } : null

    pyroscope = var.enable_pyroscope ? {
      name      = helm_release.pyroscope[0].name
      namespace = helm_release.pyroscope[0].namespace
      version   = helm_release.pyroscope[0].version
      status    = helm_release.pyroscope[0].status
    } : null
  }
}

# ============================================================
# MODULE SUMMARY
# ============================================================

output "module_summary" {
  description = "Summary of module deployment"
  value = {
    cloud_provider = var.cloud_provider
    environment    = var.environment
    project        = var.project

    enabled_components = {
      grafana    = var.enable_grafana
      prometheus = var.enable_prometheus
      loki       = var.enable_loki
      mimir      = var.enable_mimir
      tempo      = var.enable_tempo
      pyroscope  = var.enable_pyroscope
    }

    features = {
      storage_created     = var.create_storage
      alerting_enabled    = var.alerting_provider != "none"
      alerting_provider   = var.alerting_provider
      resource_quotas     = var.enable_resource_quotas
      limit_ranges        = var.enable_limit_ranges
      network_policies    = var.enable_network_policies
      sso_enabled         = var.grafana_sso_enabled
      tls_external_secret = var.enable_tls_external_secret
    }

    grafana_url = var.enable_grafana ? "https://${var.grafana_domain}" : null
  }
}
