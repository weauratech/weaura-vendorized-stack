# ============================================================
# AWS Secrets Manager - Data Sources
# ============================================================
# References existing secrets in AWS Secrets Manager.
# Secrets are created and managed externally (manually or via CI/CD).
# Only used when cloud_provider = "aws"
#
# IMPORTANT: These are DATA SOURCES, not managed resources.
# Secret values must be populated manually or via CI/CD.
# ============================================================

# -----------------------------
# Slack Webhooks Secret (Data Source)
# -----------------------------
# Stores Slack webhooks for different alert channels.
# Expected JSON structure:
# {
#   "general_webhook": "https://hooks.slack.com/services/...",
#   "critical_webhook": "https://hooks.slack.com/services/...",
#   "infra_webhook": "https://hooks.slack.com/services/...",
#   "app_webhook": "https://hooks.slack.com/services/..."
# }
# These webhooks are used by Grafana Unified Alerting contact points.

data "aws_secretsmanager_secret" "slack_webhooks" {
  count = local.is_aws && local.is_slack && var.aws_secrets_path_slack_webhooks != "" ? 1 : 0
  name  = var.aws_secrets_path_slack_webhooks
}

data "aws_secretsmanager_secret_version" "slack_webhooks" {
  count     = local.is_aws && local.is_slack && var.aws_secrets_path_slack_webhooks != "" ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.slack_webhooks[0].id
}

# -----------------------------
# Grafana Admin Password Secret (Data Source)
# -----------------------------
# Grafana admin password (optional - can use variable directly instead).
# Expected JSON structure:
# {
#   "admin_password": "..."
# }

data "aws_secretsmanager_secret" "grafana_admin" {
  count = local.is_aws && var.enable_grafana && var.aws_secrets_path_grafana_admin != "" ? 1 : 0
  name  = var.aws_secrets_path_grafana_admin
}

data "aws_secretsmanager_secret_version" "grafana_admin" {
  count     = local.is_aws && var.enable_grafana && var.aws_secrets_path_grafana_admin != "" ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.grafana_admin[0].id
}

# -----------------------------
# Local values for secret access
# -----------------------------
locals {
  # Slack webhooks from Secrets Manager (AWS + Slack)
  aws_slack_webhooks = local.is_aws && local.is_slack && length(data.aws_secretsmanager_secret_version.slack_webhooks) > 0 ? jsondecode(data.aws_secretsmanager_secret_version.slack_webhooks[0].secret_string) : {}

  # Grafana admin password from Secrets Manager (optional)
  aws_grafana_admin_password = local.is_aws && length(data.aws_secretsmanager_secret_version.grafana_admin) > 0 ? jsondecode(data.aws_secretsmanager_secret_version.grafana_admin[0].secret_string)["admin_password"] : null
}
