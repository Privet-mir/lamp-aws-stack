# LAMP Stack Infrastructure on AWS using Terraform

# EC2 Instance
resource "aws_instance" "lamp_instance" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  iam_instance_profile = aws_iam_instance_profile.lamp_instance_profile.name

  user_data_replace_on_change = true

  user_data_base64 = base64gzip(templatefile("${path.module}/user_data.sh", {
    db_endpoint = aws_db_instance.lamp_mysql.endpoint
    db_name     = var.db_name
    db_username = var.db_username
    aws_region = var.aws_region
    db_instance_identifier = aws_db_instance.lamp_mysql.identifier
    secrets_manager_secret_name = aws_secretsmanager_secret.rds_password.name
    project_name = var.project_name
  }))

  # Ensure RDS, Secrets Manager, and VPC endpoints are available before creating EC2 instance
  depends_on = [
    aws_db_instance.lamp_mysql,
    aws_secretsmanager_secret_version.rds_password,
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssm_messages,
    aws_vpc_endpoint.ec2_messages,
    aws_vpc_endpoint.logs
  ]

  tags = {
    Name = "${var.project_name}-instance"
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.project_name}-alb-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Security Group for Web Server (Private Subnet)
resource "aws_security_group" "web_sg" {
  name_prefix = "${var.project_name}-web-sg"
  vpc_id      = module.vpc.vpc_id

  # Only allow HTTP traffic from ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Allow HTTPS traffic from ALB (for future SSL)
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Allow SSM access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSM access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}


# Application Load Balancer
resource "aws_lb" "lamp_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "lamp_tg" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "lamp_tg_attachment" {
  target_group_arn = aws_lb_target_group.lamp_tg.arn
  target_id        = aws_instance.lamp_instance.id
  port             = 80
}

# ALB Listener
resource "aws_lb_listener" "lamp_listener" {
  load_balancer_arn = aws_lb.lamp_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lamp_tg.arn
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "lamp_instance_role" {
  name = "${var.project_name}-instance-role"

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
    Name = "${var.project_name}-instance-role"
  }
}

# IAM Policy for SSM
resource "aws_iam_role_policy_attachment" "lamp_ssm_policy" {
  role       = aws_iam_role.lamp_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Policy for RDS access
resource "aws_iam_role_policy" "lamp_rds_policy" {
  name = "${var.project_name}-rds-policy"
  role = aws_iam_role.lamp_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:DescribeDBEngineVersions",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBParameters",
          "rds:DescribeDBSecurityGroups",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeOptionGroups",
          "rds:DescribeReservedDBInstances",
          "rds:DescribeReservedDBInstancesOfferings"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = "arn:aws:rds-db:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.lamp_mysql.resource_id}/${var.db_username}"
      }
    ]
  })
}

# IAM Policy for Secrets Manager access
resource "aws_iam_role_policy" "lamp_secrets_policy" {
  name = "${var.project_name}-secrets-policy"
  role = aws_iam_role.lamp_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.rds_password.arn
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "lamp_instance_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.lamp_instance_role.name
}
