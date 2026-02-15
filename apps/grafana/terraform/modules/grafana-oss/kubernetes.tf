# ============================================================
# Kubernetes Resources - Observability Stack
# ============================================================
# Namespaces, ResourceQuotas, LimitRanges, and NetworkPolicies
# for each enabled component.
# ============================================================

# -----------------------------
# Namespaces (for_each)
# -----------------------------
resource "kubernetes_namespace" "this" {
  for_each = local.enabled_components

  metadata {
    name = each.value.namespace

    labels = merge(local.common_labels, {
      "app.kubernetes.io/name"      = each.key
      "app.kubernetes.io/component" = each.value.component
      "terraform.io/managed"        = "true"
    })

    annotations = {
      "description" = each.value.description
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["kubectl.kubernetes.io/last-applied-configuration"]
    ]
  }
}

# -----------------------------
# Resource Quotas (for_each)
# -----------------------------
# NOTE: Using lifecycle ignore_changes to prevent race conditions with Helm.
# Helm charts may also try to update these quotas, causing "the object has been modified" errors.
resource "kubernetes_resource_quota" "this" {
  for_each = var.enable_resource_quotas ? local.enabled_components : {}

  metadata {
    name      = "${each.key}-quota"
    namespace = kubernetes_namespace.this[each.key].metadata[0].name
    labels    = local.common_labels
  }

  spec {
    hard = {
      "requests.cpu"           = local.resource_quotas[each.key].requests_cpu
      "requests.memory"        = local.resource_quotas[each.key].requests_memory
      "limits.cpu"             = local.resource_quotas[each.key].limits_cpu
      "limits.memory"          = local.resource_quotas[each.key].limits_memory
      "persistentvolumeclaims" = local.resource_quotas[each.key].pvcs
      "services"               = local.resource_quotas[each.key].services
      "secrets"                = local.resource_quotas[each.key].secrets
      "configmaps"             = local.resource_quotas[each.key].configmaps
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore resourceVersion changes that can cause race conditions
      # when Helm and Terraform both try to modify the quota
      metadata[0].resource_version,
      metadata[0].annotations["kubectl.kubernetes.io/last-applied-configuration"],
    ]
  }
}

# -----------------------------
# Limit Ranges (for_each)
# -----------------------------
resource "kubernetes_limit_range" "this" {
  for_each = var.enable_limit_ranges ? local.enabled_components : {}

  metadata {
    name      = "${each.key}-limits"
    namespace = kubernetes_namespace.this[each.key].metadata[0].name
    labels    = local.common_labels
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = local.limit_ranges[each.key].default_cpu
        memory = local.limit_ranges[each.key].default_memory
      }
      default_request = {
        cpu    = local.limit_ranges[each.key].default_request_cpu
        memory = local.limit_ranges[each.key].default_request_memory
      }
      min = {
        cpu    = local.limit_ranges[each.key].min_cpu
        memory = local.limit_ranges[each.key].min_memory
      }
      max = {
        cpu    = local.limit_ranges[each.key].max_cpu
        memory = local.limit_ranges[each.key].max_memory
      }
    }
  }
}

# -----------------------------
# Network Policies (for_each)
# -----------------------------
resource "kubernetes_network_policy" "this" {
  for_each = var.enable_network_policies ? local.enabled_components : {}

  metadata {
    name      = "allow-observability-stack"
    namespace = kubernetes_namespace.this[each.key].metadata[0].name
    labels    = local.common_labels
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]

    # If allow_all_namespaces is true, allow from all namespaces
    dynamic "ingress" {
      for_each = local.network_policies[each.key].allow_all_namespaces ? [1] : []
      content {
        from {
          namespace_selector {}
        }
      }
    }

    # If allow_all_namespaces is false, only allow from specific namespaces
    dynamic "ingress" {
      for_each = local.network_policies[each.key].allow_all_namespaces ? [] : local.network_policies[each.key].allowed_namespaces
      content {
        from {
          namespace_selector {
            match_labels = {
              "kubernetes.io/metadata.name" = ingress.value
            }
          }
        }
      }
    }
  }
}

# -----------------------------
# Service Accounts for Workload Identity
# -----------------------------
# Creates service accounts with cloud-specific annotations for workload identity
# IMPORTANT: Labels are set to be Helm-compatible to avoid conflicts when Helm
# charts try to manage the same ServiceAccount. Helm expects:
# - app.kubernetes.io/managed-by: Helm
# - meta.helm.sh/release-name: <release-name>
# - meta.helm.sh/release-namespace: <namespace>
resource "kubernetes_service_account" "workload_identity" {
  for_each = local.enabled_storage_components

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.this[each.key].metadata[0].name
    # Use Helm-compatible labels to avoid conflicts with Helm releases
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
      "app.kubernetes.io/part-of"    = "observability-stack"
      "environment"                  = var.environment
      "cloud-provider"               = var.cloud_provider
    }
    # Include Helm release annotations + cloud-specific workload identity annotations
    annotations = merge(
      # Helm release metadata (required for Helm to adopt this resource)
      {
        "meta.helm.sh/release-name"      = each.key
        "meta.helm.sh/release-namespace" = kubernetes_namespace.this[each.key].metadata[0].name
      },
      # Cloud-specific workload identity annotations
      local.is_aws ? {
        "eks.amazonaws.com/role-arn" = aws_iam_role.irsa[each.key].arn
        } : local.is_azure ? {
        "azure.workload.identity/client-id" = azurerm_user_assigned_identity.workload_identity[each.key].client_id
        "azure.workload.identity/use"       = "true"
      } : {}
    )
  }

  # Ignore changes to labels/annotations that Helm might modify
  lifecycle {
    ignore_changes = [
      metadata[0].labels["app.kubernetes.io/instance"],
      metadata[0].labels["app.kubernetes.io/name"],
      metadata[0].labels["app.kubernetes.io/version"],
      metadata[0].labels["helm.sh/chart"],
      metadata[0].annotations["kubectl.kubernetes.io/last-applied-configuration"],
    ]
  }
}
