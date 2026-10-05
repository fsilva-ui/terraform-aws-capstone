variable "aws_region" {
  description = "The AWS region used for disaster recovery environment"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "The name used for resource naming"
  type        = string
  default     = "capstone-dr"
}

variable "vpc_cidr" {
  description = "CIDR block for the disaster recovery VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "admin_ip_cidr" {
  description = "Public IP address allowed to access the DR instance via SSH"
  type        = string
}