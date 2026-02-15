# ============================================================
# PYROSCOPE - CONTINUOUS PROFILING (MULTI-CLOUD)
# ============================================================
# Continuous profiling for performance analysis.
# Uses Alloy agent for automatic profiling collection.
# Supports both AWS and Azure deployments.
# ============================================================

pyroscope:
  replicaCount: 1

  # Resources
  resources:
    requests:
      cpu: ${pyroscope_resources.requests.cpu}
      memory: ${pyroscope_resources.requests.memory}
    limits:
      cpu: ${pyroscope_resources.limits.cpu}
      memory: ${pyroscope_resources.limits.memory}

  # Environment variables for memberlist configuration
  # Fixes "no private IP address found" error by explicitly setting POD_IP
  extraEnv:
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP

  # Extra args to configure memberlist advertise address
  # NOTE: Format must be a map (key: value), not a list of strings
  extraArgs:
    "memberlist.advertise-addr": "$(POD_IP)"
    "memberlist.advertise-port": "7946"

  # Node Selector - run on observability nodes
%{ if length(node_selector) > 0 ~}
  nodeSelector:
%{ for key, value in node_selector ~}
    ${key}: "${value}"
%{ endfor ~}
%{ endif ~}

  # Tolerations - tolerate observability taint
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
# ALLOY AGENT
# ============================================================
# Collects profiling automatically via eBPF/perf
# No need to modify applications
# IMPORTANT: DaemonSet runs on ALL nodes (no nodeSelector)

alloy:
  enabled: true

  # DaemonSet to collect profiling from all pods on each node
  mode: daemonset

  # Tolerations - tolerate ALL taints to run on every node
  tolerations:
    - operator: "Exists"

  # Configuration for automatic profiling collection
  configMap:
    create: true
    content: |
      # Discover all pods in the cluster
      discovery.kubernetes "pods" {
        role = "pod"
      }

      # Collect profiling from discovered pods
      pyroscope.scrape "profiles" {
        targets = discovery.kubernetes.pods.targets
        forward_to = [pyroscope.write.profiles.receiver]

        # Filter system/infrastructure namespaces
        relabel_configs {
          source_labels = ["__meta_kubernetes_namespace"]
          regex = "^(${join("|", excluded_profiling_namespaces)})$"
          action = "drop"
        }
      }

      pyroscope.write "profiles" {
        endpoint {
          url = "http://pyroscope.${namespace_pyroscope}.svc.cluster.local:4040"
        }
      }

  # Alloy resources
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # RBAC required to discover pods
  rbac:
    create: true

  # ServiceAccount
  serviceAccount:
    create: true

  # Security context for eBPF/perf (requires capabilities)
  securityContext:
    capabilities:
      add:
        - SYS_ADMIN
        - SYS_RESOURCE
        - DAC_OVERRIDE
        - PERFMON
        - BPF
    privileged: true  # Required for eBPF profiling
    runAsUser: 0      # Needs to run as root for eBPF
