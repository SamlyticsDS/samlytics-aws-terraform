# =============================================================================
# ENVIRONMENT OUTPUTS — What Terraform Prints After Deployment
# =============================================================================
# After running "terraform apply", these values are printed to your terminal.
# They tell you everything you need to connect to and use the environment.
# =============================================================================

output "deployment_summary" {
  description = "Summary of what was deployed"
  value = {
    project     = var.project_name
    environment = var.environment
    region      = var.aws_region
    deployed_at = timestamp()
  }
}

# ----------- NETWORKING -----------

output "vpc_id" {
  description = "VPC ID — your private network"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC IP range"
  value       = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EC2 lives here)"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs (NAT Gateway lives here)"
  value       = module.vpc.public_subnet_ids
}

output "nat_gateway_public_ip" {
  description = "Your EC2's outbound internet IP (whitelist this in external services)"
  value       = module.vpc.nat_gateway_public_ip
}

# ----------- EC2 INSTANCE -----------

output "ec2_instance_id" {
  description = "EC2 Instance ID — needed to start SSM sessions"
  value       = module.ec2_windows.instance_id
}

output "ec2_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = module.ec2_windows.private_ip
}

output "ec2_instance_type" {
  description = "EC2 instance type in use"
  value       = module.ec2_windows.instance_type
}

# ----------- HOW TO CONNECT -----------

output "connect_via_ssm" {
  description = "Run this command to open a terminal session on the Windows server"
  value       = module.ec2_windows.ssm_connect_command
}

output "connect_via_rdp_tunnel" {
  description = "Run this, then connect RDP to localhost:13389 for a full Windows desktop"
  value       = module.ec2_windows.ssm_rdp_tunnel_command
}

# ----------- SQL SERVER -----------

output "sql_password_location" {
  description = "The SQL Server admin password is stored here (encrypted)"
  value       = module.ec2_windows.sql_password_ssm_path
}

output "retrieve_sql_password" {
  description = "Run this command to get the SQL Server admin password"
  value       = module.ec2_windows.sql_password_retrieve_command
  sensitive   = true
}

# ----------- SECURITY -----------

output "kms_key_arn" {
  description = "KMS key encrypting all data at rest"
  value       = module.security.kms_key_arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.security.guardduty_detector_id
}

output "cloudtrail_logs_bucket" {
  description = "S3 bucket containing CloudTrail audit logs"
  value       = module.security.cloudtrail_bucket_name
}

# ----------- MONITORING -----------

output "cloudwatch_dashboard_url" {
  description = "Open this URL in your browser to see the monitoring dashboard"
  value       = module.monitoring.dashboard_url
}

output "alerts_topic_arn" {
  description = "SNS topic ARN for alert notifications"
  value       = module.monitoring.sns_topic_arn
}

output "log_groups" {
  description = "CloudWatch Log Groups for this instance"
  value = {
    system      = module.monitoring.log_group_system
    application = module.monitoring.log_group_application
    security    = module.monitoring.log_group_security
  }
}

# ----------- NEXT STEPS (displayed after deployment) -----------

output "next_steps" {
  description = "What to do after deployment"
  value       = <<-EOT

    ============================================================
    DEPLOYMENT COMPLETE — NEXT STEPS
    ============================================================

    1. WAIT 5-10 MINUTES for Windows to start and software to install.

    2. CHECK INSTALL PROGRESS:
       ${module.ec2_windows.ssm_connect_command}
       Then run: Get-Content C:\UserData\setup.log -Tail 20

    3. CONNECT VIA RDP (full Windows desktop):
       ${module.ec2_windows.ssm_rdp_tunnel_command}
       Then open Remote Desktop and connect to: localhost:13389

    4. GET SQL SERVER PASSWORD:
       ${module.ec2_windows.sql_password_retrieve_command}

    5. CONFIRM ALERTS: Check your email (${var.alert_email}) for a
       CloudWatch subscription confirmation. Click the link!

    6. VIEW DASHBOARD:
       ${module.monitoring.dashboard_url}

    ⚠️  REMEMBER: Run 'terraform destroy' when you're done to avoid charges!
    ============================================================
  EOT
}
