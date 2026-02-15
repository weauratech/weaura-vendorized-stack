# ============================================================
# Helm Release - Prometheus (kube-prometheus-stack)
# ============================================================
# Deploys kube-prometheus-stack for metrics collection.
# Configures remote write to Mimir for long-term storage.
# ============================================================

resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  name             = "prometheus"
  namespace        = local.namespaces.prometheus
  repository       = local.helm_repositories.prometheus
  chart            = "kube-prometheus-stack"
  version          = var.prometheus_chart_version
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900
  atomic           = false # kube-prometheus-stack can take long to deploy
  cleanup_on_fail  = true

  values = [
    templatefile("${path.module}/templates/prometheus-values.yaml.tpl", {
      # Prometheus configuration
      prometheus_retention      = var.prometheus_retention
      prometheus_retention_size = var.prometheus_retention_size

      # Resources
      prometheus_resources = var.prometheus_resources

      # Storage
      prometheus_storage_size = var.prometheus_storage_size
      storage_class           = var.storage_class

      # Remote write to Mimir
      enable_mimir           = var.enable_mimir
      mimir_remote_write_url = local.datasource_urls.mimir_push
      namespace_mimir        = local.namespaces.mimir

      # AlertManager (disabled - using Grafana Unified Alerting)
      enable_alertmanager = false

      # Grafana (disabled - using separate Grafana deployment)
      enable_grafana = false

      # Node Exporter
      enable_node_exporter = var.prometheus_enable_node_exporter

      # Kube State Metrics
      enable_kube_state_metrics = var.prometheus_enable_kube_state_metrics

      # ServiceMonitor configuration
      service_monitor_selector_labels = var.prometheus_service_monitor_selector

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
