# ============================================================
# Grafana Alerting - Contact Points, Notification Policies
# ============================================================
# Configures Grafana alerting with Slack or Microsoft Teams.
# Uses the Grafana Terraform provider for native integration.
# ============================================================

# ============================================================
# MESSAGE TEMPLATES
# ============================================================

resource "grafana_message_template" "default" {
  count = var.enable_grafana && var.enable_grafana_resources && var.alerting_provider != "none" ? 1 : 0

  name = "default-alert-template"

  template = <<-EOT
    {{ define "alert_message" }}
    {{ if gt (len .Alerts.Firing) 0 }}
    *Firing Alerts:*
    {{ range .Alerts.Firing }}
    - {{ .Labels.alertname }}: {{ .Annotations.summary }}
      Severity: {{ .Labels.severity | default "unknown" }}
      {{ if .Annotations.description }}Description: {{ .Annotations.description }}{{ end }}
      {{ if .DashboardURL }}Dashboard: {{ .DashboardURL }}{{ end }}
      {{ if .SilenceURL }}Silence: {{ .SilenceURL }}{{ end }}
    {{ end }}
    {{ end }}
    {{ if gt (len .Alerts.Resolved) 0 }}
    *Resolved Alerts:*
    {{ range .Alerts.Resolved }}
    - {{ .Labels.alertname }}: {{ .Annotations.summary }}
    {{ end }}
    {{ end }}
    {{ end }}
  EOT

  depends_on = [helm_release.grafana]
}

resource "grafana_message_template" "critical" {
  count = var.enable_grafana && var.enable_grafana_resources && var.alerting_provider != "none" ? 1 : 0

  name = "critical-alert-template"

  template = <<-EOT
    {{ define "critical_message" }}
    :rotating_light: *CRITICAL ALERT* :rotating_light:
    {{ range .Alerts.Firing }}
    *Alert:* {{ .Labels.alertname }}
    *Severity:* CRITICAL
    *Summary:* {{ .Annotations.summary }}
    {{ if .Annotations.description }}*Description:* {{ .Annotations.description }}{{ end }}
    {{ if .Annotations.runbook_url }}*Runbook:* {{ .Annotations.runbook_url }}{{ end }}
    *Labels:*
    {{ range .Labels.SortedPairs }}  - {{ .Name }}: {{ .Value }}
    {{ end }}
    {{ if .DashboardURL }}*Dashboard:* {{ .DashboardURL }}{{ end }}
    {{ if .SilenceURL }}*Silence:* {{ .SilenceURL }}{{ end }}
    {{ end }}
    {{ end }}
  EOT

  depends_on = [helm_release.grafana]
}

# ============================================================
# SLACK CONTACT POINTS
# ============================================================

resource "grafana_contact_point" "slack_general" {
  count = var.enable_grafana && var.enable_grafana_resources && local.is_slack && var.slack_webhook_general != "" ? 1 : 0

  name = "slack-general"

  slack {
    url                     = var.slack_webhook_general
    recipient               = var.slack_channel_general
    username                = "Grafana Alerts"
    icon_emoji              = ":grafana:"
    title                   = "{{ template \"default.title\" . }}"
    text                    = "{{ template \"alert_message\" . }}"
    mention_users           = ""
    mention_groups          = ""
    mention_channel         = ""
    disable_resolve_message = false
  }

  depends_on = [helm_release.grafana, grafana_message_template.default]
}

resource "grafana_contact_point" "slack_critical" {
  count = var.enable_grafana && var.enable_grafana_resources && local.is_slack && var.slack_webhook_critical != "" ? 1 : 0

  name = "slack-critical"

  slack {
    url                     = var.slack_webhook_critical
    recipient               = var.slack_channel_critical
    username                = "Grafana Critical Alerts"
    icon_emoji              = ":rotating_light:"
    title                   = ":rotating_light: CRITICAL: {{ template \"default.title\" . }}"
    text                    = "{{ template \"critical_message\" . }}"
    mention_channel         = "here"
    disable_resolve_message = false
  }

  depends_on = [helm_release.grafana, grafana_message_template.critical]
}

resource "grafana_contact_point" "slack_infrastructure" {
  count = var.enable_grafana && var.enable_grafana_resources && local.is_slack && var.slack_webhook_infrastructure != "" ? 1 : 0

  name = "slack-infrastructure"

  slack {
    url                     = var.slack_webhook_infrastructure
    recipient               = var.slack_channel_infrastructure
    username                = "Grafana Infrastructure"
    icon_emoji              = ":kubernetes:"
    title                   = ":gear: Infrastructure: {{ template \"default.title\" . }}"
    text                    = "{{ template \"alert_message\" . }}"
    disable_resolve_message = false
  }

  depends_on = [helm_release.grafana, grafana_message_template.default]
}

resource "grafana_contact_point" "slack_application" {
  count = var.enable_grafana && var.enable_grafana_resources && local.is_slack && var.slack_webhook_application != "" ? 1 : 0

  name = "slack-application"

  slack {
    url                     = var.slack_webhook_application
    recipient               = var.slack_channel_application
    username                = "Grafana Application"
    icon_emoji              = ":application:"
    title                   = ":package: Application: {{ template \"default.title\" . }}"
    text                    = "{{ template \"alert_message\" . }}"
    disable_resolve_message = false
  }

  depends_on = [helm_release.grafana, grafana_message_template.default]
}

# ============================================================
# MICROSOFT TEAMS CONTACT POINTS
# ============================================================

resource "grafana_contact_point" "teams_general" {
  count = var.enable_grafana && var.enable_grafana_resources && local.is_teams && var.teams_webhook_general != "" ? 1 : 0

  name = "teams-general"

  teams {
    url                     = var.teams_webhook_general
    title                   = "Grafana Alert"
    message                 = "{{ template \"alert_message\" . }}"
    section_title           = "Alert Details"
    disable_resolve_message = false
  }

  depends_on = [helm_release.grafana, grafana_message_template.default]
}

resource "grafana_contact_point" "teams_critical" {
  count = var.enable_grafana && var.enable_grafana_resources && local.is_teams && var.teams_webhook_critical != "" ? 1 : 0

  name = "teams-critical"

  teams {
    url                     = var.teams_webhook_critical
    title                   = "CRITICAL Alert"
    message                 = "{{ template \"critical_message\" . }}"
    section_title           = "Critical Alert Details"
    disable_resolve_message = false
  }

  depends_on = [helm_release.grafana, grafana_message_template.critical]
}

resource "grafana_contact_point" "teams_infrastructure" {
  count = var.enable_grafana && var.enable_grafana_resources && local.is_teams && var.teams_webhook_infrastructure != "" ? 1 : 0

  name = "teams-infrastructure"

  teams {
    url                     = var.teams_webhook_infrastructure
    title                   = "Infrastructure Alert"
    message                 = "{{ template \"alert_message\" . }}"
    section_title           = "Infrastructure Alert Details"
    disable_resolve_message = false
  }

  depends_on = [helm_release.grafana, grafana_message_template.default]
}

resource "grafana_contact_point" "teams_application" {
  count = var.enable_grafana && var.enable_grafana_resources && local.is_teams && var.teams_webhook_application != "" ? 1 : 0

  name = "teams-application"

  teams {
    url                     = var.teams_webhook_application
    title                   = "Application Alert"
    message                 = "{{ template \"alert_message\" . }}"
    section_title           = "Application Alert Details"
    disable_resolve_message = false
  }

  depends_on = [helm_release.grafana, grafana_message_template.default]
}

# ============================================================
# NOTIFICATION POLICY
# ============================================================

# Build dynamic contact point reference
locals {
  # Slack contact points
  slack_contact_points = {
    general        = var.slack_webhook_general != "" ? "slack-general" : null
    critical       = var.slack_webhook_critical != "" ? "slack-critical" : null
    infrastructure = var.slack_webhook_infrastructure != "" ? "slack-infrastructure" : null
    application    = var.slack_webhook_application != "" ? "slack-application" : null
  }

  # Teams contact points
  teams_contact_points = {
    general        = var.teams_webhook_general != "" ? "teams-general" : null
    critical       = var.teams_webhook_critical != "" ? "teams-critical" : null
    infrastructure = var.teams_webhook_infrastructure != "" ? "teams-infrastructure" : null
    application    = var.teams_webhook_application != "" ? "teams-application" : null
  }

  # Select contact points based on provider
  active_contact_points = local.is_slack ? local.slack_contact_points : local.teams_contact_points

  # Default contact point
  default_contact_point = coalesce(
    local.active_contact_points.general,
    local.active_contact_points.critical,
    local.active_contact_points.infrastructure,
    local.active_contact_points.application,
    "grafana-default-email"
  )
}

resource "grafana_notification_policy" "main" {
  count = var.enable_grafana && var.enable_grafana_resources && var.alerting_provider != "none" ? 1 : 0

  contact_point   = local.default_contact_point
  group_by        = ["alertname", "namespace", "job"]
  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"

  # Critical alerts - route to critical channel
  dynamic "policy" {
    for_each = local.active_contact_points.critical != null ? [1] : []
    content {
      contact_point   = local.active_contact_points.critical
      group_by        = ["alertname"]
      group_wait      = "10s"
      group_interval  = "1m"
      repeat_interval = "1h"

      matcher {
        label = "severity"
        match = "="
        value = "critical"
      }

      continue = false
    }
  }

  # Infrastructure alerts - route to infrastructure channel
  dynamic "policy" {
    for_each = local.active_contact_points.infrastructure != null ? [1] : []
    content {
      contact_point = local.active_contact_points.infrastructure
      group_by      = ["alertname", "namespace"]

      matcher {
        label = "category"
        match = "="
        value = "infrastructure"
      }

      continue = false
    }
  }

  # Application alerts - route to application channel
  dynamic "policy" {
    for_each = local.active_contact_points.application != null ? [1] : []
    content {
      contact_point = local.active_contact_points.application
      group_by      = ["alertname", "namespace", "service"]

      matcher {
        label = "category"
        match = "="
        value = "application"
      }

      continue = false
    }
  }

  depends_on = [
    grafana_contact_point.slack_general,
    grafana_contact_point.slack_critical,
    grafana_contact_point.slack_infrastructure,
    grafana_contact_point.slack_application,
    grafana_contact_point.teams_general,
    grafana_contact_point.teams_critical,
    grafana_contact_point.teams_infrastructure,
    grafana_contact_point.teams_application,
  ]
}

# ============================================================
# MUTE TIMINGS (for scheduled maintenance)
# ============================================================

resource "grafana_mute_timing" "maintenance" {
  count = var.enable_grafana && var.enable_grafana_resources && var.alerting_provider != "none" ? 1 : 0

  name = "scheduled-maintenance"

  intervals {
    weekdays = ["saturday", "sunday"]
    times {
      start = "02:00"
      end   = "06:00"
    }
  }

  depends_on = [helm_release.grafana]
}
