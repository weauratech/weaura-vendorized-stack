# ============================================================
# External Secrets - TLS Certificate
# ============================================================
# Creates an ExternalSecret to sync TLS certificate from
# Azure KeyVault or AWS Secrets Manager to Kubernetes.
# This allows using pre-existing wildcard certificates
# instead of cert-manager.
# ============================================================

resource "kubernetes_manifest" "grafana_tls_external_secret" {
  count = var.enable_tls_external_secret && var.enable_grafana && var.enable_tls ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "grafana-tls-external-secret"
      namespace = kubernetes_namespace.this["grafana"].metadata[0].name
      labels = merge(local.common_labels, {
        "app.kubernetes.io/component" = "tls-certificate"
      })
    }
    spec = {
      refreshInterval = var.tls_external_secret_config.secret_refresh_interval
      secretStoreRef = {
        name = var.tls_external_secret_config.cluster_secret_store_name
        kind = "ClusterSecretStore"
      }
      target = {
        name           = var.tls_secret_name
        creationPolicy = "Owner"
        template = {
          type          = "kubernetes.io/tls"
          engineVersion = "v2"
          data = {
            "tls.crt" = "{{ .certificate }}"
            "tls.key" = "{{ .privatekey }}"
          }
        }
      }
      data = [
        {
          secretKey = "certificate"
          remoteRef = {
            key = "${var.tls_external_secret_config.key_vault_cert_name}-crt"
          }
        },
        {
          secretKey = "privatekey"
          remoteRef = {
            key = "${var.tls_external_secret_config.key_vault_cert_name}-key"
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_namespace.this,
    helm_release.grafana
  ]
}
