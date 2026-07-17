# =============================================================================
# ENVIRONMENT VARIABLES — Windows Workstation Deployment
# =============================================================================
# These variables let you customise the deployment without changing any code.
# Set your values in terraform.tfvars (copy from terraform.tfvars.example).
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy into (e.g. eu-west-1, us-east-1, af-south-1)"
  type        = string
}

variable "aws_account_id" {
  description = "Your AWS Account ID (12 digits, found in AWS Console top-right)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be exactly 12 digits."
  }
}

variable "project_name" {
  description = "Short name for your organisation/project (lowercase, hyphens ok). Used in all resource names."
  type        = string
  default     = "myorg"
}

variable "environment" {
  description = "Environment: dev, staging, or prod. Affects resource naming and some security settings."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

# ----------- NETWORKING -----------

variable "vpc_cidr" {
  description = "IP range for the VPC (your private network). Default 10.0.0.0/16 gives 65,535 addresses."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to use. Use 2 for resilience. Format: [\"eu-west-1a\", \"eu-west-1b\"]"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "IP ranges for public subnets (one per AZ). NAT Gateway lives here."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "IP ranges for private subnets (one per AZ). EC2 instance lives here."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ----------- EC2 INSTANCE -----------

variable "instance_type" {
  description = <<-EOT
    EC2 size. Recommended options:
      t3.xlarge  — 4 CPU, 16 GB RAM (~£0.16/hr) — minimum for .NET + SQL + PowerBI
      t3.2xlarge — 8 CPU, 32 GB RAM (~£0.32/hr) — comfortable for heavy workloads
      m5.xlarge  — 4 CPU, 16 GB RAM (~£0.20/hr) — consistent performance (no burst limits)
  EOT
  type        = string
  default     = "t3.xlarge"
}

variable "root_volume_size_gb" {
  description = "Size of the C: (OS) drive in GB. 150 GB recommended (Windows + apps)."
  type        = number
  default     = 150
}

variable "data_volume_size_gb" {
  description = "Size of the D: (data) drive in GB. Used for SQL databases and project files."
  type        = number
  default     = 200
}

variable "allowed_rdp_cidrs" {
  description = <<-EOT
    IP ranges allowed direct RDP access (port 3389).
    Leave empty [] to disable RDP — use SSM Session Manager instead (recommended).
    Example office-only access: ["203.0.113.10/32"]
  EOT
  type        = list(string)
  default     = []
}

# ----------- MONITORING -----------

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications. You'll get a confirmation email."
  type        = string
}

variable "cpu_alarm_threshold" {
  description = "CPU % that triggers an alert (0-100). 80 means alert when CPU > 80% for 10 minutes."
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  description = "Memory % that triggers an alert (0-100)."
  type        = number
  default     = 85
}

variable "disk_alarm_threshold" {
  description = "Disk used % that triggers an alert (0-100). 85 means alert when disk is 85% full."
  type        = number
  default     = 85
}

# ----------- SECURITY -----------

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection. Highly recommended. First 30 days free."
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable Security Hub compliance dashboard. Recommended."
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail API audit logging. Required for compliance. Keep enabled."
  type        = bool
  default     = true
}

variable "enable_aws_config" {
  description = "Enable AWS Config compliance checks. Recommended for governance."
  type        = bool
  default     = true
}

# ----------- TAGS -----------

variable "tags" {
  description = "Additional tags added to all resources. Useful for cost allocation."
  type        = map(string)
  default     = {}
}
