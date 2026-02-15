# ============================================================
# Helm Release - Mimir
# ============================================================
# Deploys Mimir for long-term metrics storage.
# Supports both AWS S3 and Azure Blob Storage backends.
# ============================================================

resource "helm_release" "mimir" {
  count = var.enable_mimir ? 1 : 0

  name             = "mimir"
  namespace        = local.namespaces.mimir
  repository       = local.helm_repositories.grafana
  chart            = "mimir-distributed"
  version          = var.mimir_chart_version
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true

  # Cloud-conditional values
  values = local.is_aws ? [
    templatefile("${path.module}/templates/mimir-values-aws.yaml.tpl", {
      # IRSA configuration
      mimir_irsa_role_arn = aws_iam_role.irsa["mimir"].arn

      # S3 bucket configuration
      mimir_blocks_bucket = aws_s3_bucket.this["mimir_blocks"].id
      mimir_ruler_bucket  = aws_s3_bucket.this["mimir_ruler"].id
      aws_region          = var.aws_region

      # Retention
      mimir_retention_period = var.mimir_retention_period

      # Replication
      mimir_replication_factor = var.mimir_replication_factor

      # Storage class
      storage_class = var.storage_class

      # Node scheduling
      node_selector = local.node_selector
      tolerations   = local.tolerations
    })
    ] : [
    templatefile("${path.module}/templates/mimir-values-azure.yaml.tpl", {
      # Workload Identity configuration
      mimir_client_id = azurerm_user_assigned_identity.workload_identity["mimir"].client_id

      # Azure Storage configuration
      storage_account_name   = azurerm_storage_account.this[0].name
      mimir_blocks_container = azurerm_storage_container.this["mimir_blocks"].name
      mimir_ruler_container  = azurerm_storage_container.this["mimir_ruler"].name

      # Retention
      mimir_retention_period = var.mimir_retention_period

      # Replication
      mimir_replication_factor = var.mimir_replication_factor

      # Storage class
      storage_class = var.storage_class

      # Node scheduling
      node_selector = local.node_selector
      tolerations   = local.tolerations
    })
  ]

  depends_on = [
    kubernetes_namespace.this,
    kubernetes_limit_range.this,
    kubernetes_service_account.workload_identity,
    # AWS dependencies
    aws_iam_role.irsa,
    aws_iam_role_policy_attachment.irsa_s3,
    aws_s3_bucket.this,
    # Azure dependencies
    azurerm_user_assigned_identity.workload_identity,
    azurerm_federated_identity_credential.workload_identity,
    azurerm_storage_account.this,
    azurerm_storage_container.this,
    azurerm_role_assignment.storage_blob_contributor,
  ]
}
