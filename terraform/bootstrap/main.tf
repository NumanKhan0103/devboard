# Terraform state bucket — the chicken-and-egg layer.
#
# The main config in ../ keeps its state in S3. But something has to CREATE
# that bucket, and it can't be the config that stores its state there. The
# honest answer is a tiny separate config with LOCAL state, run exactly once.
#
# Its terraform.tfstate is disposable: it tracks one bucket. If you lose it,
# `terraform import` the bucket back in thirty seconds. That is the trade-off
# that makes the whole thing work — accept one small local state file rather
# than pretend the problem doesn't exist.
#
#   cd terraform/bootstrap
#   terraform init && terraform apply
#   terraform output -raw backend_hcl > ../backend.hcl

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  # S3 bucket names are globally unique across every AWS account on earth, so
  # they cannot be hardcoded in a repo people fork. Deriving from the account
  # ID gives everyone a name that is both unique and predictable.
  bucket_name = coalesce(var.bucket_name, "devboard-tfstate-${data.aws_caller_identity.current.account_id}-${var.region}")

  tags = {
    Project   = "devboard"
    ManagedBy = "terraform"
    Layer     = "bootstrap"
  }
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name

  # Teaching cluster only: lets `terraform destroy` delete a bucket that still
  # holds state files. In production this is how you lose your state history.
  force_destroy = var.force_destroy

  tags = local.tags
}

# Versioning does double duty, and both jobs matter:
#   1. It is your undo button. A bad `terraform destroy` or a corrupted apply
#      is recoverable by restoring the previous object version.
#   2. S3-native locking (use_lockfile) relies on conditional writes, which
#      behave predictably on a versioned bucket.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AES256) is free. SSE-KMS is the production answer — it gives you an
# audit trail and per-key access control — but costs $1/month per key plus a
# charge per request, and every `terraform plan` is a lot of requests.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACLs are legacy. BucketOwnerEnforced disables them entirely, so access is
# decided by IAM and the bucket policy alone — one mechanism, not two.
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Every apply writes a new version. Without this, five years of state history
# accumulates forever and you pay for all of it.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  # The provider requires an explicit filter; an empty one means "all objects".
  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

# Block plaintext HTTP. Terraform always uses TLS, so this costs nothing — but
# it is the difference between "we assume TLS" and "we enforce TLS", and every
# compliance scanner looks for it.
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.state.arn,
        "${aws_s3_bucket.state.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}
