terraform {
  backend "s3" {
    bucket         = "contugas-terraform-state-dev"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
} 