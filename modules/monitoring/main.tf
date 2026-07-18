# =============================================================================
# MONITORING MODULE
# =============================================================================
# Sets up comprehensive monitoring for the Windows EC2 instance:
#
#   SNS Topic         → sends email/SMS notifications when alarms fire
#   CloudWatch Alarms → CPU, Memory, Disk — alert when thresholds exceeded
#   Log Groups        → centralised log storage for Windows event logs
#   Dashboard         → visual overview in CloudWatch console
#
# WHY MONITORING MATTERS:
#   Without monitoring, you only know something is wrong when users complain.
#   With monitoring, you know before they do.
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
    Module      = "monitoring"
  })
}

# =============================================================================
# SNS TOPIC — Notification Hub
# =============================================================================
# Simple Notification Service (SNS) is AWS's messaging system.
# We create a topic that CloudWatch alarms publish to,
# and subscribe your email address to receive those notifications.
resource "aws_sns_topic" "alerts" {
  name         = "${var.project_name}-${var.environment}-alerts"
  display_name = "${var.project_name} ${var.environment} Infrastructure Alerts"

  tags = local.common_tags
}

# Email subscription — you'll receive a confirmation email, click the link
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# =============================================================================
# CLOUDWATCH LOG GROUPS
# =============================================================================
# Log groups hold the Windows Event Logs forwarded by the CloudWatch Agent.
# These let you search and analyse logs in the AWS Console.

resource "aws_cloudwatch_log_group" "system" {
  name              = "/aws/${var.project_name}/${var.environment}/ec2/system"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    LogType = "Windows System Events"
  })
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/${var.project_name}/${var.environment}/ec2/application"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    LogType = "Windows Application Events"
  })
}

resource "aws_cloudwatch_log_group" "security" {
  name              = "/aws/${var.project_name}/${var.environment}/ec2/security"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    LogType = "Windows Security Events"
  })
}

resource "aws_cloudwatch_log_group" "userdata" {
  name              = "/aws/${var.project_name}/${var.environment}/ec2/userdata"
  retention_in_days = 30

  tags = merge(local.common_tags, {
    LogType = "EC2 User Data Setup Logs"
  })
}

# =============================================================================
# CLOUDWATCH ALARMS — CPU
# =============================================================================
# CPU alarm fires if average CPU stays above threshold for 2 consecutive
# 5-minute periods (10 minutes total) — avoids false alarms from brief spikes.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-cpu-high"
  alarm_description   = "CPU utilisation above ${var.cpu_alarm_threshold}% for 10 minutes on ${var.ec2_instance_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300  # 5 minutes
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  treat_missing_data  = "notBreaching"  # Don't alarm if instance is stopped

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]  # Notify when alarm clears too

  tags = local.common_tags
}

# =============================================================================
# CLOUDWATCH ALARMS — Memory
# =============================================================================
# Memory metrics come from the CloudWatch Agent (not available by default).
# The namespace matches what we configured in userdata.ps1.
resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.project_name}-${var.environment}-memory-high"
  alarm_description   = "Memory usage above ${var.memory_alarm_threshold}% on ${var.ec2_instance_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "% Committed Bytes In Use"
  namespace           = "${var.project_name}/${var.environment}/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

# =============================================================================
# CLOUDWATCH ALARMS — Disk (C: drive)
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "disk_c_low" {
  alarm_name          = "${var.project_name}-${var.environment}-disk-c-low"
  alarm_description   = "C: drive free space below ${100 - var.disk_alarm_threshold}% on ${var.ec2_instance_name}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "% Free Space"
  namespace           = "${var.project_name}/${var.environment}/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 100 - var.disk_alarm_threshold  # Convert "85% used" to "15% free"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.ec2_instance_id
    instance   = "C:"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

# Disk alarm for D: drive (data drive)
resource "aws_cloudwatch_metric_alarm" "disk_d_low" {
  alarm_name          = "${var.project_name}-${var.environment}-disk-d-low"
  alarm_description   = "D: drive free space below ${100 - var.disk_alarm_threshold}% on ${var.ec2_instance_name}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "% Free Space"
  namespace           = "${var.project_name}/${var.environment}/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 100 - var.disk_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.ec2_instance_id
    instance   = "D:"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

# =============================================================================
# CLOUDWATCH ALARM — Instance Status
# =============================================================================
# This alarm fires if the EC2 instance itself has a hardware or software
# issue. AWS runs automatic health checks every minute.
resource "aws_cloudwatch_metric_alarm" "instance_status" {
  alarm_name          = "${var.project_name}-${var.environment}-instance-status"
  alarm_description   = "EC2 instance status check failure on ${var.ec2_instance_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

# =============================================================================
# CLOUDWATCH DASHBOARD
# =============================================================================
# Creates a visual dashboard in CloudWatch console showing all key metrics.
# Access: AWS Console → CloudWatch → Dashboards
resource "aws_cloudwatch_dashboard" "main" {
  count          = var.create_dashboard ? 1 : 0
  dashboard_name = "${var.project_name}-${var.environment}-workstation"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# ${var.project_name} ${var.environment} — Windows Workstation Dashboard\nInstance: `${var.ec2_instance_id}` | [View Logs](/cloudwatch/home#logsV2:log-groups)"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "CPU Utilisation (%)"
          region = var.aws_region
          period = 300
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.ec2_instance_id]
          ]
          annotations = {
            horizontal = [{
              value = var.cpu_alarm_threshold
              label = "Alarm Threshold"
              color = "#ff6961"
            }]
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Memory Usage (%)"
          region = var.aws_region
          period = 300
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["${var.project_name}/${var.environment}/EC2", "% Committed Bytes In Use", "InstanceId", var.ec2_instance_id]
          ]
          annotations = {
            horizontal = [{
              value = var.memory_alarm_threshold
              label = "Alarm Threshold"
              color = "#ff6961"
            }]
          }
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Disk Free Space (%)"
          region = var.aws_region
          period = 300
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["${var.project_name}/${var.environment}/EC2", "% Free Space", "InstanceId", var.ec2_instance_id, "instance", "C:", { label = "C: Drive" }],
            ["${var.project_name}/${var.environment}/EC2", "% Free Space", "InstanceId", var.ec2_instance_id, "instance", "D:", { label = "D: Drive" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Network Traffic (bytes)"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", var.ec2_instance_id, { label = "Network In", color = "#2ca02c" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", var.ec2_instance_id, { label = "Network Out", color = "#1f77b4" }]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 12
        y      = 7
        width  = 12
        height = 6
        properties = {
          title = "Alarm Status"
          alarms = [
            aws_cloudwatch_metric_alarm.cpu_high.arn,
            aws_cloudwatch_metric_alarm.memory_high.arn,
            aws_cloudwatch_metric_alarm.disk_c_low.arn,
            aws_cloudwatch_metric_alarm.disk_d_low.arn,
            aws_cloudwatch_metric_alarm.instance_status.arn
          ]
        }
      }
    ]
  })
}
