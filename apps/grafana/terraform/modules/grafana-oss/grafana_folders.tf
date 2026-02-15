# ============================================================
# Grafana Folders - Dashboard and Alert Organization
# ============================================================
# Creates Grafana folders for organizing dashboards and alerts.
# Supports dynamic folder creation via variable input.
# ============================================================

# ============================================================
# DEFAULT FOLDERS
# ============================================================

resource "grafana_folder" "infrastructure" {
  count = var.enable_grafana && var.enable_grafana_resources ? 1 : 0

  uid   = "infrastructure"
  title = "Infrastructure"

  depends_on = [helm_release.grafana]
}

resource "grafana_folder" "kubernetes" {
  count = var.enable_grafana && var.enable_grafana_resources ? 1 : 0

  uid   = "kubernetes"
  title = "Kubernetes"

  depends_on = [helm_release.grafana]
}

resource "grafana_folder" "applications" {
  count = var.enable_grafana && var.enable_grafana_resources ? 1 : 0

  uid   = "applications"
  title = "Applications"

  depends_on = [helm_release.grafana]
}

resource "grafana_folder" "sre" {
  count = var.enable_grafana && var.enable_grafana_resources ? 1 : 0

  uid   = "sre"
  title = "SRE"

  depends_on = [helm_release.grafana]
}

resource "grafana_folder" "alerts" {
  count = var.enable_grafana && var.enable_grafana_resources ? 1 : 0

  uid   = "alerts"
  title = "Alert Rules"

  depends_on = [helm_release.grafana]
}

# ============================================================
# OBSERVABILITY STACK FOLDERS
# ============================================================

resource "grafana_folder" "prometheus" {
  count = var.enable_grafana && var.enable_grafana_resources && var.enable_prometheus ? 1 : 0

  uid   = "prometheus"
  title = "Prometheus"

  depends_on = [helm_release.grafana]
}

resource "grafana_folder" "loki" {
  count = var.enable_grafana && var.enable_grafana_resources && var.enable_loki ? 1 : 0

  uid   = "loki"
  title = "Loki"

  depends_on = [helm_release.grafana]
}

resource "grafana_folder" "mimir" {
  count = var.enable_grafana && var.enable_grafana_resources && var.enable_mimir ? 1 : 0

  uid   = "mimir"
  title = "Mimir"

  depends_on = [helm_release.grafana]
}

resource "grafana_folder" "tempo" {
  count = var.enable_grafana && var.enable_grafana_resources && var.enable_tempo ? 1 : 0

  uid   = "tempo"
  title = "Tempo"

  depends_on = [helm_release.grafana]
}

resource "grafana_folder" "pyroscope" {
  count = var.enable_grafana && var.enable_grafana_resources && var.enable_pyroscope ? 1 : 0

  uid   = "pyroscope"
  title = "Pyroscope"

  depends_on = [helm_release.grafana]
}

# ============================================================
# CUSTOM FOLDERS (from variable input)
# ============================================================

resource "grafana_folder" "custom" {
  for_each = var.enable_grafana && var.enable_grafana_resources ? var.grafana_folders : {}

  uid   = each.key
  title = each.value.title

  depends_on = [helm_release.grafana]
}

# ============================================================
# FOLDER PERMISSIONS (Read-only for Viewer role by default)
# ============================================================

resource "grafana_folder_permission" "infrastructure" {
  count = var.enable_grafana && var.enable_grafana_resources ? 1 : 0

  folder_uid = grafana_folder.infrastructure[0].uid

  permissions {
    role       = "Viewer"
    permission = "View"
  }

  permissions {
    role       = "Editor"
    permission = "Edit"
  }

  depends_on = [grafana_folder.infrastructure]
}

resource "grafana_folder_permission" "kubernetes" {
  count = var.enable_grafana && var.enable_grafana_resources ? 1 : 0

  folder_uid = grafana_folder.kubernetes[0].uid

  permissions {
    role       = "Viewer"
    permission = "View"
  }

  permissions {
    role       = "Editor"
    permission = "Edit"
  }

  depends_on = [grafana_folder.kubernetes]
}

resource "grafana_folder_permission" "applications" {
  count = var.enable_grafana && var.enable_grafana_resources ? 1 : 0

  folder_uid = grafana_folder.applications[0].uid

  permissions {
    role       = "Viewer"
    permission = "View"
  }

  permissions {
    role       = "Editor"
    permission = "Edit"
  }

  depends_on = [grafana_folder.applications]
}

resource "grafana_folder_permission" "sre" {
  count = var.enable_grafana && var.enable_grafana_resources ? 1 : 0

  folder_uid = grafana_folder.sre[0].uid

  permissions {
    role       = "Viewer"
    permission = "View"
  }

  permissions {
    role       = "Editor"
    permission = "Edit"
  }

  permissions {
    role       = "Admin"
    permission = "Admin"
  }

  depends_on = [grafana_folder.sre]
}

resource "grafana_folder_permission" "alerts" {
  count = var.enable_grafana && var.enable_grafana_resources ? 1 : 0

  folder_uid = grafana_folder.alerts[0].uid

  permissions {
    role       = "Viewer"
    permission = "View"
  }

  permissions {
    role       = "Editor"
    permission = "Edit"
  }

  depends_on = [grafana_folder.alerts]
}
