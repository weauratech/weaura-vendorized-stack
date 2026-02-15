# ============================================================
# Helm Release - Grafana
# ============================================================
# Deploys Grafana OSS for visualization and dashboarding.
# Includes datasource configuration, SSO, and ingress setup.
# ============================================================

resource "helm_release" "grafana" {
  count = var.enable_grafana ? 1 : 0

  name             = "grafana"
  namespace        = local.namespaces.grafana
  repository       = local.helm_repositories.grafana
  chart            = "grafana"
  version          = var.grafana_chart_version
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600
  atomic           = true
  cleanup_on_fail  = true

  values = [
    templatefile("${path.module}/templates/grafana-values.yaml.tpl", {
      # Grafana configuration
      grafana_domain     = var.grafana_domain
      grafana_admin_user = var.grafana_admin_user
      grafana_admin_password = local.is_aws ? (
        try(data.aws_secretsmanager_secret_version.grafana_admin[0].secret_string, var.grafana_admin_password)
      ) : var.grafana_admin_password

      # Plugins
      grafana_plugins = var.grafana_plugins

      # Resources
      grafana_resources = var.grafana_resources

      # Storage
      grafana_persistence_enabled = var.grafana_persistence_enabled
      grafana_persistence_size    = var.grafana_storage_size
      grafana_storage_size        = var.grafana_storage_size
      storage_class               = var.storage_class

      # Ingress
      enable_ingress      = var.enable_ingress
      ingress_class       = var.ingress_class
      ingress_annotations = var.ingress_annotations
      enable_tls          = var.enable_tls
      tls_secret_name     = var.tls_secret_name
      cluster_issuer      = var.cluster_issuer

      # SSO / OAuth (template uses grafana_sso_enabled and grafana_google_allowed_domains)
      grafana_sso_enabled            = var.grafana_sso_enabled
      grafana_google_allowed_domains = var.grafana_sso_allowed_domains
      oauth_client_id                = var.grafana_sso_client_id
      oauth_client_secret            = var.grafana_sso_client_secret
      oauth_auth_url                 = var.grafana_oauth_auth_url
      oauth_token_url                = var.grafana_oauth_token_url
      oauth_api_url                  = var.grafana_oauth_api_url
      oauth_role_attribute_path      = var.grafana_oauth_role_attribute_path

      # Datasources
      enable_mimir     = var.enable_mimir
      enable_loki      = var.enable_loki
      enable_tempo     = var.enable_tempo
      enable_pyroscope = var.enable_pyroscope

      # Datasource URLs
      datasource_mimir     = local.datasource_urls.mimir
      datasource_loki      = local.datasource_urls.loki
      datasource_tempo     = local.datasource_urls.tempo
      datasource_pyroscope = local.datasource_urls.pyroscope

      # Namespace references for datasource URLs
      namespace_prometheus = local.namespaces.prometheus
      namespace_mimir      = local.namespaces.mimir
      namespace_loki       = local.namespaces.loki
      namespace_tempo      = local.namespaces.tempo
      namespace_pyroscope  = local.namespaces.pyroscope

      # Cloud provider
      cloud_provider = var.cloud_provider

      # Cloud-specific datasources
      is_aws                = local.is_aws
      is_azure              = local.is_azure
      aws_region            = var.aws_region
      azure_subscription_id = var.azure_subscription_id
      azure_tenant_id       = var.azure_tenant_id
      enable_cloudwatch     = var.enable_cloudwatch_datasource
      enable_azure_monitor  = var.enable_azure_monitor_datasource

      # Unified Alerting
      enable_alerting = var.grafana_enable_alerting

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

# ============================================================
# Grafana Provider Configuration
# ============================================================
# Used for managing Grafana resources (dashboards, alerting, etc.)
# ============================================================

# Note: The Grafana provider configuration is typically done at the
# module consumer level. Here we output the necessary values.
