terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }

  cloud {
    organization = "Fit_and_Healthy_Practice"

    workspaces {
      name = "terraform-aws-capstone-personal"
    }
  }
}