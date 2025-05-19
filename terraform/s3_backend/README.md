# Backend S3 - Terraform State

Este módulo cria a infraestrutura necessária para armazenar o estado do Terraform de forma remota usando Amazon S3.

## Recursos Criados

- Bucket S3 para armazenar o estado do Terraform
  - Versionamento habilitado
  - Criptografia AES256
  - Bloqueio de acesso público
  - Prevenção contra exclusão acidental

## Uso

1. Primeiro, aplique este módulo para criar o bucket S3:

```bash
cd s3_backend
terraform init
terraform plan
terraform apply
```

2. Após criar o bucket, você pode configurar o backend nos outros módulos usando:

```hcl
terraform {
  backend "s3" {
    bucket         = "contugas-terraform-state-dev"  # Ajuste conforme ambiente
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
```

## Variáveis

| Nome | Descrição | Tipo | Default |
|------|-----------|------|---------|
| aws_region | Região AWS | string | us-east-1 |
| project_name | Nome do projeto | string | Contugas |
| environment | Ambiente (dev, staging, prod) | string | dev |
| tags | Tags comuns para todos os recursos | map(string) | {...} |

## Outputs

| Nome | Descrição |
|------|-----------|
| state_bucket_name | Nome do bucket S3 que armazena o estado |
| state_bucket_arn | ARN do bucket S3 que armazena o estado |

## Notas

- O bucket é criado com `prevent_destroy = true` para evitar exclusão acidental
- O nome do bucket segue o padrão: `{project_name}-terraform-state-{environment}`
- Todos os recursos são tagueados apropriadamente para melhor governança 