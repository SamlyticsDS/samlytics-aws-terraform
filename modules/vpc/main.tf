# =============================================================================
# VPC MODULE
# =============================================================================
# Creates a secure, multi-AZ network with:
#   - 1 VPC (your private AWS network)
#   - Public subnets (for NAT Gateway only)
#   - Private subnets (for EC2 instances — more secure)
#   - Internet Gateway (VPC's connection to the internet)
#   - NAT Gateway (lets private resources reach internet without being reachable)
#   - Route Tables (traffic routing rules)
#   - VPC Flow Logs (network traffic audit trail)
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
    Module      = "vpc"
  })
}

# =============================================================================
# VPC — Your Private Network in AWS
# =============================================================================
# Think of a VPC like a private office building. You control who gets in,
# what floor they can go to, and how traffic flows inside.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # EC2 instances get a DNS hostname automatically
  enable_dns_support   = true  # Required for SSM Session Manager to work

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })
}

# =============================================================================
# INTERNET GATEWAY — The VPC's Door to the Internet
# =============================================================================
# Without this, nothing in the VPC can reach the internet at all.
# Only traffic explicitly routed through this can leave.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

# =============================================================================
# PUBLIC SUBNETS — Where the NAT Gateway Lives
# =============================================================================
# We create one public subnet per Availability Zone.
# count.index iterates: 0, 1, 2... matching each CIDR to each AZ.
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # SECURITY: Never auto-assign public IPs — we control what gets a public IP
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Tier = "Public"
  })
}

# =============================================================================
# PRIVATE SUBNETS — Where EC2 Instances Live
# =============================================================================
# Resources here have no direct internet access from the outside.
# They can INITIATE connections out (via NAT Gateway) but not receive them.
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-${count.index + 1}"
    Tier = "Private"
  })
}

# =============================================================================
# NAT GATEWAY — Lets Private Resources Reach the Internet Safely
# =============================================================================
# Elastic IP: a static public IP address that won't change on restart
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-eip"
  })

  # EIP must be created after the Internet Gateway exists
  depends_on = [aws_internet_gateway.main]
}

# The NAT Gateway sits in the first public subnet and uses the Elastic IP
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-gw"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# ROUTE TABLES — Traffic Routing Rules
# =============================================================================

# Public Route Table: send all internet-bound traffic through the Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"           # "all traffic"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })
}

# Private Route Table: send internet-bound traffic through NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-rt"
  })
}

# Connect each public subnet to the public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Connect each private subnet to the private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# VPC FLOW LOGS — Network Traffic Audit Trail
# =============================================================================
# Flow logs capture metadata about every network connection:
# source IP, destination IP, port, protocol, bytes transferred, accept/reject.
# They do NOT capture the actual data — just the "envelope" information.
# Critical for security investigations ("did our server connect to that bad IP?")

resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/flow-logs/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.project_name}-${var.environment}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.project_name}-${var.environment}-vpc-flow-log-policy"
  role  = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-flow-logs"
  })
}

# =============================================================================
# SECURITY HARDENING — Default Security Group
# =============================================================================
# AWS creates a "default" security group that allows all traffic between
# resources in the same security group. We override it to deny everything.
# All our resources use explicitly-defined security groups instead.
resource "aws_default_security_group" "deny_all" {
  vpc_id = aws_vpc.main.id

  # No ingress or egress rules = deny all
  tags = merge(local.common_tags, {
    Name = "DO-NOT-USE-default-sg"
  })
}

# =============================================================================
# VPC ENDPOINTS — Private Access to AWS Services (No Internet Required)
# =============================================================================
# SSM Session Manager needs to reach AWS APIs. Without VPC endpoints,
# this traffic goes via the internet (through NAT Gateway, costing money).
# With endpoints, traffic stays within the AWS network — faster and cheaper.

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ssmmessages-endpoint"
  })
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2messages-endpoint"
  })
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-cloudwatch-endpoint"
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-s3-endpoint"
  })
}

# Security group for VPC Interface Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
  description = "Allow HTTPS traffic from VPC to AWS service endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
  })
}

data "aws_region" "current" {}
