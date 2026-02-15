# ============================================================
# Helm Release - Loki
# ============================================================
# Deploys Loki for log aggregation.
# Supports both AWS S3 and Azure Blob Storage backends.
# ============================================================

resource "helm_release" "loki" {
  count = var.enable_loki ? 1 : 0

  name             = "loki"
  namespace        = local.namespaces.loki
  repository       = local.helm_repositories.grafana
  chart            = "loki"
  version          = var.loki_chart_version
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true

  # Cloud-conditional values
  values = local.is_aws ? [
    templatefile("${path.module}/templates/loki-values-aws.yaml.tpl", {
      # IRSA configuration
      loki_irsa_role_arn = aws_iam_role.irsa["loki"].arn

      # S3 bucket configuration
      loki_chunks_bucket = aws_s3_bucket.this["loki_chunks"].id
      loki_ruler_bucket  = aws_s3_bucket.this["loki_ruler"].id
      aws_region         = var.aws_region

      # Retention
      loki_retention_period = var.loki_retention_period

      # Replicas
      loki_replicas = var.loki_replicas

      # Resources
      loki_resources = var.loki_resources

      # Node scheduling
      node_selector = local.node_selector
      tolerations   = local.tolerations
    })
    ] : [
    templatefile("${path.module}/templates/loki-values-azure.yaml.tpl", {
      # Workload Identity configuration
      loki_client_id = azurerm_user_assigned_identity.workload_identity["loki"].client_id

      # Azure Storage configuration
      storage_account_name  = azurerm_storage_account.this[0].name
      loki_chunks_container = azurerm_storage_container.this["loki_chunks"].name
      loki_ruler_container  = azurerm_storage_container.this["loki_ruler"].name

      # Retention
      loki_retention_period = var.loki_retention_period

      # Replicas
      loki_replicas = var.loki_replicas

      # Resources
      loki_resources = var.loki_resources

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
