terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "region" {
  description = "AWS region where to create the state bucket and lock table"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "S3 bucket name for Terraform state (must be globally unique)"
  type        = string
}

variable "dynamodb_table" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-locks"
}

provider "aws" {
  region = var.region
}

# ---- S3 bucket for remote state ----
resource "aws_s3_bucket" "tf_state" {
  bucket = var.bucket_name
  tags = {
    Purpose   = "TerraformState"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# TLS-only access policy
data "aws_iam_policy_document" "tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.tf_state.arn,
      "${aws_s3_bucket.tf_state.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.tls_only.json
}

# ---- DynamoDB table for state locks ----
resource "aws_dynamodb_table" "locks" {
  name         = var.dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Purpose   = "TerraformLocks"
    ManagedBy = "Terraform"
  }
}

output "bucket" {
  value       = aws_s3_bucket.tf_state.bucket
  description = "S3 bucket used for remote Terraform state"
}

output "table" {
  value       = aws_dynamodb_table.locks.name
  description = "DynamoDB table used for state locking"
}
