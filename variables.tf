# Variables for LAMP Stack Infrastructure

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "lamp-stack"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage for RDS instance (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for RDS instance (GB)"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Name of the MySQL database"
  type        = string
  default     = "lampdb"
}

variable "db_username" {
  description = "Username for MySQL database"
  type        = string
  default     = "admin"
}

# Remote backend bootstrap variables
variable "backend_bucket_name" {
  description = "Name for S3 bucket to store Terraform state"
  type        = string
  default     = "assesment-sfeh123rasf1sdfa111"
}

variable "backend_state_key" {
  description = "Object key (path) for the Terraform state file in S3"
  type        = string
  default     = "fugro-assessment/terraform.tfstate"
}
