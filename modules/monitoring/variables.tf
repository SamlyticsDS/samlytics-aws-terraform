# =============================================================================
# MONITORING MODULE — Input Variables
# =============================================================================

variable "project_name" {
  description = "Name of your project/organisation"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "alert_email" {
  description = <<-EOT
    Email address to receive CloudWatch alarm notifications.
    You will receive a confirmation email — click the link to activate alerts.
  EOT
  type        = string
}

variable "ec2_instance_id" {
  description = "ID of the EC2 instance to monitor (e.g. i-0abc123def456)"
  type        = string
}

variable "ec2_instance_name" {
  description = "Name of the EC2 instance (used in alarm descriptions)"
  type        = string
  default     = "windows-workstation"
}

variable "cpu_alarm_threshold" {
  description = "CPU utilisation % that triggers an alarm (0-100)"
  type        = number
  default     = 80
}

variable "disk_alarm_threshold" {
  description = "Disk usage % that triggers an alarm (0-100)"
  type        = number
  default     = 85
}

variable "memory_alarm_threshold" {
  description = "Memory usage % that triggers an alarm (0-100)"
  type        = number
  default     = 85
}

variable "log_retention_days" {
  description = "Days to retain application logs in CloudWatch"
  type        = number
  default     = 30
}

variable "create_dashboard" {
  description = "Create a CloudWatch dashboard for this instance"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
