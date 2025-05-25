# S3 Buckets
resource "aws_s3_bucket" "raw" {
  bucket = "contugas-raw-data-dev"
  force_destroy = true
}

# Encryption for raw bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for raw bucket
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL/TLS for raw bucket
resource "aws_s3_bucket_policy" "raw_ssl" {
  bucket = aws_s3_bucket.raw.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ForceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "trusted" {
  bucket = "contugas-trusted-data-dev"
  force_destroy = true
}

# Encryption for trusted bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "trusted" {
  bucket = aws_s3_bucket.trusted.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for trusted bucket
resource "aws_s3_bucket_public_access_block" "trusted" {
  bucket = aws_s3_bucket.trusted.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL/TLS for trusted bucket
resource "aws_s3_bucket_policy" "trusted_ssl" {
  bucket = aws_s3_bucket.trusted.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ForceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.trusted.arn,
          "${aws_s3_bucket.trusted.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "scripts" {
  bucket = "contugas-scripts-dev"
  force_destroy = true
}

# Encryption for scripts bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for scripts bucket
resource "aws_s3_bucket_public_access_block" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL/TLS for scripts bucket
resource "aws_s3_bucket_policy" "scripts_ssl" {
  bucket = aws_s3_bucket.scripts.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ForceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.scripts.arn,
          "${aws_s3_bucket.scripts.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "refined" {
  bucket = "contugas-refined-data-dev"
  force_destroy = true
}

# Encryption for refined bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "refined" {
  bucket = aws_s3_bucket.refined.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for refined bucket
resource "aws_s3_bucket_public_access_block" "refined" {
  bucket = aws_s3_bucket.refined.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL/TLS for refined bucket
resource "aws_s3_bucket_policy" "refined_ssl" {
  bucket = aws_s3_bucket.refined.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ForceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.refined.arn,
          "${aws_s3_bucket.refined.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "models" {
  bucket = "contugas-models-dev"
  force_destroy = true
}

# Encryption for models bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "models" {
  bucket = aws_s3_bucket.models.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for models bucket
resource "aws_s3_bucket_public_access_block" "models" {
  bucket = aws_s3_bucket.models.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL/TLS for models bucket
resource "aws_s3_bucket_policy" "models_ssl" {
  bucket = aws_s3_bucket.models.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ForceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.models.arn,
          "${aws_s3_bucket.models.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "athena_results" {
  bucket = "contugas-athena-results-dev"
  force_destroy = true
}

# Encryption for athena_results bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for athena_results bucket
resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL/TLS for athena_results bucket
resource "aws_s3_bucket_policy" "athena_results_ssl" {
  bucket = aws_s3_bucket.athena_results.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ForceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.athena_results.arn,
          "${aws_s3_bucket.athena_results.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}

# Versionamento apenas para buckets de dados
resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "trusted" {
  bucket = aws_s3_bucket.trusted.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Versionamento para o bucket de modelos
resource "aws_s3_bucket_versioning" "models" {
  bucket = aws_s3_bucket.models.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Versionamento para o bucket de resultados do Athena
resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Upload inicial dos arquivos
resource "aws_s3_object" "excel_data" {
  bucket = aws_s3_bucket.raw.id
  key    = "Contugas_Datos.xlsx"
  source = "../Contugas_Datos.xlsx"
  etag   = filemd5("../Contugas_Datos.xlsx")
}

resource "aws_s3_object" "raw_to_trusted_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "glue/raw_to_trusted_01.py"
  source = "${path.module}/scripts/glue/raw_to_trusted_01.py"
  etag   = filemd5("${path.module}/scripts/glue/raw_to_trusted_01.py")
}

# Upload do script trusted_to_refined
resource "aws_s3_object" "trusted_to_refined_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "glue/trusted_to_refined_02.py"
  source = "${path.module}/scripts/glue/trusted_to_refined_02.py"
  etag   = filemd5("${path.module}/scripts/glue/trusted_to_refined_02.py")
}

# Criação da estrutura de diretórios
resource "aws_s3_object" "raw_data_folder" {
  bucket = aws_s3_bucket.raw.id
  key    = "data/"
  source = "/dev/null"
}

resource "aws_s3_object" "trusted_data_folder" {
  bucket = aws_s3_bucket.trusted.id
  key    = "data/"
  source = "/dev/null"
}

resource "aws_s3_object" "scripts_folder" {
  bucket = aws_s3_bucket.scripts.id
  key    = "glue/"
  source = "/dev/null"
}

# Criação da estrutura de diretórios para resultados do Athena
resource "aws_s3_object" "athena_results_folder" {
  bucket = aws_s3_bucket.athena_results.id
  key    = "athena-results/"
  source = "/dev/null"
}

# Criação da estrutura de diretórios para modelos
resource "aws_s3_object" "models_folder" {
  bucket = aws_s3_bucket.models.id
  key    = "models/"
  source = "/dev/null"
}

# Upload do script refined_to_models_03.py para o bucket de scripts Glue
resource "aws_s3_object" "refined_to_models_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "glue/refined_to_models_03.py"
  source = "${path.module}/scripts/glue/refined_to_models_03.py"
  etag   = filemd5("${path.module}/scripts/glue/refined_to_models_03.py")
} 