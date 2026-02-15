# ============================================================
# KUBE-PROMETHEUS-STACK - MULTI-CLOUD CONFIGURATION
# ============================================================
# Prometheus and supporting components (Node Exporter, KSM).
# Metrics are sent to Mimir for long-term storage via remote write.
# Alerting is handled by Grafana Unified Alerting (not Alertmanager).
# Supports both AWS and Azure deployments.
# ============================================================

# Skip CRD installation (applied via PreSync hook or manually)
skipCRDs: true

# Disable Grafana (we have a separate one in grafana namespace)
grafana:
  enabled: false

# ============================================================
# DISABLE DEFAULT KUBE-PROMETHEUS-STACK ALERTS
# ============================================================
# Only custom alerts are used
defaultRules:
  create: false

# ============================================================
# PROMETHEUS OPERATOR
# ============================================================
prometheusOperator:
  enabled: true

  tls:
    enabled: true

  admissionWebhooks:
    enabled: true
    patch:
      enabled: true
    certManager:
      enabled: true

  webhook:
    patch:
      enabled: true
    cert:
      enabled: true
    secret:
      enabled: true

  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

  # Node scheduling for operator
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
# PROMETHEUS
# ============================================================
prometheus:
  enabled: true
  prometheusSpec:
    # Persistence
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: ${storage_class}
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: ${prometheus_storage_size}

    # Resources
    resources:
      requests:
        cpu: ${prometheus_resources.requests.cpu}
        memory: ${prometheus_resources.requests.memory}
      limits:
        cpu: ${prometheus_resources.limits.cpu}
        memory: ${prometheus_resources.limits.memory}

    # Node scheduling for Prometheus server
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

    # Local retention (short-term)
    # Long-term metrics are sent to Mimir via remote write
    retention: ${prometheus_retention}

    # Remote write to Mimir (long-term storage)
    remoteWrite:
      - url: http://mimir-nginx.${namespace_mimir}.svc.cluster.local:80/api/v1/push

    # PrometheusRule discovery
    ruleSelector:
      matchLabels:
        release: prometheus
    # Allow reading PrometheusRule from all namespaces
    ruleNamespaceSelector: {}

    # ServiceMonitor discovery
    serviceMonitorSelector:
      matchLabels: {}
    serviceMonitorNamespaceSelector: {}

    # PodMonitor discovery
    podMonitorSelector:
      matchLabels: {}
    podMonitorNamespaceSelector: {}

    # Additional scrape configurations
    additionalScrapeConfigs:
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: pod

      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)

# ============================================================
# ALERTMANAGER - DISABLED
# ============================================================
# Alerting is now handled by Grafana Unified Alerting.
# Contact points and notification policies are managed via
# Terraform Grafana Provider (grafana_alerting.tf).
# ============================================================
alertmanager:
  enabled: false

# ============================================================
# NODE EXPORTER (DaemonSet - runs on ALL nodes)
# ============================================================
nodeExporter:
  enabled: true

prometheus-node-exporter:
  enabled: true
  affinity: {}
  # DaemonSet tolerates ANY taint to run on all nodes
  tolerations:
    - operator: "Exists"
  resources:
    requests:
      cpu: 25m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi

# ============================================================
# KUBE STATE METRICS
# ============================================================
kubeStateMetrics:
  enabled: true

kube-state-metrics:
  # Node scheduling for kube-state-metrics
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
