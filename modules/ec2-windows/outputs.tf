# =============================================================================
# EC2 WINDOWS MODULE — Outputs
# =============================================================================

output "instance_id" {
  description = "EC2 instance ID — use this in SSM Session Manager to connect"
  value       = aws_instance.windows.id
}

output "instance_arn" {
  description = "EC2 instance ARN"
  value       = aws_instance.windows.arn
}

output "private_ip" {
  description = "Private IP address of the EC2 instance (within VPC)"
  value       = aws_instance.windows.private_ip
}

output "instance_type" {
  description = "EC2 instance type being used"
  value       = aws_instance.windows.instance_type
}

output "ami_id" {
  description = "AMI ID used for this instance"
  value       = local.ami_id
}

output "security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}

output "iam_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2.arn
}

output "ssm_connect_command" {
  description = "AWS CLI command to start an SSM session with this instance"
  value       = "aws ssm start-session --target ${aws_instance.windows.id}"
}

output "ssm_rdp_tunnel_command" {
  description = "AWS CLI command to tunnel RDP through SSM (then connect RDP to localhost:13389)"
  value       = "aws ssm start-session --target ${aws_instance.windows.id} --document-name AWS-StartPortForwardingSession --parameters 'portNumber=3389,localPortNumber=13389'"
}

output "sql_password_ssm_path" {
  description = "SSM Parameter Store path where the SQL Server admin password is stored"
  value       = aws_ssm_parameter.sql_admin_password.name
}

output "sql_password_retrieve_command" {
  description = "AWS CLI command to retrieve the SQL Server admin password"
  value       = "aws ssm get-parameter --name ${aws_ssm_parameter.sql_admin_password.name} --with-decryption --query Parameter.Value --output text"
}

output "data_volume_id" {
  description = "ID of the data EBS volume (D: drive)"
  value       = aws_ebs_volume.data.id
}
