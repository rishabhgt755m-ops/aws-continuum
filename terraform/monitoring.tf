# Phase 4 — Observability
# All monitoring is Terraform-managed and removed during final teardown.

variable "alarm_email" {
  description = "Email recipient for alarm notifications. Empty disables subscription."
  type        = string
  default     = ""
  sensitive   = true
}

locals {
  monitoring_tags = {
    Project   = "continuum"
    Component = "observability"
  }

  alb_dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_sns_topic" "alerts" {
  name = "continuum-phase4-alerts"
  tags = local.monitoring_tags
}

resource "aws_sns_topic_subscription" "email" {
  count = nonsensitive(var.alarm_email) == "" ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "alb_capacity" {
  alarm_name          = "continuum-alb-capacity"
  alarm_description   = "Fewer than two healthy application targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  dimensions          = local.alb_dimensions
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "LessThanThreshold"
  threshold           = 2
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.monitoring_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "continuum-alb-target-5xx"
  alarm_description   = "At least five target HTTP 5XX errors within one minute"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = local.alb_dimensions
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.monitoring_tags
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name        = "continuum-ec2-high-cpu"
  alarm_description = "ASG EC2 average CPU above 80 percent"
  namespace         = "AWS/EC2"
  metric_name       = "CPUUtilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.monitoring_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name        = "continuum-rds-high-cpu"
  alarm_description = "RDS CPU above 80 percent for three minutes"
  namespace         = "AWS/RDS"
  metric_name       = "CPUUtilization"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.monitoring_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name        = "continuum-rds-low-storage"
  alarm_description = "RDS free storage below 2 GiB"
  namespace         = "AWS/RDS"
  metric_name       = "FreeStorageSpace"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "LessThanThreshold"
  threshold           = 2147483648
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.monitoring_tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "continuum-phase4"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB healthy targets"
          region = "eu-west-1"
          period = 60
          stat   = "Minimum"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount",
              "TargetGroup", aws_lb_target_group.app.arn_suffix,
            "LoadBalancer", aws_lb.app.arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB request count and target 5XX"
          region = "eu-west-1"
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount",
            "LoadBalancer", aws_lb.app.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count",
              "TargetGroup", aws_lb_target_group.app.arn_suffix,
            "LoadBalancer", aws_lb.app.arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB target response time"
          region = "eu-west-1"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime",
            "LoadBalancer", aws_lb.app.arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "EC2 average CPU"
          region = "eu-west-1"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/EC2", "CPUUtilization",
            "AutoScalingGroupName", aws_autoscaling_group.app.name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "RDS CPU and connections"
          region = "eu-west-1"
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization",
              "DBInstanceIdentifier", aws_db_instance.postgres.identifier,
            { stat = "Average", yAxis = "left" }],
            ["AWS/RDS", "DatabaseConnections",
              "DBInstanceIdentifier", aws_db_instance.postgres.identifier,
            { stat = "Average", yAxis = "right" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "RDS free storage"
          region = "eu-west-1"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "FreeStorageSpace",
            "DBInstanceIdentifier", aws_db_instance.postgres.identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "RDS Proxy connections"
          region = "eu-west-1"
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/RDS", "ClientConnections",
            "ProxyName", aws_db_proxy.app.name],
            ["AWS/RDS", "DatabaseConnections",
            "ProxyName", aws_db_proxy.app.name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "Auto Scaling in-service capacity"
          region = "eu-west-1"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances",
            "AutoScalingGroupName", aws_autoscaling_group.app.name]
          ]
        }
      }
    ]
  })
}
