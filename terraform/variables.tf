variable "aws_region" {
  description = "Região AWS para criar os recursos"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t3.micro"
}

variable "aws_key_pair_name" {
  description = "Nome para registrar o par de chaves na AWS"
  type        = string
  default     = "manual-ec2-key"
}

variable "admin_ipv4" {
  description = "Endereço IPv4 do administrador para acesso SSH"
  type        = string
}

variable "app_port" {
  description = "Porta em que a aplicação FastAPI rodará"
  type        = number
  default     = 5000
}

variable "streamlit_port" {
  description = "Porta em que a aplicação Streamlit rodará"
  type        = number
  default     = 8501
} 