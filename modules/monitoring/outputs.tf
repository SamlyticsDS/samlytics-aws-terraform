# =============================================================================
# MONITORING MODULE — Outputs
# =============================================================================

output "sns_topic_arn" {
  description = "ARN of the SNS alert topic"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS alert topic"
  value       = aws_sns_topic.alerts.name
}

output "log_group_system" {
  description = "CloudWatch Log Group for Windows System events"
  value       = aws_cloudwatch_log_group.system.name
}

output "log_group_application" {
  description = "CloudWatch Log Group for Windows Application events"
  value       = aws_cloudwatch_log_group.application.name
}

output "log_group_security" {
  description = "CloudWatch Log Group for Windows Security events"
  value       = aws_cloudwatch_log_group.security.name
}

output "dashboard_url" {
  description = "URL to view the CloudWatch dashboard (open in AWS Console)"
  value       = var.create_dashboard ? "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${var.project_name}-${var.environment}-workstation" : null
}

output "cpu_alarm_arn" {
  description = "ARN of the CPU high alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_high.arn
}

output "memory_alarm_arn" {
  description = "ARN of the memory high alarm"
  value       = aws_cloudwatch_metric_alarm.memory_high.arn
}
