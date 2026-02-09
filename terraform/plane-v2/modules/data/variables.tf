variable "vpc_id" {
  description = "VPC ID where the data instance will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the data instance"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for PostgreSQL pg_hba.conf"
  type        = string
}

variable "plane_security_group_id" {
  description = "Security group ID of the Plane instance (to allow traffic from)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the data instance"
  type        = string
  default     = "m6g.medium"
}

variable "ebs_size" {
  description = "Size of the EBS volume for all data in GB"
  type        = number
  default     = 30
}

# PostgreSQL settings
variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "plane"
}

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "plane"
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

# RabbitMQ settings
variable "mq_user" {
  description = "RabbitMQ username"
  type        = string
  default     = "plane"
}

variable "mq_password" {
  description = "RabbitMQ password"
  type        = string
  sensitive   = true
}

variable "mq_vhost" {
  description = "RabbitMQ virtual host"
  type        = string
  default     = "plane"
}

# DNS settings
variable "private_zone_name" {
  description = "Private hosted zone name"
  type        = string
  default     = "plane.internal"
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for SSM access"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "plane-v2"
}
