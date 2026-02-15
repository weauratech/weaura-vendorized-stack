# ============================================================
# AWS S3 - Observability Stack Storage
# ============================================================
# S3 buckets for Loki, Mimir, and Tempo data storage.
# Each component uses dedicated buckets for chunks/blocks and ruler.
# Only created when cloud_provider = "aws"
# ============================================================

# -----------------------------
# S3 Buckets (for_each)
# -----------------------------
resource "aws_s3_bucket" "this" {
  for_each = local.enabled_s3_buckets

  bucket = each.value.bucket_name

  tags = merge(local.default_tags, {
    Name      = each.value.bucket_name
    Component = each.value.component
    Purpose   = each.value.purpose
  })
}

# -----------------------------
# Versioning (for_each)
# -----------------------------
resource "aws_s3_bucket_versioning" "this" {
  for_each = local.enabled_s3_buckets

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------
# Encryption (for_each)
# -----------------------------
# Uses customer-managed KMS key if provided, otherwise falls back to AES256.
# Providing a KMS CMK is recommended for enhanced security posture.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.enabled_s3_buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.s3_kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.s3_kms_key_arn != "" ? var.s3_kms_key_arn : null
    }
    bucket_key_enabled = true
  }
}

# -----------------------------
# Public Access Block (for_each)
# -----------------------------
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.enabled_s3_buckets

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------
# Lifecycle Configuration (for_each)
# -----------------------------
# Only for buckets that need lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = local.s3_buckets_with_lifecycle

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    # Apply to all objects in the bucket
    filter {}

    transition {
      days          = each.value.lifecycle_days.transition_ia
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = each.value.lifecycle_days.transition_glacier
      storage_class = "GLACIER"
    }

    expiration {
      days = each.value.lifecycle_days.expiration
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
