# Grupo de Segurança para a instância EC2
resource "aws_security_group" "instance_sg" {
  name        = "${var.aws_key_pair_name}-sg"
  description = "Allow SSH from admin (IPv4) and App traffic (IPv4 and IPv6)"

  ingress {
    description = "SSH from Admin IPv4"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.admin_ipv4}/32"]
  }

  ingress {
    description = "App Port from IPv4"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "App Port from IPv6"
    from_port        = var.app_port
    to_port          = var.app_port
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Streamlit Port from IPv4"
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Streamlit Port from IPv6"
    from_port        = 8501
    to_port          = 8501
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.aws_key_pair_name}-sg"
  }
}

# Criar o par de chaves SSH
resource "aws_key_pair" "app_key" {
  key_name   = var.aws_key_pair_name
  public_key = file("${path.module}/ssh/${var.aws_key_pair_name}.pub")
}

resource "aws_instance" "app_server" {
  ami           = "ami-084568db4383264d4" # Ubuntu Server 24.04 LTS (us-east-1)
  instance_type = var.instance_type
  key_name      = var.aws_key_pair_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  tags = {
    Name = "contugasapi" # Nombre de la instancia EC2 para identificar en AWS
  }

  # Exemplo de user_data para instalar dependências (opcional)
  # user_data = <<-EOF
  #   #!/bin/bash
  #   apt-get update
  #   apt-get install -y python3-pip git
  #   pip3 install fastapi uvicorn joblib pandas scikit-learn
  #   # Outros comandos de setup...
  # EOF
} 