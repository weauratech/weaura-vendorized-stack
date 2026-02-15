# ============================================================
# Helm Release - Tempo
# ============================================================
# Deploys Tempo for distributed tracing.
# Supports both AWS S3 and Azure Blob Storage backends.
# ============================================================

resource "helm_release" "tempo" {
  count = var.enable_tempo ? 1 : 0

  name             = "tempo"
  namespace        = local.namespaces.tempo
  repository       = local.helm_repositories.grafana
  chart            = "tempo-distributed"
  version          = var.tempo_chart_version
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true

  # Cloud-conditional values
  values = local.is_aws ? [
    templatefile("${path.module}/templates/tempo-values-aws.yaml.tpl", {
      # IRSA configuration
      tempo_irsa_role_arn = aws_iam_role.irsa["tempo"].arn

      # S3 bucket configuration
      tempo_traces_bucket = aws_s3_bucket.this["tempo"].id
      aws_region          = var.aws_region

      # Retention
      tempo_retention_period = var.tempo_retention_period

      # Resources
      tempo_resources = var.tempo_resources

      # Mimir namespace for metrics generator remote write
      namespace_mimir = local.namespaces.mimir

      # Node scheduling
      node_selector = local.node_selector
      tolerations   = local.tolerations
    })
    ] : [
    templatefile("${path.module}/templates/tempo-values-azure.yaml.tpl", {
      # Workload Identity configuration
      tempo_client_id = azurerm_user_assigned_identity.workload_identity["tempo"].client_id

      # Azure Storage configuration
      storage_account_name   = azurerm_storage_account.this[0].name
      tempo_traces_container = azurerm_storage_container.this["tempo"].name

      # Retention
      tempo_retention_period = var.tempo_retention_period

      # Resources
      tempo_resources = var.tempo_resources

      # Mimir namespace for metrics generator remote write
      namespace_mimir = local.namespaces.mimir

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
    # Mimir should be deployed first for metrics generator
    helm_release.mimir,
  ]
}
