# Outputs for LAMP Stack Infrastructure

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.lamp_alb.dns_name
}


output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.lamp_mysql.endpoint
  sensitive   = true
}


output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.lamp_mysql.port
}

output "database_name" {
  description = "Name of the MySQL database"
  value       = aws_db_instance.lamp_mysql.db_name
}

output "web_url" {
  description = "URL to access the web application"
  value       = "http://${aws_lb.lamp_alb.dns_name}"
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret containing RDS credentials"
  value       = aws_secretsmanager_secret.rds_password.name
}


output "cloudwatch_log_groups" {
  description = "CloudWatch log groups for monitoring"
  value = {
    application_logs = aws_cloudwatch_log_group.lamp_app_logs.name
    apache_access   = aws_cloudwatch_log_group.lamp_apache_access_logs.name
    apache_error    = aws_cloudwatch_log_group.lamp_apache_error_logs.name
  }
}
