# =============================================================================
# VPC MODULE — Input Variables
# =============================================================================
# These are the "knobs" you can turn when using this module.
# Each variable has a description, type, and default value.
# =============================================================================

variable "project_name" {
  description = "Name of your project/organisation — used to name all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod) — added to resource tags"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = <<-EOT
    The IP address range for your entire VPC network.
    10.0.0.0/16 gives you 65,536 addresses to work with.
    Think of this as the street address range for your private network.
  EOT
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  description = <<-EOT
    IP ranges for public subnets. Resources here CAN receive traffic from the internet.
    We use public subnets for the NAT Gateway only — NOT for EC2 instances.
    Provide one CIDR per Availability Zone.
  EOT
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = <<-EOT
    IP ranges for private subnets. Resources here CANNOT receive traffic from the internet
    directly. EC2 instances live here — much more secure.
    Provide one CIDR per Availability Zone.
  EOT
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = <<-EOT
    AWS Availability Zones to spread resources across.
    Using 2+ AZs means if one data centre has issues, your app keeps running.
    Format: ["eu-west-1a", "eu-west-1b"]
  EOT
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "enable_nat_gateway" {
  description = <<-EOT
    Whether to create a NAT Gateway.
    NAT Gateway lets private subnet resources (like EC2) download software from the internet
    while still being unreachable FROM the internet.
    Cost: ~$0.05/hour. Disable for pure cost savings if instances don't need internet access.
  EOT
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = <<-EOT
    Whether to enable VPC Flow Logs.
    Flow Logs record metadata about every network connection in your VPC
    (source IP, destination IP, ports, whether the traffic was accepted/rejected).
    Essential for security investigations and compliance.
  EOT
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "How many days to keep VPC flow logs in CloudWatch before auto-deletion"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention period."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources (key-value pairs)"
  type        = map(string)
  default     = {}
}
