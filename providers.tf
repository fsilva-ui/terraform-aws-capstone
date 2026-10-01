provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "AWS-Capstone-DR"
      Environment = "lab"
      ManagedBy   = "Terraform"
    }
  }
}