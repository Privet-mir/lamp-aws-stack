# CloudWatch Log Group for EC2 Application Logs
resource "aws_cloudwatch_log_group" "lamp_app_logs" {
  name              = "${var.project_name}/application"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-app-logs"
    Environment = "production"
  }
}

# CloudWatch Log Group for Apache Access Logs
resource "aws_cloudwatch_log_group" "lamp_apache_access_logs" {
  name              = "${var.project_name}/apache/access"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-apache-access-logs"
    Environment = "production"
  }
}

# CloudWatch Log Group for Apache Error Logs
resource "aws_cloudwatch_log_group" "lamp_apache_error_logs" {
  name              = "${var.project_name}/apache/error"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-apache-error-logs"
    Environment = "production"
  }
}

# CloudWatch Agent IAM Role
resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "${var.project_name}-cloudwatch-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-cloudwatch-agent-role"
  }
}

# CloudWatch Agent IAM Policy
resource "aws_iam_role_policy" "cloudwatch_agent_policy" {
  name = "${var.project_name}-cloudwatch-agent-policy"
  role = aws_iam_role.cloudwatch_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach CloudWatch Agent role to EC2 instance role
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy_attachment" {
  role       = aws_iam_role.lamp_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# CloudWatch Alarm for EC2 CPU Utilization
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "${var.project_name}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = []

  dimensions = {
    InstanceId = aws_instance.lamp_instance.id
  }

  tags = {
    Name = "${var.project_name}-ec2-cpu-high"
  }
}

# CloudWatch Alarm for EC2 Memory Utilization
resource "aws_cloudwatch_metric_alarm" "ec2_memory_high" {
  alarm_name          = "${var.project_name}-ec2-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors ec2 memory utilization"
  alarm_actions       = []

  dimensions = {
    InstanceId = aws_instance.lamp_instance.id
  }

  tags = {
    Name = "${var.project_name}-ec2-memory-high"
  }
}

# CloudWatch Alarm for EC2 Disk Utilization
resource "aws_cloudwatch_metric_alarm" "ec2_disk_high" {
  alarm_name          = "${var.project_name}-ec2-disk-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"
  alarm_description   = "This metric monitors ec2 disk utilization"
  alarm_actions       = []

  dimensions = {
    InstanceId = aws_instance.lamp_instance.id
    device     = "/dev/xvda1"
    fstype     = "xfs"
  }

  tags = {
    Name = "${var.project_name}-ec2-disk-high"
  }
}

# CloudWatch Alarm for ALB Target Response Time
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.project_name}-alb-target-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "This metric monitors alb target response time"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.lamp_alb.arn_suffix
  }

  tags = {
    Name = "${var.project_name}-alb-target-response-time"
  }
}

# CloudWatch Alarm for ALB HTTP 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_http_5xx_errors" {
  alarm_name          = "${var.project_name}-alb-http-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors alb 5xx errors"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.lamp_alb.arn_suffix
  }

  tags = {
    Name = "${var.project_name}-alb-http-5xx-errors"
  }
}

# CloudWatch Alarm for ALB Target Health
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.project_name}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors alb unhealthy targets"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.lamp_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.lamp_tg.arn_suffix
  }

  tags = {
    Name = "${var.project_name}-alb-unhealthy-targets"
  }
}