variable "aws_region" {
  default = "ap-southeast-1"
}

variable "instance_types" {
  description = "Spot instance type candidates (ARM64/Graviton)"
  default     = ["t4g.micro"]
}