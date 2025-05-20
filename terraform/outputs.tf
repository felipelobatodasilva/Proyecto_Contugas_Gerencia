output "ec2_public_ip" {
  description = "IP público da instância EC2 criada"
  value       = aws_instance.app_server.public_ip
} 