# ============================================================
# MIMIR DISTRIBUTED - AWS S3 CONFIGURATION
# ============================================================
# Based on Grafana's recommended values for small environments
# Targets ~1M series with 15s scrape interval (~66k samples/s)
# Storage: AWS S3 with IRSA authentication
# ============================================================

# ============================================================
# SERVICE ACCOUNT - IRSA for S3 Access
# ============================================================
# IMPORTANT: ServiceAccount is created by Terraform (kubernetes.tf) with
# Helm-compatible labels. This ensures the IRSA annotations are present
# before the Helm chart is installed.
serviceAccount:
  create: false
  name: mimir

# Global configuration
global:
  clusterDomain: cluster.local

# Disable multi-tenancy (single tenant)
multitenancyEnabled: false

# Mimir configuration
mimir:
  structuredConfig:
    # Storage backend - S3
    common:
      storage:
        backend: s3
        s3:
          endpoint: s3.${aws_region}.amazonaws.com
          region: ${aws_region}
          bucket_name: ${mimir_blocks_bucket}

    # Blocks storage (TSDB) - S3
    blocks_storage:
      backend: s3
      s3:
        endpoint: s3.${aws_region}.amazonaws.com
        region: ${aws_region}
        bucket_name: ${mimir_blocks_bucket}
      tsdb:
        dir: /data/tsdb
        ship_interval: 15m
        head_compaction_interval: 5m
        head_compaction_concurrency: 1
        head_compaction_idle_timeout: 1h
        block_ranges_period: ["2h", "12h", "24h"]
        retention_period: ${mimir_retention_period}
        flush_blocks_on_shutdown: true

    # Compactor
    compactor:
      data_dir: /data/compactor
      sharding_ring:
        kvstore:
          store: memberlist
      compaction_interval: 15m
      compaction_concurrency: 1

    # Ruler storage - S3
    ruler_storage:
      backend: s3
      s3:
        endpoint: s3.${aws_region}.amazonaws.com
        region: ${aws_region}
        bucket_name: ${mimir_ruler_bucket}

    # Distributor
    distributor:
      ring:
        kvstore:
          store: memberlist
      pool:
        health_check_ingesters: true

    # Ingester
    ingester:
      ring:
        kvstore:
          store: memberlist
        replication_factor: ${mimir_replication_factor}
        heartbeat_period: 5s
        heartbeat_timeout: 1m

    # Store Gateway
    store_gateway:
      sharding_ring:
        kvstore:
          store: memberlist

    # Querier
    querier:
      timeout: 2m
      max_concurrent: 20

    # Limits - adjusted for production environment
    limits:
      max_global_series_per_user: 3000000
      max_global_series_per_metric: 100000
      ingestion_rate: 200000
      ingestion_burst_size: 400000
      max_label_names_per_series: 50
      max_label_value_length: 2048
      max_query_length: 721h
      max_query_parallelism: 32
      out_of_order_time_window: 1h

# ============================================================
# COMPONENTS - RECOMMENDED SETTINGS FOR SMALL ENV
# ============================================================

# Gateway (nginx)
gateway:
  replicas: 1
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 1
      memory: 731Mi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}

# Distributor - receives metrics from Prometheus
distributor:
  replicas: 2
  resources:
    requests:
      cpu: 1
      memory: 2Gi
    limits:
      cpu: 2
      memory: 4Gi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}

# Ingester - stores metrics in memory
ingester:
  replicas: 3
  persistentVolume:
    enabled: true
    size: 50Gi
    storageClass: ${storage_class}
  resources:
    requests:
      cpu: 1
      memory: 4Gi
    limits:
      cpu: 2
      memory: 8Gi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}
  topologySpreadConstraints: {}
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/component
                  operator: In
                  values:
                    - ingester
            topologyKey: "kubernetes.io/hostname"

# Querier - executes queries
querier:
  replicas: 1
  resources:
    requests:
      cpu: 500m
      memory: 2Gi
    limits:
      cpu: 2
      memory: 4Gi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}

# Query Frontend
query_frontend:
  replicas: 1
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2
      memory: 2Gi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}

# Store Gateway - serves blocks from S3
store_gateway:
  replicas: 3
  persistentVolume:
    enabled: true
    size: 10Gi
    storageClass: ${storage_class}
  resources:
    requests:
      cpu: 250m
      memory: 1Gi
    limits:
      cpu: 1
      memory: 2Gi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}
  topologySpreadConstraints: {}
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/component
                  operator: In
                  values:
                    - store-gateway
            topologyKey: "kubernetes.io/hostname"

# Compactor - compacts blocks
compactor:
  replicas: 1
  persistentVolume:
    enabled: true
    size: 20Gi
    storageClass: ${storage_class}
  resources:
    requests:
      cpu: 250m
      memory: 1Gi
    limits:
      cpu: 1
      memory: 2Gi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}

# Ruler
ruler:
  replicas: 1
  resources:
    requests:
      cpu: 250m
      memory: 1Gi
    limits:
      cpu: 1
      memory: 2Gi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}

# Overrides Exporter
overrides_exporter:
  replicas: 1
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}

# ============================================================
# CACHES - MEMCACHED (RECOMMENDED FOR PERFORMANCE)
# ============================================================

# Chunks Cache
chunks-cache:
  enabled: true
  replicas: 2
  resources:
    requests:
      cpu: 100m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}

# Index Cache
index-cache:
  enabled: true
  replicas: 2
  resources:
    requests:
      cpu: 100m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}

# Metadata Cache
metadata-cache:
  enabled: true
  replicas: 2
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}

# Results Cache
results-cache:
  enabled: true
  replicas: 2
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}
%{ if length(tolerations) > 0 ~}
  tolerations:
%{ for toleration in tolerations ~}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
%{ if toleration.value != null ~}
      value: "${toleration.value}"
%{ endif ~}
      effect: "${toleration.effect}"
%{ endfor ~}
%{ endif ~}

# ============================================================
# DISABLED COMPONENTS
# ============================================================

# Alertmanager (using Grafana Unified Alerting)
alertmanager:
  enabled: false

# MinIO (using S3 directly)
minio:
  enabled: false

# Rollout Operator - disabled to avoid architecture errors
rollout_operator:
  enabled: false

# ============================================================
# MONITORING
# ============================================================
monitoring:
  dashboards:
    enabled: true
    labels:
      grafana_dashboard: "1"
  rules:
    enabled: true
    alerting: true
  serviceMonitor:
    enabled: true
    labels:
      release: prometheus
