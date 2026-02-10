variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "domain_name" {
  description = "Domain name for Plane"
  type        = string
  default     = "capitalplace2.tylerops.dev"
}

variable "instance_type" {
  description = "EC2 instance type for Plane"
  type        = string
  default     = "t4g.large"
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
  default     = "plane-v2-secret-password"
}

variable "mq_password" {
  description = "RabbitMQ password"
  type        = string
  sensitive   = true
  default     = "plane-v2-mq-password"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.5.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block"
  type        = string
  default     = "10.5.1.0/24"
}

