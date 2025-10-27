# Outputs for LAMP Stack Infrastructure

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.lamp_alb.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.lamp_alb.zone_id
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

output "security_group_alb_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

output "security_group_web_id" {
  description = "ID of the web server security group"
  value       = aws_security_group.web_sg.id
}

output "security_group_rds_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds_sg.id
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.lamp_instance.id
}

output "ec2_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.lamp_instance.private_ip
}

output "vpc_endpoint_ssm_id" {
  description = "ID of the SSM VPC endpoint"
  value       = aws_vpc_endpoint.ssm.id
}

output "vpc_endpoint_ssm_messages_id" {
  description = "ID of the SSM Messages VPC endpoint"
  value       = aws_vpc_endpoint.ssm_messages.id
}

output "vpc_endpoint_ec2_messages_id" {
  description = "ID of the EC2 Messages VPC endpoint"
  value       = aws_vpc_endpoint.ec2_messages.id
}

output "vpc_endpoint_logs_id" {
  description = "ID of the CloudWatch Logs VPC endpoint"
  value       = aws_vpc_endpoint.logs.id
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  value       = aws_secretsmanager_secret.rds_password.arn
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
