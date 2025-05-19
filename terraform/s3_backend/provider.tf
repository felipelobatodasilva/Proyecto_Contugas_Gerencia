provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
} 