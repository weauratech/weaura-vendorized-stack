# ============================================================
# Helm Release - Pyroscope
# ============================================================
# Deploys Pyroscope for continuous profiling.
# Cloud-agnostic deployment using local storage.
# ============================================================

resource "helm_release" "pyroscope" {
  count = var.enable_pyroscope ? 1 : 0

  name             = "pyroscope"
  namespace        = local.namespaces.pyroscope
  repository       = local.helm_repositories.grafana
  chart            = "pyroscope"
  version          = var.pyroscope_chart_version
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true

  values = [
    templatefile("${path.module}/templates/pyroscope-values.yaml.tpl", {
      # Resources
      pyroscope_resources = var.pyroscope_resources

      # Replicas
      pyroscope_replicas = var.pyroscope_replicas

      # Storage
      pyroscope_persistence_size = var.pyroscope_persistence_size
      storage_class              = var.storage_class

      # Alloy (agent) configuration
      enable_alloy                  = var.pyroscope_enable_alloy
      excluded_profiling_namespaces = var.excluded_profiling_namespaces
      namespace_pyroscope           = local.namespaces.pyroscope

      # Node scheduling
      node_selector = local.node_selector
      tolerations   = local.tolerations
    })
  ]

  depends_on = [
    kubernetes_namespace.this,
    kubernetes_limit_range.this,
  ]
}
