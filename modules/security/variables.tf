# =============================================================================
# SECURITY MODULE — Input Variables
# =============================================================================

variable "project_name" {
  description = "Name of your project/organisation — used to name all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region these resources are in"
  type        = string
}

variable "aws_account_id" {
  description = "Your AWS Account ID — used in IAM policies and resource ARNs"
  type        = string
}

variable "enable_guardduty" {
  description = <<-EOT
    Enable AWS GuardDuty — intelligent threat detection that analyses
    CloudTrail, VPC Flow Logs, and DNS logs to detect malicious activity.
    Examples: crypto mining, compromised EC2 instances, unusual API calls.
    First 30 days free, then ~$1-4/month for typical accounts.
  EOT
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = <<-EOT
    Enable AWS Security Hub — gives you a security score and compliance dashboard.
    Aggregates findings from GuardDuty, Inspector, Macie, and Config into one place.
    First 30 days free.
  EOT
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = <<-EOT
    Enable AWS CloudTrail — logs every API call made in your AWS account.
    Who logged in, what they did, when, from where.
    Essential for security auditing and incident investigation.
  EOT
  type        = bool
  default     = true
}

variable "enable_aws_config" {
  description = <<-EOT
    Enable AWS Config — continuously monitors your resource configurations
    and checks them against compliance rules (e.g., "are all S3 buckets private?").
    ~$2/month for typical accounts.
  EOT
  type        = bool
  default     = true
}

variable "cloudtrail_log_retention_days" {
  description = "How long to keep CloudTrail logs in CloudWatch"
  type        = number
  default     = 365
}

variable "enable_kms" {
  description = "Create a KMS key for encrypting EC2 volumes, S3, and other resources"
  type        = bool
  default     = true
}

variable "kms_key_deletion_window_days" {
  description = <<-EOT
    Days before a deleted KMS key is permanently removed (7-30).
    During this window you can cancel the deletion if you made a mistake.
  EOT
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window_days >= 7 && var.kms_key_deletion_window_days <= 30
    error_message = "kms_key_deletion_window_days must be between 7 and 30."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
