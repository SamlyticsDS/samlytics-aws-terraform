# =============================================================================
# SECURITY MODULE
# =============================================================================
# Deploys a layered security posture:
#
#   Layer 1 — KMS:          Encryption keys for all data at rest
#   Layer 2 — CloudTrail:   "Who did what, when?" — full API audit log
#   Layer 3 — GuardDuty:    Active threat detection (ML-based)
#   Layer 4 — Security Hub: Compliance dashboard and finding aggregation
#   Layer 5 — AWS Config:   Continuous compliance checking
#
# Together these give you detective controls (you'll know if something happens)
# and compliance evidence (for audits and certifications like ISO27001).
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "security"
  })
}

# =============================================================================
# KMS — Encryption Key Management
# =============================================================================
# KMS (Key Management Service) manages encryption keys so your data
# cannot be read even if someone physically accesses the storage hardware.
# One key is shared across resources — simpler and cheaper than per-resource keys.
resource "aws_kms_key" "main" {
  count = var.enable_kms ? 1 : 0

  description             = "Primary encryption key for ${var.project_name} ${var.environment}"
  deletion_window_in_days = var.kms_key_deletion_window_days
  enable_key_rotation     = true  # AWS automatically rotates the key annually

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to use key"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-main-key"
  })
}

resource "aws_kms_alias" "main" {
  count         = var.enable_kms ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.main[0].key_id
}

# =============================================================================
# CLOUDTRAIL — API Call Audit Log
# =============================================================================
# CloudTrail records every action taken in your AWS account:
#   - Console logins (who, when, from where)
#   - API calls (EC2 started, S3 file deleted, IAM policy changed)
#   - Service-to-service calls
#
# Without CloudTrail, if something goes wrong, you have no evidence.
# With CloudTrail, you can replay exactly what happened and when.

resource "aws_s3_bucket" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-cloudtrail-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-cloudtrail"
  })
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"  # Cheaper storage for older logs
    }

    transition {
      days          = 365
      storage_class = "GLACIER"  # Cheapest storage for archive logs
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/AWSLogs/${var.aws_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  count             = var.enable_cloudtrail ? 1 : 0
  name              = "/aws/cloudtrail/${var.project_name}-${var.environment}"
  retention_in_days = var.cloudtrail_log_retention_days

  tags = local.common_tags
}

resource "aws_iam_role" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0
  name  = "${var.project_name}-${var.environment}-cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0
  name  = "${var.project_name}-${var.environment}-cloudtrail-policy"
  role  = aws_iam_role.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "main" {
  count = var.enable_cloudtrail ? 1 : 0

  name                          = "${var.project_name}-${var.environment}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].id
  include_global_service_events = true  # Captures IAM events (global service)
  is_multi_region_trail         = true  # Captures events in ALL regions
  enable_log_file_validation    = true  # Detects if log files are tampered with
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail[0].arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    # Log S3 data events (who accessed/modified which files)
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-trail"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# =============================================================================
# GUARDDUTY — Intelligent Threat Detection
# =============================================================================
# GuardDuty uses machine learning to analyse:
#   - CloudTrail events (unusual API calls)
#   - VPC Flow Logs (suspicious network traffic)
#   - DNS logs (connections to known-bad domains)
#
# It alerts you to things like:
#   - Your EC2 instance mining cryptocurrency
#   - Someone trying to brute-force your instance
#   - An instance communicating with known malware servers
#   - Credentials being used from an unusual location
resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false  # We don't use Kubernetes
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true  # Scan EC2 volumes if GuardDuty finds a threat
        }
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-guardduty"
  })
}

# =============================================================================
# SECURITY HUB — Security Posture Dashboard
# =============================================================================
# Security Hub is your security control room. It:
#   - Collects findings from GuardDuty, Inspector, Config
#   - Runs automated checks against security standards (CIS, AWS Foundational)
#   - Gives you an overall security score
#   - Lets you track remediation progress
resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards = true  # CIS AWS Foundations Benchmark
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.main]
}

# Connect GuardDuty findings to Security Hub
resource "aws_securityhub_product_subscription" "guardduty" {
  count       = var.enable_security_hub && var.enable_guardduty ? 1 : 0
  product_arn = "arn:aws:securityhub:${var.aws_region}::product/aws/guardduty"

  depends_on = [aws_securityhub_account.main]
}

# =============================================================================
# AWS CONFIG — Continuous Compliance Checking
# =============================================================================
# Config continuously records your resource configurations and checks them
# against rules. For example:
#   - Are all EBS volumes encrypted?
#   - Are all S3 buckets private?
#   - Are security groups not open to the world?
#   - Is MFA enabled on the root account?

resource "aws_s3_bucket" "config" {
  count  = var.enable_aws_config ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-config-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "config" {
  count  = var.enable_aws_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "config" {
  count = var.enable_aws_config ? 1 : 0
  name  = "${var.project_name}-${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_aws_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  count = var.enable_aws_config ? 1 : 0
  name  = "${var.project_name}-${var.environment}-config-s3-policy"
  role  = aws_iam_role.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.config[0].arn}/AWSLogs/${var.aws_account_id}/Config/*"
      Condition = {
        StringLike = {
          "s3:x-amz-acl" = "bucket-owner-full-control"
        }
      }
    }, {
      Effect   = "Allow"
      Action   = ["s3:GetBucketAcl"]
      Resource = aws_s3_bucket.config[0].arn
    }]
  })
}

resource "aws_config_delivery_channel" "main" {
  count          = var.enable_aws_config ? 1 : 0
  name           = "${var.project_name}-${var.environment}-config"
  s3_bucket_name = aws_s3_bucket.config[0].bucket

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_aws_config ? 1 : 0
  name     = "${var.project_name}-${var.environment}-config"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = var.enable_aws_config ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# Key compliance rules
resource "aws_config_config_rule" "ebs_encrypted" {
  count      = var.enable_aws_config ? 1 : 0
  name       = "${var.project_name}-ebs-encryption-check"
  depends_on = [aws_config_configuration_recorder.main]

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  description = "Checks that all EBS volumes are encrypted"
}

resource "aws_config_config_rule" "s3_public_access" {
  count      = var.enable_aws_config ? 1 : 0
  name       = "${var.project_name}-s3-public-access-check"
  depends_on = [aws_config_configuration_recorder.main]

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  description = "Checks that no S3 buckets allow public read access"
}

resource "aws_config_config_rule" "root_mfa" {
  count      = var.enable_aws_config ? 1 : 0
  name       = "${var.project_name}-root-mfa-check"
  depends_on = [aws_config_configuration_recorder.main]

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  description = "Checks that MFA is enabled on the root account"
}

data "aws_caller_identity" "current" {}
