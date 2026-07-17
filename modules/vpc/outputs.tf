# =============================================================================
# VPC MODULE — Outputs
# =============================================================================
# These values are "exported" so other modules can use them.
# Example: the EC2 module needs to know the VPC ID and subnet IDs.
# =============================================================================

output "vpc_id" {
  description = "The ID of the VPC (e.g. vpc-0abc123)"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The IP address range of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs — use for NAT Gateway, load balancers"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs — use for EC2 instances, databases"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "IP ranges of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "IP ranges of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (null if disabled)"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway — your EC2's outbound internet IP"
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "flow_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

output "vpc_endpoint_sg_id" {
  description = "Security group ID for VPC endpoints — used by EC2 module"
  value       = aws_security_group.vpc_endpoints.id
}
