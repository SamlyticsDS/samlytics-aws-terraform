# =============================================================================
# EC2 WINDOWS MODULE
# =============================================================================
# Deploys a secure Windows Server EC2 instance with:
#   - Windows Server 2022 (latest AMI auto-selected)
#   - Software pre-installed via User Data script
#   - IAM role with SSM + CloudWatch permissions (no key pairs needed)
#   - Encrypted EBS volumes (OS + Data)
#   - Security group with minimal permissions
#   - SSM Session Manager access (no open firewall ports)
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
    Module      = "ec2-windows"
    OS          = "Windows Server 2022"
  })

  kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : null
}

# =============================================================================
# AMI LOOKUP — Latest Windows Server 2022
# =============================================================================
# Rather than hardcoding an AMI ID (which is region-specific and changes with
# updates), we dynamically look up the latest official Windows Server 2022 AMI.
data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]  # Only trust Amazon's official AMIs

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  ami_id = var.windows_ami_id != "" ? var.windows_ami_id : data.aws_ami.windows_2022.id
}

# =============================================================================
# IAM ROLE — EC2 Instance Identity and Permissions
# =============================================================================
# EC2 instances need an IAM role to call AWS services.
# This role grants the minimum permissions needed:
#   - SSM: Connect via Session Manager (no open ports needed)
#   - CloudWatch: Send metrics and logs
#   - S3: Download software from AWS S3 (SSM agent updates etc.)
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

# SSM managed policy — enables Session Manager and patch management
resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm_session_manager ? 1 : 0
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent policy — allows sending metrics and logs
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  count      = var.install_ssm_cloudwatch_agent ? 1 : 0
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# S3 read — for downloading SSM agent updates and CloudWatch config
resource "aws_iam_role_policy" "s3_read" {
  name = "${var.project_name}-${var.environment}-ec2-s3-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::aws-ssm-${var.aws_region}/*",
        "arn:aws:s3:::aws-windows-downloads-${var.aws_region}/*",
        "arn:aws:s3:::amazon-ssm-${var.aws_region}/*",
        "arn:aws:s3:::amazon-ssm-packages-${var.aws_region}/*",
        "arn:aws:s3:::${var.aws_region}-birdwatcher-prod/*",
        "arn:aws:s3:::aws-ssm-document-attachments-${var.aws_region}/*",
        "arn:aws:s3:::patch-baseline-snapshot-${var.aws_region}/*",
        "arn:aws:s3:::aws-patch-manager-${var.aws_region}-*/*",
        "arn:aws:s3:::amazoncloudwatch-agent/*"
      ]
    }]
  })
}

# Attach the role to an instance profile (what gets attached to EC2)
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = local.common_tags
}

# =============================================================================
# SECURITY GROUP — Minimal Firewall Rules
# =============================================================================
# A security group is like a personal firewall for your EC2 instance.
# We follow the "least privilege" principle: deny everything, allow only what's needed.
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for ${var.project_name} Windows EC2 instance"
  vpc_id      = var.vpc_id

  # HTTPS outbound — needed to download software, reach AWS APIs
  egress {
    description = "HTTPS outbound (software downloads, AWS APIs)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP outbound — some package managers use HTTP
  egress {
    description = "HTTP outbound (package downloads)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2-sg"
  })
}

# Conditional RDP rule — only add if allowed_rdp_cidrs is non-empty
resource "aws_security_group_rule" "rdp_inbound" {
  count = length(var.allowed_rdp_cidrs) > 0 ? 1 : 0

  type              = "ingress"
  description       = "RDP inbound from specified IPs only"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  cidr_blocks       = var.allowed_rdp_cidrs
  security_group_id = aws_security_group.ec2.id
}

# =============================================================================
# USER DATA — Software Installation Script
# =============================================================================
# templatefile() reads our PowerShell script and substitutes variables.
# The ${variable} placeholders in userdata.ps1 are filled in here.
locals {
  userdata = templatefile("${path.module}/userdata.ps1", {
    sql_admin_password   = random_password.sql_admin.result
    cloudwatch_namespace = "${var.project_name}/${var.environment}/EC2"
    log_group_name       = "/aws/${var.project_name}/${var.environment}/ec2"
  })
}

# Generate a random SQL Server sa (admin) password
# Excludes $, {, }, and backtick — this value is embedded directly into a
# double-quoted string in userdata.ps1, and those characters trigger
# PowerShell variable/subexpression interpolation, corrupting the script.
resource "random_password" "sql_admin" {
  length           = 20
  special          = true
  override_special = "!#%&*()-_=+[]:?"
}

# Store the SQL password in SSM Parameter Store (encrypted)
# Access it via: AWS Console → Systems Manager → Parameter Store
resource "aws_ssm_parameter" "sql_admin_password" {
  name        = "/${var.project_name}/${var.environment}/sql/admin-password"
  description = "SQL Server Express sa (admin) password for ${var.project_name} ${var.environment}"
  type        = "SecureString"
  value       = random_password.sql_admin.result
  key_id      = local.kms_key_arn

  tags = local.common_tags
}

# =============================================================================
# EC2 INSTANCE — The Windows Server
# =============================================================================
resource "aws_instance" "windows" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  user_data              = local.userdata

  # SECURITY: Disable key pairs — we use SSM Session Manager instead
  # Never need to manage, store, or rotate SSH/RDP keys
  key_name = null

  # Protects against accidental termination
  disable_api_termination = false  # Set to true in production

  # SECURITY: Prevent instance metadata from being accessed without IMDSv2
  # IMDSv2 requires a token — prevents SSRF attacks from stealing instance credentials
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"    # Forces IMDSv2
    http_put_response_hop_limit = 1             # Prevent metadata access from containers
  }

  # OS disk — Windows C: drive
  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"          # Faster and cheaper than gp2
    encrypted             = true
    kms_key_id            = local.kms_key_arn
    delete_on_termination = true

    tags = merge(local.common_tags, {
      Name = "${var.project_name}-${var.environment}-os-volume"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-windows-workstation"
  })

  lifecycle {
    # Don't destroy and recreate the instance if the AMI is updated
    # (a new AMI is just a new base image — we don't want to wipe the server)
    ignore_changes = [ami, user_data]
  }
}

# =============================================================================
# DATA VOLUME — Separate D: drive for SQL Server data and projects
# =============================================================================
# Keeping data on a separate volume from the OS is a best practice because:
#   - You can resize data storage without touching the OS
#   - You can detach and reattach to a different instance
#   - Snapshots of just the data are faster and cheaper
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.windows.availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  encrypted         = true
  kms_key_id        = local.kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-data-volume"
  })
}

resource "aws_volume_attachment" "data" {
  device_name  = "/dev/xvdf"      # Windows will see this as the next available drive letter
  volume_id    = aws_ebs_volume.data.id
  instance_id  = aws_instance.windows.id
  force_detach = false
}

# =============================================================================
# SSM PATCH MANAGER — Automatic Windows Updates
# =============================================================================
# Keeps the Windows instance patched with security updates automatically.
# Patches are applied during a maintenance window to minimise disruption.
resource "aws_ssm_maintenance_window" "patching" {
  name              = "${var.project_name}-${var.environment}-patch-window"
  description       = "Weekly patching window for Windows instances"
  schedule          = "cron(0 2 ? * SUN *)"  # Every Sunday at 2:00 AM UTC
  duration          = 4                        # Hours
  cutoff            = 1                        # Stop starting new patches 1hr before end
  allow_unassociated_targets = false

  tags = local.common_tags
}

resource "aws_ssm_maintenance_window_target" "patching" {
  window_id     = aws_ssm_maintenance_window.patching.id
  name          = "${var.project_name}-${var.environment}-patch-target"
  description   = "Windows instances to patch"
  resource_type = "INSTANCE"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.windows.id]
  }
}

resource "aws_ssm_maintenance_window_task" "patching" {
  window_id        = aws_ssm_maintenance_window.patching.id
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunPatchBaseline"
  priority         = 1
  service_role_arn = aws_iam_role.ssm_maintenance.arn
  max_concurrency  = "1"
  max_errors       = "1"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.patching.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      parameter {
        name   = "Operation"
        values = ["Install"]
      }
      parameter {
        name   = "RebootOption"
        values = ["RebootIfNeeded"]
      }
    }
  }
}

resource "aws_iam_role" "ssm_maintenance" {
  name = "${var.project_name}-${var.environment}-ssm-maintenance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ssm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_maintenance" {
  role       = aws_iam_role.ssm_maintenance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}

resource "random_password" "placeholder" {
  # Required dependency for random provider
  length = 8
}
