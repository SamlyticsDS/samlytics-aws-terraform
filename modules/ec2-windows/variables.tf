# =============================================================================
# EC2 WINDOWS MODULE — Input Variables
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

variable "aws_region" {
  description = "AWS region for this EC2 instance"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy the EC2 instance into"
  type        = string
}

variable "subnet_id" {
  description = <<-EOT
    ID of the subnet to place the EC2 instance in.
    Use a PRIVATE subnet — the instance will be accessed via SSM, not direct internet.
  EOT
  type        = string
}

variable "instance_type" {
  description = <<-EOT
    EC2 instance size. Larger = more powerful but more expensive.
    For .NET development + SQL Server + Power BI:
      t3.xlarge  = 4 vCPU, 16 GB RAM  — minimum comfortable
      t3.2xlarge = 8 vCPU, 32 GB RAM  — recommended for Power BI
      m5.xlarge  = 4 vCPU, 16 GB RAM  — better sustained performance
  EOT
  type        = string
  default     = "t3.xlarge"
}

variable "root_volume_size_gb" {
  description = <<-EOT
    Size of the main Windows OS drive in GB.
    SQL Server + .NET + Power BI need at least 100 GB.
    Windows itself takes ~30 GB, leaving ~70 GB for applications and data.
  EOT
  type        = number
  default     = 150
}

variable "data_volume_size_gb" {
  description = <<-EOT
    Size of a separate data drive for SQL Server databases and files.
    Keeping data on a separate volume from OS is a best practice — easier to
    resize, backup, and restore independently.
  EOT
  type        = number
  default     = 200
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting EBS volumes. If empty, uses AWS-managed key."
  type        = string
  default     = ""
}

variable "allowed_rdp_cidrs" {
  description = <<-EOT
    IP ranges allowed to connect via RDP (port 3389).
    We primarily use SSM Session Manager (no ports needed), but this allows
    direct RDP as a fallback. Set to [] to disable RDP entirely (recommended).
    Example: ["203.0.113.10/32"] — your office IP only.
  EOT
  type        = list(string)
  default     = []
}

variable "windows_ami_id" {
  description = <<-EOT
    Windows Server AMI ID. Leave empty to auto-select the latest
    Windows Server 2022 Base AMI for your region (recommended).
    To find manually: EC2 Console → AMI Catalog → search "Windows_Server-2022-English-Full-Base"
  EOT
  type        = string
  default     = ""
}

variable "install_dotnet" {
  description = "Install .NET 8 LTS (includes .NET Framework 4.8 already in Windows)"
  type        = bool
  default     = true
}

variable "install_sql_server" {
  description = "Install SQL Server Express (free edition — up to 10 GB database, 4 cores)"
  type        = bool
  default     = true
}

variable "install_powerbi" {
  description = "Install Power BI Desktop"
  type        = bool
  default     = true
}

variable "install_ssm_cloudwatch_agent" {
  description = "Install and configure CloudWatch Agent for detailed monitoring (memory, disk)"
  type        = bool
  default     = true
}

variable "enable_ssm_session_manager" {
  description = <<-EOT
    Attach IAM role permissions for SSM Session Manager.
    This lets you connect to the instance from the AWS Console or CLI
    WITHOUT opening any firewall ports or managing SSH/RDP keys.
    Always keep this enabled.
  EOT
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
