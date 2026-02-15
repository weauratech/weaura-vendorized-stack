# ============================================================
# Local Values - Grafana OSS Module (Multi-Cloud)
# ============================================================
# Centralized local values for multi-cloud configuration.
# Provides abstractions for AWS/Azure differences.
# ============================================================

locals {
  # ============================================================
  # CLOUD PROVIDER FLAGS
  # ============================================================
  is_aws   = var.cloud_provider == "aws"
  is_azure = var.cloud_provider == "azure"

  # ============================================================
  # ALERTING PROVIDER FLAGS
  # ============================================================
  is_slack = var.alerting_provider == "slack"
  is_teams = var.alerting_provider == "teams"

  # ============================================================
  # NAMING
  # ============================================================
  name_prefix = var.name_prefix != "" ? var.name_prefix : var.project
  full_name   = "${local.name_prefix}-${var.environment}"

  # ============================================================
  # CLOUD-SPECIFIC CONFIGURATION
  # ============================================================

  # Region/Location
  cloud_region = local.is_aws ? var.aws_region : var.azure_location

  # Cluster name
  cluster_name = local.is_aws ? var.eks_cluster_name : var.aks_cluster_name

  # ============================================================
  # COMPONENT CONFIGURATION
  # ============================================================
  components = {
    grafana = {
      enabled     = var.enable_grafana
      namespace   = "grafana"
      component   = "visualization"
      description = "Grafana OSS - Visualization and dashboarding"
    }
    prometheus = {
      enabled     = var.enable_prometheus
      namespace   = "prometheus"
      component   = "metrics"
      description = "Prometheus - Metrics collection"
    }
    loki = {
      enabled     = var.enable_loki
      namespace   = "loki"
      component   = "logs"
      description = "Loki - Log aggregation system"
    }
    mimir = {
      enabled     = var.enable_mimir
      namespace   = "mimir"
      component   = "metrics-storage"
      description = "Mimir - Long-term metrics storage"
    }
    tempo = {
      enabled     = var.enable_tempo
      namespace   = "tempo"
      component   = "tracing"
      description = "Tempo - Distributed tracing backend"
    }
    pyroscope = {
      enabled     = var.enable_pyroscope
      namespace   = "pyroscope"
      component   = "profiling"
      description = "Pyroscope - Continuous profiling"
    }
  }

  # Filter enabled components
  enabled_components = { for k, v in local.components : k => v if v.enabled }

  # Namespace names for compatibility
  namespaces = { for k, v in local.components : k => v.namespace }

  # ============================================================
  # STORAGE CONFIGURATION
  # ============================================================

  # AWS S3 Bucket Configuration
  s3_buckets_config = {
    loki_chunks = {
      enabled     = var.enable_loki && local.is_aws
      bucket_name = var.s3_buckets.loki_chunks != "" ? var.s3_buckets.loki_chunks : "${local.full_name}-loki-chunks"
      component   = "loki"
      purpose     = "log-chunks"
      lifecycle_days = {
        transition_ia      = 30
        transition_glacier = 90
        expiration         = 365
      }
    }
    loki_ruler = {
      enabled        = var.enable_loki && local.is_aws
      bucket_name    = var.s3_buckets.loki_ruler != "" ? var.s3_buckets.loki_ruler : "${local.full_name}-loki-ruler"
      component      = "loki"
      purpose        = "ruler-storage"
      lifecycle_days = null
    }
    mimir_blocks = {
      enabled     = var.enable_mimir && local.is_aws
      bucket_name = var.s3_buckets.mimir_blocks != "" ? var.s3_buckets.mimir_blocks : "${local.full_name}-mimir-blocks"
      component   = "mimir"
      purpose     = "metrics-blocks"
      lifecycle_days = {
        transition_ia      = 30
        transition_glacier = 90
        expiration         = 730
      }
    }
    mimir_ruler = {
      enabled        = var.enable_mimir && local.is_aws
      bucket_name    = var.s3_buckets.mimir_ruler != "" ? var.s3_buckets.mimir_ruler : "${local.full_name}-mimir-ruler"
      component      = "mimir"
      purpose        = "ruler-storage"
      lifecycle_days = null
    }
    tempo = {
      enabled     = var.enable_tempo && local.is_aws
      bucket_name = var.s3_buckets.tempo != "" ? var.s3_buckets.tempo : "${local.full_name}-tempo"
      component   = "tempo"
      purpose     = "trace-storage"
      lifecycle_days = {
        transition_ia      = 30
        transition_glacier = 90
        expiration         = 180
      }
    }
  }

  enabled_s3_buckets        = { for k, v in local.s3_buckets_config : k => v if v.enabled }
  s3_buckets_with_lifecycle = { for k, v in local.enabled_s3_buckets : k => v if v.lifecycle_days != null }

  # Azure Blob Container Configuration
  azure_storage_account = var.azure_storage_account_name != "" ? var.azure_storage_account_name : replace("${substr(local.name_prefix, 0, 10)}${var.environment}obs", "-", "")

  azure_containers_config = {
    loki_chunks = {
      enabled        = var.enable_loki && local.is_azure
      container_name = var.azure_storage_container_prefix != "" ? "${var.azure_storage_container_prefix}-loki-chunks" : "loki-chunks"
      component      = "loki"
    }
    loki_ruler = {
      enabled        = var.enable_loki && local.is_azure
      container_name = var.azure_storage_container_prefix != "" ? "${var.azure_storage_container_prefix}-loki-ruler" : "loki-ruler"
      component      = "loki"
    }
    mimir_blocks = {
      enabled        = var.enable_mimir && local.is_azure
      container_name = var.azure_storage_container_prefix != "" ? "${var.azure_storage_container_prefix}-mimir-blocks" : "mimir-blocks"
      component      = "mimir"
    }
    mimir_ruler = {
      enabled        = var.enable_mimir && local.is_azure
      container_name = var.azure_storage_container_prefix != "" ? "${var.azure_storage_container_prefix}-mimir-ruler" : "mimir-ruler"
      component      = "mimir"
    }
    tempo = {
      enabled        = var.enable_tempo && local.is_azure
      container_name = var.azure_storage_container_prefix != "" ? "${var.azure_storage_container_prefix}-tempo" : "tempo"
      component      = "tempo"
    }
  }

  enabled_azure_containers = { for k, v in local.azure_containers_config : k => v if v.enabled }

  # ============================================================
  # IRSA / WORKLOAD IDENTITY CONFIGURATION
  # ============================================================

  # Components that need cloud storage access
  storage_components = {
    loki = {
      enabled     = var.enable_loki
      namespace   = "loki"
      bucket_keys = ["loki_chunks", "loki_ruler"]
    }
    mimir = {
      enabled     = var.enable_mimir
      namespace   = "mimir"
      bucket_keys = ["mimir_blocks", "mimir_ruler"]
    }
    tempo = {
      enabled     = var.enable_tempo
      namespace   = "tempo"
      bucket_keys = ["tempo"]
    }
  }

  enabled_storage_components = { for k, v in local.storage_components : k => v if v.enabled }

  # AWS IRSA role names
  irsa_role_names = { for k, v in local.storage_components : k => "${local.full_name}-${k}" }

  # Azure Managed Identity names
  managed_identity_names = { for k, v in local.storage_components : k => "${local.full_name}-${k}" }

  # AWS IRSA - filter by cloud provider
  enabled_irsa = { for k, v in local.enabled_storage_components : k => v if local.is_aws }

  # Azure Workload Identity - filter by cloud provider
  enabled_workload_identities = { for k, v in local.enabled_storage_components : k => v if local.is_azure }

  # ============================================================
  # OIDC PROVIDER (AWS)
  # ============================================================
  oidc_provider_arn = local.is_aws ? var.eks_oidc_provider_arn : ""
  oidc_provider_url = local.is_aws ? replace(var.eks_oidc_provider_url, "https://", "") : ""

  # ============================================================
  # SECRETS PATHS
  # ============================================================
  secrets_paths = {
    slack_webhooks = var.aws_secrets_path_slack_webhooks
    teams_webhooks = var.azure_keyvault_secret_teams_webhooks
    grafana_admin  = var.aws_secrets_path_grafana_admin
  }

  # ============================================================
  # RESOURCE QUOTAS CONFIGURATION
  # ============================================================
  resource_quotas = {
    grafana = {
      requests_cpu    = "4"
      requests_memory = "8Gi"
      limits_cpu      = "8"
      limits_memory   = "16Gi"
      pvcs            = "5"
      services        = "10"
      secrets         = "20"
      configmaps      = "30"
    }
    prometheus = {
      requests_cpu    = "10"
      requests_memory = "20Gi"
      limits_cpu      = "20"
      limits_memory   = "40Gi"
      pvcs            = "10"
      services        = "20"
      secrets         = "30"
      configmaps      = "50"
    }
    loki = {
      requests_cpu    = "20"
      requests_memory = "40Gi"
      limits_cpu      = "40"
      limits_memory   = "80Gi"
      pvcs            = "15"
      services        = "15"
      secrets         = "20"
      configmaps      = "30"
    }
    mimir = {
      requests_cpu    = "30"
      requests_memory = "60Gi"
      limits_cpu      = "60"
      limits_memory   = "120Gi"
      pvcs            = "20"
      services        = "30"
      secrets         = "20"
      configmaps      = "30"
    }
    tempo = {
      requests_cpu    = "10"
      requests_memory = "16Gi"
      limits_cpu      = "20"
      limits_memory   = "32Gi"
      pvcs            = "10"
      services        = "15"
      secrets         = "15"
      configmaps      = "20"
    }
    pyroscope = {
      requests_cpu    = "8"
      requests_memory = "12Gi"
      limits_cpu      = "16"
      limits_memory   = "24Gi"
      pvcs            = "5"
      services        = "10"
      secrets         = "10"
      configmaps      = "15"
    }
  }

  # ============================================================
  # LIMIT RANGES CONFIGURATION
  # ============================================================
  limit_ranges = {
    grafana = {
      default_cpu            = "500m"
      default_memory         = "512Mi"
      default_request_cpu    = "100m"
      default_request_memory = "128Mi"
      min_cpu                = "10m"
      min_memory             = "16Mi"
      max_cpu                = "4"
      max_memory             = "8Gi"
    }
    prometheus = {
      default_cpu            = "500m"
      default_memory         = "512Mi"
      default_request_cpu    = "100m"
      default_request_memory = "128Mi"
      min_cpu                = "10m"
      min_memory             = "16Mi"
      max_cpu                = "8"
      max_memory             = "16Gi"
    }
    loki = {
      default_cpu            = "500m"
      default_memory         = "512Mi"
      default_request_cpu    = "100m"
      default_request_memory = "256Mi"
      min_cpu                = "10m"
      min_memory             = "16Mi"
      max_cpu                = "4"
      max_memory             = "16Gi"
    }
    mimir = {
      default_cpu            = "500m"
      default_memory         = "512Mi"
      default_request_cpu    = "100m"
      default_request_memory = "256Mi"
      min_cpu                = "10m"
      min_memory             = "16Mi"
      max_cpu                = "8"
      max_memory             = "16Gi"
    }
    tempo = {
      default_cpu            = "500m"
      default_memory         = "512Mi"
      default_request_cpu    = "100m"
      default_request_memory = "128Mi"
      min_cpu                = "10m"
      min_memory             = "16Mi"
      max_cpu                = "4"
      max_memory             = "8Gi"
    }
    pyroscope = {
      default_cpu            = "500m"
      default_memory         = "512Mi"
      default_request_cpu    = "100m"
      default_request_memory = "128Mi"
      min_cpu                = "10m"
      min_memory             = "16Mi"
      max_cpu                = "4"
      max_memory             = "8Gi"
    }
  }

  # ============================================================
  # NETWORK POLICY CONFIGURATION
  # ============================================================
  network_policies = {
    grafana = {
      allow_all_namespaces = false
      allowed_namespaces   = ["grafana", "ingress-nginx", "kube-system"]
    }
    prometheus = {
      allow_all_namespaces = true
      allowed_namespaces   = []
    }
    loki = {
      allow_all_namespaces = true
      allowed_namespaces   = []
    }
    mimir = {
      allow_all_namespaces = false
      allowed_namespaces   = ["prometheus", "grafana", "tempo", "mimir"]
    }
    tempo = {
      allow_all_namespaces = true
      allowed_namespaces   = []
    }
    pyroscope = {
      allow_all_namespaces = true
      allowed_namespaces   = []
    }
  }

  # ============================================================
  # DATASOURCE URLs
  # ============================================================
  datasource_urls = {
    prometheus = "http://prometheus-kube-prometheus-prometheus.${local.namespaces.prometheus}.svc.cluster.local:9090"
    mimir      = "http://mimir-nginx.${local.namespaces.mimir}.svc.cluster.local:80/prometheus"
    mimir_push = "http://mimir-nginx.${local.namespaces.mimir}.svc.cluster.local:80/api/v1/push"
    loki       = "http://loki-gateway.${local.namespaces.loki}.svc.cluster.local:80"
    tempo      = "http://tempo-query-frontend.${local.namespaces.tempo}.svc.cluster.local:3200"
    pyroscope  = "http://pyroscope.${local.namespaces.pyroscope}.svc.cluster.local:4040"
  }

  # ============================================================
  # ALERTING CHANNELS
  # ============================================================
  slack_channels = local.is_slack ? {
    general  = var.slack_channel_general
    critical = var.slack_channel_critical
    infra    = var.slack_channel_infrastructure
    app      = var.slack_channel_application
  } : {}

  # ============================================================
  # GRAFANA CONFIGURATION
  # ============================================================
  grafana_base_url = var.grafana_base_url != "" ? var.grafana_base_url : "https://${var.grafana_domain}"

  # ============================================================
  # COMMON LABELS (Kubernetes)
  # ============================================================
  common_labels = merge(var.labels, {
    "app.kubernetes.io/part-of"    = "observability-stack"
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.environment
    "cloud-provider"               = var.cloud_provider
  })

  # ============================================================
  # CLOUD TAGS
  # ============================================================
  default_tags = merge(var.tags, {
    Project       = var.project
    Environment   = var.environment
    ManagedBy     = "terraform"
    CloudProvider = var.cloud_provider
  })

  # ============================================================
  # HELM CHART REPOSITORIES
  # ============================================================
  helm_repositories = {
    grafana    = "https://grafana.github.io/helm-charts"
    prometheus = "https://prometheus-community.github.io/helm-charts"
  }

  # ============================================================
  # NODE SCHEDULING
  # ============================================================
  node_selector = var.global_node_selector
  tolerations   = var.global_tolerations
}
