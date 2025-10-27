# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name_prefix = "${var.project_name}-rds-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "lamp_db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# DB Parameter Group
resource "aws_db_parameter_group" "lamp_mysql_params" {
  family = "mysql8.0"
  name   = "${var.project_name}-mysql-params"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "collation_server"
    value = "utf8_general_ci"
  }

  tags = {
    Name = "${var.project_name}-mysql-params"
  }
}

# Generate random password for RDS
resource "random_password" "rds_password" {
  length  = 16
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# Store RDS password in AWS Secrets Manager
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_secretsmanager_secret" "rds_password" {
  name                    = "${random_id.suffix.hex}-${var.project_name}-rds-password"
  description             = "RDS MySQL password for LAMP stack"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-rds-password"
  }
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id     = aws_secretsmanager_secret.rds_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.rds_password.result
    engine   = "mysql"
    host     = aws_db_instance.lamp_mysql.endpoint
    port     = aws_db_instance.lamp_mysql.port
    dbname   = var.db_name
  })
}

# RDS MySQL Instance
resource "aws_db_instance" "lamp_mysql" {
  identifier = "${var.project_name}-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.rds_password.result

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.lamp_db_subnet_group.name
  parameter_group_name   = aws_db_parameter_group.lamp_mysql_params.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-mysql"
  }
}
