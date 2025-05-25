# Grupo principal para usuários do projeto
resource "aws_iam_group" "contugas_users" {
  name = "contugas_users"
}

# Política para gerenciar jobs do Glue
resource "aws_iam_policy" "glue_management" {
  name        = "contugas_glue_management"
  description = "Permite gerenciar e executar jobs do Glue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:*",
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogGroupFields",
          "logs:GetQueryResults"
        ]
        Resource = "*"
      }
    ]
  })
}

# Política para acesso total aos buckets S3 do projeto
resource "aws_iam_policy" "s3_access" {
  name        = "contugas_s3_access"
  description = "Permite acesso total aos buckets S3 do projeto"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*",
          aws_s3_bucket.trusted.arn,
          "${aws_s3_bucket.trusted.arn}/*",
          aws_s3_bucket.refined.arn,
          "${aws_s3_bucket.refined.arn}/*",
          aws_s3_bucket.models.arn,
          "${aws_s3_bucket.models.arn}/*",
          aws_s3_bucket.scripts.arn,
          "${aws_s3_bucket.scripts.arn}/*",
          aws_s3_bucket.athena_results.arn,
          "${aws_s3_bucket.athena_results.arn}/*"
        ]
      }
    ]
  })
}

# Política para gerenciamento do Terraform
resource "aws_iam_policy" "terraform_management" {
  name        = "contugas_terraform_management"
  description = "Permite gerenciar recursos via Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "iam:*",
          "s3:*",
          "glue:*",
          "athena:*",
          "states:*",
          "lambda:*",
          "cloudwatch:*",
          "logs:*",
          "kms:*",
          "sns:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Política para Athena
resource "aws_iam_policy" "athena_access" {
  name        = "contugas_athena_access"
  description = "Permite executar consultas no Athena"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "athena:*",
          "glue:GetTable",
          "glue:GetPartition",
          "glue:GetDatabase",
          "glue:GetTables",
          "glue:GetPartitions",
          "glue:GetDatabases",
          "glue:GetCatalogImportStatus"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.athena_results.arn,
          "${aws_s3_bucket.athena_results.arn}/*"
        ]
      }
    ]
  })
}

# Política para gerenciamento de EC2
resource "aws_iam_policy" "ec2_management" {
  name        = "contugas_ec2_management"
  description = "Permite gerenciar instâncias EC2"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "cloudwatch:*",
          "autoscaling:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Política para CloudWatch Logs
resource "aws_iam_policy" "cloudwatch_logs" {
  name        = "contugas_cloudwatch_logs"
  description = "Permite acesso aos logs do CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Anexar todas as políticas ao grupo
resource "aws_iam_group_policy_attachment" "glue_attachment" {
  group      = aws_iam_group.contugas_users.name
  policy_arn = aws_iam_policy.glue_management.arn
}

resource "aws_iam_group_policy_attachment" "s3_attachment" {
  group      = aws_iam_group.contugas_users.name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_group_policy_attachment" "terraform_attachment" {
  group      = aws_iam_group.contugas_users.name
  policy_arn = aws_iam_policy.terraform_management.arn
}

resource "aws_iam_group_policy_attachment" "athena_attachment" {
  group      = aws_iam_group.contugas_users.name
  policy_arn = aws_iam_policy.athena_access.arn
}

resource "aws_iam_group_policy_attachment" "ec2_attachment" {
  group      = aws_iam_group.contugas_users.name
  policy_arn = aws_iam_policy.ec2_management.arn
}

resource "aws_iam_group_policy_attachment" "cloudwatch_attachment" {
  group      = aws_iam_group.contugas_users.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

# Criar um usuário de exemplo (você pode criar mais conforme necessário)
resource "aws_iam_user" "user" {
  name = "contugas_user"
}

# Adicionar o usuário ao grupo
resource "aws_iam_user_group_membership" "user_membership" {
  user   = aws_iam_user.user.name
  groups = [aws_iam_group.contugas_users.name]
} 