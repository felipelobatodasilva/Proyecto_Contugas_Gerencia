# S3 bucket para armazenar o estado do Terraform
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${lower(var.project_name)}-terraform-state-${var.environment}"

  # Previne a exclusão acidental do bucket
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${lower(var.project_name)}-terraform-state-${var.environment}"
    Description = "Armazena o estado do Terraform"
    Environment = var.environment
  })
}

# Habilita versionamento no bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Habilita criptografia por padrão
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueia todo acesso público ao bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
} 