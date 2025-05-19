output "state_bucket_name" {
  description = "Nome do bucket S3 que armazena o estado do Terraform"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN do bucket S3 que armazena o estado do Terraform"
  value       = aws_s3_bucket.terraform_state.arn
} 