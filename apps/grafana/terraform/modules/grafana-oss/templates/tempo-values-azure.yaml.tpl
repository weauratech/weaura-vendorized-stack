# ============================================================
# TEMPO DISTRIBUTED - AZURE BLOB STORAGE CONFIGURATION
# ============================================================
# Distributed tracing backend using Azure Blob for storage.
# Receives traces via OTLP from OpenTelemetry Collector or SDKs.
# Storage: Azure Blob Storage with Workload Identity authentication
# ============================================================

# Multi-tenancy enabled for isolation
multitenancyEnabled: true

# ============================================================
# SERVICE ACCOUNT - Workload Identity for Azure Blob Access
# ============================================================
# IMPORTANT: ServiceAccount is created by Terraform (kubernetes.tf) with
# Helm-compatible labels. This ensures the Workload Identity annotations
# are present before the Helm chart is installed.
serviceAccount:
  create: false
  name: tempo

# Global pod labels for Workload Identity
global:
  podLabels:
    azure.workload.identity/use: "true"

# Storage - Azure Blob
storage:
  trace:
    backend: azure
    azure:
      container_name: ${tempo_traces_container}
      storage_account_name: ${storage_account_name}
      user_assigned_id: ${tempo_client_id}

# Traces receivers
traces:
  otlp:
    grpc:
      enabled: true
      receiverConfig:
        endpoint: 0.0.0.0:4317
    http:
      enabled: true
  jaeger:
    grpc:
      enabled: false
    thriftHttp:
      enabled: false
  zipkin:
    enabled: false

# ============================================================
# COMPONENTS
# ============================================================

# Distributor - receives traces
distributor:
  replicas: 2
  resources:
    requests:
      cpu: ${tempo_resources.requests.cpu}
      memory: ${tempo_resources.requests.memory}
    limits:
      cpu: ${tempo_resources.limits.cpu}
      memory: ${tempo_resources.limits.memory}
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

# Ingester - processes and stores traces
ingester:
  replicas: 2
  config:
    max_block_duration: 30m
    trace_idle_period: 30s
    flush_check_period: 5s
    complete_block_timeout: 6m
  resources:
    requests:
      cpu: ${tempo_resources.requests.cpu}
      memory: ${tempo_resources.requests.memory}
    limits:
      cpu: ${tempo_resources.limits.cpu}
      memory: ${tempo_resources.limits.memory}
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

# Compactor - compacts blocks
compactor:
  replicas: 1
  config:
    compaction:
      block_retention: ${tempo_retention_period}
  resources:
    requests:
      cpu: ${tempo_resources.requests.cpu}
      memory: ${tempo_resources.requests.memory}
    limits:
      cpu: ${tempo_resources.limits.cpu}
      memory: ${tempo_resources.limits.memory}
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

# Querier - executes queries
querier:
  replicas: 2
  resources:
    requests:
      cpu: ${tempo_resources.requests.cpu}
      memory: ${tempo_resources.requests.memory}
    limits:
      cpu: ${tempo_resources.limits.cpu}
      memory: ${tempo_resources.limits.memory}
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

# Query Frontend
queryFrontend:
  replicas: 2
  config:
    metrics:
      max_duration: 168h         # 7 days of history allowed
      query_backend_after: 30m   # use local/ingesters metrics for recent window
  resources:
    requests:
      cpu: ${tempo_resources.requests.cpu}
      memory: ${tempo_resources.requests.memory}
    limits:
      cpu: ${tempo_resources.limits.cpu}
      memory: ${tempo_resources.limits.memory}
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

# Metrics Generator - generates metrics from traces
# Sends metrics to Mimir
metricsGenerator:
  enabled: true
  replicas: 1
  walEmptyDir:
    sizeLimit: 5Gi
  config:
    processor:
      local_blocks:
        max_block_duration: 30m
        trace_idle_period: 1m
        flush_check_period: 30s
    storage:
      path: /var/tempo/wal
      remote_write:
        - url: "http://mimir-nginx.${namespace_mimir}.svc.cluster.local:80/api/v1/push"
    traces_storage:
      path: /var/tempo/traces
  resources:
    requests:
      cpu: ${tempo_resources.requests.cpu}
      memory: ${tempo_resources.requests.memory}
    limits:
      cpu: ${tempo_resources.limits.cpu}
      memory: ${tempo_resources.limits.memory}
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

# Overrides
overrides:
  defaults:
    metrics_generator:
      processors:
        - service-graphs
        - span-metrics
        - local-blocks

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
