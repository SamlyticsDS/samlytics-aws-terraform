# =============================================================================
# WINDOWS WORKSTATION ENVIRONMENT
# =============================================================================
# This is the "root" configuration that assembles the modules like LEGO pieces.
# It tells each module what values to use.
#
# Think of it like a recipe:
#   - modules/ = ingredients (VPC, Security, EC2, Monitoring)
#   - this file = the recipe that combines them
#   - terraform.tfvars = your specific quantities
# =============================================================================
# Initial deployment via GitHub Actions.

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

  # Default tags applied to EVERY resource — makes cost tracking easy
  # Do not add non-deterministic values here (e.g. timestamp()) — the AWS
  # provider fails some resource types with "Provider produced inconsistent
  # final plan" when a default tag's value can't be known at plan time.
  default_tags {
    tags = merge(var.tags, {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    })
  }
}

# Look up current AWS account details (region, account ID)
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# MODULE 1: VPC — Networking Foundation
# =============================================================================
# Everything else depends on this — the VPC is your private network in AWS.
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = true   # Needed for EC2 to download software
  enable_flow_logs     = true   # Security monitoring
  log_retention_days   = 30
  tags                 = var.tags
}

# =============================================================================
# MODULE 2: SECURITY — GuardDuty, CloudTrail, Security Hub, KMS, Config
# =============================================================================
# Deployed after VPC so we can reference VPC outputs if needed.
module "security" {
  source = "../../modules/security"

  project_name                 = var.project_name
  environment                  = var.environment
  aws_region                   = var.aws_region
  aws_account_id               = var.aws_account_id
  enable_guardduty             = var.enable_guardduty
  enable_security_hub          = var.enable_security_hub
  enable_cloudtrail            = var.enable_cloudtrail
  enable_aws_config            = var.enable_aws_config
  enable_kms                   = true
  cloudtrail_log_retention_days = 365  # Keep audit logs for 1 year
  tags                         = var.tags
}

# =============================================================================
# MODULE 3: EC2 WINDOWS — The Windows Server
# =============================================================================
# Uses VPC outputs (vpc_id, subnet_id) and Security outputs (kms_key_arn)
module "ec2_windows" {
  source = "../../modules/ec2-windows"

  project_name   = var.project_name
  environment    = var.environment
  aws_region     = var.aws_region

  # From VPC module — use the first private subnet
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.private_subnet_ids[0]

  # From Security module — encrypt all volumes with our KMS key
  kms_key_arn = module.security.kms_key_arn

  # Instance configuration
  instance_type       = var.instance_type
  root_volume_size_gb = var.root_volume_size_gb
  data_volume_size_gb = var.data_volume_size_gb
  allowed_rdp_cidrs   = var.allowed_rdp_cidrs

  # Software installation
  install_dotnet               = true
  install_sql_server           = true
  install_powerbi              = true
  install_ssm_cloudwatch_agent = true
  enable_ssm_session_manager   = true

  tags = var.tags

  # Wait for VPC and security to be ready first
  depends_on = [module.vpc, module.security]
}

# =============================================================================
# MODULE 4: MONITORING — CloudWatch Alarms, Logs, Dashboard
# =============================================================================
# Depends on EC2 module so we can pass the instance ID
module "monitoring" {
  source = "../../modules/monitoring"

  project_name      = var.project_name
  environment       = var.environment
  alert_email       = var.alert_email
  ec2_instance_id   = module.ec2_windows.instance_id
  ec2_instance_name = "${var.project_name}-${var.environment}-windows-workstation"

  cpu_alarm_threshold    = var.cpu_alarm_threshold
  memory_alarm_threshold = var.memory_alarm_threshold
  disk_alarm_threshold   = var.disk_alarm_threshold
  log_retention_days     = 30
  create_dashboard       = true

  tags = var.tags

  depends_on = [module.ec2_windows]
}
