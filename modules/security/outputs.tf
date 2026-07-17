# =============================================================================
# SECURITY MODULE — Outputs
# =============================================================================

output "kms_key_arn" {
  description = "ARN of the KMS encryption key — use this to encrypt EC2 volumes, S3 buckets"
  value       = var.enable_kms ? aws_kms_key.main[0].arn : null
}

output "kms_key_id" {
  description = "ID of the KMS key"
  value       = var.enable_kms ? aws_kms_key.main[0].key_id : null
}

output "kms_key_alias" {
  description = "Human-readable alias for the KMS key"
  value       = var.enable_kms ? aws_kms_alias.main[0].name : null
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "cloudtrail_bucket_name" {
  description = "S3 bucket storing CloudTrail logs"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail[0].bucket : null
}

output "cloudtrail_log_group_name" {
  description = "CloudWatch Log Group for CloudTrail — search here for API events"
  value       = var.enable_cloudtrail ? aws_cloudwatch_log_group.cloudtrail[0].name : null
}

output "config_bucket_name" {
  description = "S3 bucket storing AWS Config snapshots"
  value       = var.enable_aws_config ? aws_s3_bucket.config[0].bucket : null
}
