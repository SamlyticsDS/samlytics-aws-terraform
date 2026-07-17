# =============================================================================
# BACKEND SETUP — Run This ONCE Before Anything Else
# =============================================================================
#
# WHY THIS EXISTS:
# Terraform needs to remember what it has deployed (its "state"). If two people
# run Terraform at the same time without a shared state, they will conflict and
# break each other's work. We store state in S3 (reliable, versioned storage)
# and use DynamoDB as a "lock" so only one person can deploy at a time.
#
# HOW TO USE:
#   1. Open a terminal in this folder (backend-setup/)
#   2. Run: terraform init
#   3. Run: terraform apply
#   4. Copy the output values into environments/windows-workstation/backend.tf
#
# Run this ONCE per AWS account/region. Never run terraform destroy on this.
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = "terraform-backend"
      Environment = "shared"
    }
  }
}

variable "aws_region" {
  description = "AWS region to create the backend resources in"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Short name for your organisation/project (used in resource names)"
  type        = string
  default     = "myorg"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must be lowercase letters, numbers, and hyphens only."
  }
}

# Random suffix so S3 bucket names are globally unique
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# =============================================================================
# S3 BUCKET — Stores Terraform State
# =============================================================================
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${random_id.bucket_suffix.hex}"

  # Prevent accidental deletion of this bucket (it holds your entire infra state)
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning so you can recover from accidental state corruption
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt all state files at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block all public access — state files can contain secrets
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable access logging so you know who accessed the state
resource "aws_s3_bucket_logging" "terraform_state" {
  bucket        = aws_s3_bucket.terraform_state.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "terraform-state-access/"
}

# S3 bucket for access logs
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.project_name}-terraform-logs-${random_id.bucket_suffix.hex}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# =============================================================================
# DYNAMODB TABLE — Prevents Concurrent Terraform Runs (State Locking)
# =============================================================================
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Protect this table — losing it means losing state locking
  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# OUTPUTS — Copy These Into environments/windows-workstation/backend.tf
# =============================================================================
output "state_bucket_name" {
  description = "S3 bucket name for Terraform state — copy into backend.tf"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_lock_table_name" {
  description = "DynamoDB table name for state locking — copy into backend.tf"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "aws_region" {
  description = "AWS region — copy into backend.tf"
  value       = var.aws_region
}

output "backend_config_snippet" {
  description = "Paste this block into environments/windows-workstation/backend.tf"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.bucket}"
        key            = "windows-workstation/terraform.tfstate"
        region         = "${var.aws_region}"
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
        encrypt        = true
      }
    }
  EOT
}
