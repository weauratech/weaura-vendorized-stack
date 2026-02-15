# ============================================================
# LOKI DISTRIBUTED - AZURE BLOB STORAGE CONFIGURATION
# ============================================================
# For small to medium size Loki deployments up to around 1 TB/day
# Uses 3 targets: read, write, and backend
# Storage: Azure Blob Storage with Workload Identity authentication
# ============================================================

# ============================================================
# SERVICE ACCOUNT - Workload Identity for Azure Blob Access
# ============================================================
# IMPORTANT: ServiceAccount is created by Terraform (kubernetes.tf) with
# Helm-compatible labels. This ensures the Workload Identity annotations
# are present before the Helm chart is installed.
serviceAccount:
  create: false
  name: loki

global:
  clusterDomain: "cluster.local"
  dnsService: "kube-dns"
  dnsNamespace: "kube-system"

# SimpleScalable: Loki is deployed as 3 targets: read, write, and backend
deploymentMode: SimpleScalable

# ============================================================
# LOKI CONFIGURATION
# ============================================================
loki:
  auth_enabled: false

  # Common config
  commonConfig:
    path_prefix: /var/loki
    replication_factor: 1

  # Storage configuration - Azure Blob Storage
  storage:
    type: azure
    bucketNames:
      chunks: ${loki_chunks_container}
      ruler: ${loki_ruler_container}
    azure:
      accountName: ${storage_account_name}
      useManagedIdentity: true
      userAssignedId: ${loki_client_id}
      requestTimeout: 60s

  # Schema config
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: azure
        schema: v13
        index:
          prefix: loki_index_
          period: 24h

  # Storage config
  storage_config:
    azure:
      account_name: ${storage_account_name}
      container_name: ${loki_chunks_container}
      use_managed_identity: true
      user_assigned_id: ${loki_client_id}
      request_timeout: 60s
    tsdb_shipper:
      active_index_directory: /var/loki/index
      cache_location: /var/loki/index_cache

  # Limits config
  limits_config:
    reject_old_samples: true
    reject_old_samples_max_age: 168h
    max_cache_freshness_per_query: 10m
    split_queries_by_interval: 15m
    query_timeout: 180s
    volume_enabled: true
    retention_period: ${loki_retention_period}
    allow_structured_metadata: true
    max_query_parallelism: 32
    max_query_series: 500
    max_streams_per_user: 50000
    max_global_streams_per_user: 100000
    ingestion_rate_mb: 16
    ingestion_burst_size_mb: 32
    per_stream_rate_limit: 5MB
    per_stream_rate_limit_burst: 15MB
    max_line_size: 512KB
    max_label_names_per_series: 30
    max_label_name_length: 1024
    max_label_value_length: 2048
    max_concurrent_tail_requests: 10

  # Ingester config
  ingester:
    chunk_idle_period: 1m
    chunk_target_size: 1048576
    max_chunk_age: 5m
    wal:
      dir: /var/loki/wal
      flush_on_shutdown: true

  # Ruler config
  rulerConfig:
    wal:
      dir: /var/loki/ruler-wal
    enable_api: true
    storage:
      type: azure
      azure:
        account_name: ${storage_account_name}
        container_name: ${loki_ruler_container}
        use_managed_identity: true
        user_assigned_id: ${loki_client_id}
    rule_path: /var/loki/rules-temp
    ring:
      kvstore:
        store: inmemory

# Compactor config
compactor:
  working_directory: /var/loki/compactor
  compaction_interval: 5m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 50
  delete_request_store: azure

# ============================================================
# WRITE PATH (Ingester + Distributor)
# ============================================================
write:
  replicas: ${loki_replicas.write}
  persistence:
    volumeClaimsEnabled: false
  resources:
    requests:
      cpu: ${loki_resources.requests.cpu}
      memory: ${loki_resources.requests.memory}
    limits:
      cpu: ${loki_resources.limits.cpu}
      memory: ${loki_resources.limits.memory}
  podLabels:
    azure.workload.identity/use: "true"
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
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app.kubernetes.io/component: write
            topologyKey: kubernetes.io/hostname

# ============================================================
# READ PATH (Querier + Query Frontend)
# ============================================================
read:
  replicas: ${loki_replicas.read}
  resources:
    requests:
      cpu: ${loki_resources.requests.cpu}
      memory: ${loki_resources.requests.memory}
    limits:
      cpu: ${loki_resources.limits.cpu}
      memory: ${loki_resources.limits.memory}
  podLabels:
    azure.workload.identity/use: "true"
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
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app.kubernetes.io/component: read
            topologyKey: kubernetes.io/hostname

# ============================================================
# BACKEND (Compactor + Index Gateway + Ruler + Query Scheduler)
# ============================================================
backend:
  replicas: ${loki_replicas.backend}
  persistence:
    volumeClaimsEnabled: false
  resources:
    requests:
      cpu: ${loki_resources.requests.cpu}
      memory: ${loki_resources.requests.memory}
    limits:
      cpu: ${loki_resources.limits.cpu}
      memory: ${loki_resources.limits.memory}
  podLabels:
    azure.workload.identity/use: "true"
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
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app.kubernetes.io/component: backend
            topologyKey: kubernetes.io/hostname

# ============================================================
# SINGLE BINARY (disabled in SimpleScalable mode)
# ============================================================
singleBinary:
  replicas: 0

# ============================================================
# GATEWAY
# ============================================================
gateway:
  enabled: true
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
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
# CACHES - MEMCACHED
# ============================================================

# Results Cache
resultsCache:
  enabled: true
  replicas: 1
  allocatedMemory: 1024
  resources:
    requests:
      cpu: 100m
      memory: 1280Mi
    limits:
      memory: 1536Mi
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

# Chunks Cache
chunksCache:
  enabled: true
  replicas: 1
  allocatedMemory: 2048
  resources:
    requests:
      cpu: 100m
      memory: 2560Mi
    limits:
      memory: 3072Mi
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
minio:
  enabled: false

lokiCanary:
  enabled: false

test:
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
    alerting: false  # Alerts managed by Grafana Unified Alerting
  serviceMonitor:
    enabled: true
    labels:
      release: prometheus
