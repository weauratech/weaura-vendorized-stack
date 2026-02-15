# ============================================================
# GRAFANA OSS - MULTI-CLOUD CONFIGURATION
# ============================================================
# Visualization and dashboarding platform.
# All datasources are pre-configured.
# Dashboards are provisioned via Grafana Provider (IaC).
# Supports both AWS and Azure deployments.
# ============================================================

replicas: 1

# Deployment strategy - Recreate avoids PVC conflicts
deploymentStrategy:
  type: Recreate

# Persistence
persistence:
  enabled: true
  size: ${grafana_storage_size}
  storageClassName: ${storage_class}

# Environment variables
# GF_PLUGINS_PREINSTALL replaces deprecated GF_INSTALL_PLUGINS in Grafana 12.x
env:
  GF_DATABASE_SQLITE_JOURNAL_MODE: wal
  GF_PLUGINS_PREINSTALL: "${join(",", grafana_plugins)}"
%{ if grafana_sso_enabled ~}
  # Google OAuth SSO - configured via environment variables
  # Secrets (client_id, client_secret) are injected via set_sensitive in Terraform
  GF_AUTH_GOOGLE_ENABLED: "true"
  GF_AUTH_GOOGLE_ALLOW_SIGN_UP: "true"
  GF_AUTH_GOOGLE_AUTO_LOGIN: "false"
  GF_AUTH_GOOGLE_SCOPES: "openid email profile"
  GF_AUTH_GOOGLE_AUTH_URL: "https://accounts.google.com/o/oauth2/auth"
  GF_AUTH_GOOGLE_TOKEN_URL: "https://oauth2.googleapis.com/token"
  GF_AUTH_GOOGLE_API_URL: "https://openidconnect.googleapis.com/v1/userinfo"
%{ if grafana_google_allowed_domains != "" ~}
  GF_AUTH_GOOGLE_ALLOWED_DOMAINS: "${grafana_google_allowed_domains}"
%{ endif ~}
  GF_AUTH_GOOGLE_USE_PKCE: "true"
%{ endif ~}

# ============================================================
# INGRESS - NGINX Ingress Controller
# ============================================================
# TLS Configuration:
# - If tls_secret_name is provided: uses pre-existing secret (e.g., from External Secrets)
# - If tls_secret_name is empty and cluster_issuer is set: uses cert-manager
# - If both are empty: uses default secret name "grafana-tls"
# ============================================================
ingress:
  enabled: ${enable_ingress}
  ingressClassName: ${ingress_class}
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
%{ if tls_secret_name == "" && cluster_issuer != "" ~}
    cert-manager.io/cluster-issuer: "${cluster_issuer}"
%{ endif ~}
%{ for key, value in ingress_annotations ~}
    ${key}: "${value}"
%{ endfor ~}
  hosts:
    - ${grafana_domain}
%{ if enable_tls ~}
  tls:
    - secretName: ${tls_secret_name != "" ? tls_secret_name : (cluster_issuer != "" ? "grafana-tls" : "grafana-tls")}
      hosts:
        - ${grafana_domain}
%{ endif ~}

# ============================================================
# SIDECAR - DISABLED (using Grafana Provider)
# ============================================================
# Dashboards are provisioned via Terraform Grafana Provider
sidecar:
  dashboards:
    enabled: false
  datasources:
    enabled: false

# ============================================================
# ALERTING - GRAFANA UNIFIED ALERTING
# ============================================================
# Alerting is fully managed by Grafana Unified Alerting.
# Contact points and notification policies are provisioned via
# Terraform Grafana Provider (see grafana_alerting.tf).
# No external Alertmanager integration is needed.
# ============================================================

# ============================================================
# DATASOURCES
# ============================================================
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-kube-prometheus-prometheus.${namespace_prometheus}.svc.cluster.local:9090
        access: proxy
        isDefault: false
        editable: true
        uid: prometheus
        jsonData:
          manageAlerts: false  # Alerting via Mimir, not Prometheus

      - name: Mimir
        type: prometheus
        url: http://mimir-nginx.${namespace_mimir}.svc.cluster.local:80/prometheus
        access: proxy
        isDefault: true  # Mimir as default for long-term metrics
        editable: true
        uid: mimir
        jsonData:
          httpMethod: POST
          queryTimeout: 300s
          timeInterval: 15s
          manageAlerts: true  # Mimir is the default datasource for Grafana Alerting

      - name: Loki
        type: loki
        url: http://loki-gateway.${namespace_loki}.svc.cluster.local:80
        access: proxy
        editable: true
        uid: loki
        jsonData:
          httpMethod: POST
          queryTimeout: 120s
          timeInterval: 30s
          maxLines: 5000
          derivedFields:
            - datasourceUid: tempo
              matcherRegex: "traceID=(\\w+)"
              name: TraceID
              url: '$${__value.raw}'

      - name: Tempo
        type: tempo
        url: http://tempo-query-frontend.${namespace_tempo}.svc.cluster.local:3200
        access: proxy
        editable: true
        uid: tempo
        jsonData:
          httpMethod: GET
          httpHeaderName1: X-Scope-OrgID
          maxTraceDuration: 72h
          maxSearchDuration: 72h
          streamingJsonResponse: true
          search:
            hide: false
          nodeGraph:
            enabled: true
          traceQuery:
            timeShiftEnabled: true
            spanStartTimeShift: '-30m'
            spanEndTimeShift: '30m'
          lokiSearch:
            datasourceUid: loki
          serviceMap:
            datasourceUid: mimir
          tracesToLogs:
            datasourceUid: loki
            tags: ['job', 'namespace', 'pod', 'service.name']
            mappedTags: [{ key: 'service.name', value: 'service' }]
            mapTagNamesEnabled: true
            spanStartTimeShift: "-1h"
            spanEndTimeShift: "1h"
            filterByTraceID: true
            filterBySpanID: false
          tracesToProfiles:
            datasourceUid: pyroscope
            tags: ['job', 'namespace', 'pod']
            profileTypeId: 'process_cpu:cpu:nanoseconds:cpu:nanoseconds'
          tracesToMetrics:
            datasourceUid: mimir
            spanStartTimeShift: '-1h'
            spanEndTimeShift: '1h'
            tags: [{ key: 'service.name', value: 'service' }]
            queries:
              - name: 'Request Rate'
                query: 'sum(rate(traces_spanmetrics_calls_total{$$__tags}[5m]))'
              - name: 'Error Rate'
                query: 'sum(rate(traces_spanmetrics_calls_total{$$__tags, status_code="STATUS_CODE_ERROR"}[5m]))'
              - name: 'Latency (p99)'
                query: 'histogram_quantile(0.99, sum(rate(traces_spanmetrics_latency_bucket{$$__tags}[5m])) by (le))'
        secureJsonData:
          httpHeaderValue1: single-tenant

      - name: Pyroscope
        type: grafana-pyroscope-datasource
        url: http://pyroscope.${namespace_pyroscope}.svc.cluster.local:4040
        access: proxy
        editable: true
        uid: pyroscope
        jsonData:
          minStep: 1s

%{ if cloud_provider == "aws" ~}
      # AWS CloudWatch datasource (AWS only)
      - name: CloudWatch
        type: cloudwatch
        access: proxy
        editable: true
        uid: cloudwatch
        jsonData:
          authType: default
          defaultRegion: ${aws_region}
%{ endif ~}

%{ if cloud_provider == "azure" ~}
      # Azure Monitor datasource (Azure only)
      - name: Azure Monitor
        type: grafana-azure-monitor-datasource
        access: proxy
        editable: true
        uid: azure-monitor
        jsonData:
          cloudName: azuremonitor
          azureAuthType: msi
          subscriptionId: ${azure_subscription_id}
%{ endif ~}

# ============================================================
# GRAFANA.INI
# ============================================================
grafana.ini:
  server:
    root_url: https://${grafana_domain}
    domain: ${grafana_domain}

  # Authentication
  auth:
    disable_login_form: false
    oauth_auto_login: false

  # Security
  security:
    admin_user: admin
    cookie_secure: true
    cookie_samesite: lax
    strict_transport_security: true

  # Analytics
  analytics:
    check_for_updates: false
    reporting_enabled: false

  # Unified Alerting - Enabled (Legacy Alerting was removed in Grafana 11+)
  # All alerting is now managed via Grafana's internal Alertmanager.
  # Contact points and notification policies are provisioned via Terraform.
  unified_alerting:
    enabled: true

  # Feature Toggles
  feature_toggles:
    enable: tempoSearch tempoBackendSearch tempoServiceGraph traceToMetrics

# ============================================================
# ADMIN PASSWORD FROM SECRET
# ============================================================
# Admin password is configured via set_sensitive in Terraform

# ============================================================
# RESOURCES
# ============================================================
resources:
  requests:
    cpu: ${grafana_resources.requests.cpu}
    memory: ${grafana_resources.requests.memory}
  limits:
    cpu: ${grafana_resources.limits.cpu}
    memory: ${grafana_resources.limits.memory}

# ============================================================
# NODE SELECTOR
# ============================================================
%{ if length(node_selector) > 0 ~}
nodeSelector:
%{ for key, value in node_selector ~}
  ${key}: "${value}"
%{ endfor ~}
%{ endif ~}

# ============================================================
# TOLERATIONS
# ============================================================
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
