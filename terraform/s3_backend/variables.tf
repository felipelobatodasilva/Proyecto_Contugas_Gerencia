variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"  # North Virginia Region
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "Contugas"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags comuns para todos os recursos"
  type        = map(string)
  default = {
    Project     = "Contugas"
    ManagedBy   = "terraform"
    Owner       = "data-engineering"
  }
} 