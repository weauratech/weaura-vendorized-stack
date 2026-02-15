# ============================================================
# AWS IAM - IRSA for Observability Stack
# ============================================================
# IAM Roles for Service Accounts (IRSA) for Loki, Mimir, and Tempo.
# Each component receives a dedicated role with access to its S3 buckets.
# Only created when cloud_provider = "aws"
# ============================================================

# -----------------------------
# Assume Role Policy (for_each)
# -----------------------------
data "aws_iam_policy_document" "irsa_assume_role" {
  for_each = local.enabled_irsa

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Each component uses multiple service accounts
    condition {
      test     = "StringLike"
      variable = "${local.oidc_provider_url}:sub"
      values = [
        "system:serviceaccount:${each.value.namespace}:${each.key}",
        "system:serviceaccount:${each.value.namespace}:${each.key}-*",
      ]
    }
  }
}

# -----------------------------
# IAM Roles (for_each)
# -----------------------------
resource "aws_iam_role" "irsa" {
  for_each = local.enabled_irsa

  name               = local.irsa_role_names[each.key]
  assume_role_policy = data.aws_iam_policy_document.irsa_assume_role[each.key].json

  tags = merge(local.default_tags, {
    Name      = local.irsa_role_names[each.key]
    Component = each.key
    Namespace = each.value.namespace
  })
}

# -----------------------------
# S3 Policy Documents (for_each)
# -----------------------------
# For each component, create policy with access to its buckets
data "aws_iam_policy_document" "irsa_s3" {
  for_each = local.enabled_irsa

  # For each bucket associated with the component, create statements
  dynamic "statement" {
    for_each = each.value.bucket_keys
    content {
      sid    = "${replace(title(replace(statement.value, "_", " ")), " ", "")}Bucket"
      effect = "Allow"
      actions = [
        "s3:ListBucket",
        "s3:GetBucketLocation",
      ]
      resources = [aws_s3_bucket.this[statement.value].arn]
    }
  }

  dynamic "statement" {
    for_each = each.value.bucket_keys
    content {
      sid    = "${replace(title(replace(statement.value, "_", " ")), " ", "")}Objects"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
      ]
      resources = ["${aws_s3_bucket.this[statement.value].arn}/*"]
    }
  }
}

# -----------------------------
# IAM Policies (for_each)
# -----------------------------
resource "aws_iam_policy" "irsa_s3" {
  for_each = local.enabled_irsa

  name        = "${local.irsa_role_names[each.key]}-s3-policy"
  description = "IAM policy for ${each.key} to access S3 buckets"
  policy      = data.aws_iam_policy_document.irsa_s3[each.key].json

  tags = merge(local.default_tags, {
    Name      = "${local.irsa_role_names[each.key]}-s3-policy"
    Component = each.key
  })
}

# -----------------------------
# Policy Attachments (for_each)
# -----------------------------
resource "aws_iam_role_policy_attachment" "irsa_s3" {
  for_each = local.enabled_irsa

  role       = aws_iam_role.irsa[each.key].name
  policy_arn = aws_iam_policy.irsa_s3[each.key].arn
}
