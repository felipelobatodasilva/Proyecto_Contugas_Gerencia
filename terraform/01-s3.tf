# S3 Buckets
resource "aws_s3_bucket" "raw" {
  bucket = "contugas-raw-data-dev"
  force_destroy = true
}

resource "aws_s3_bucket" "trusted" {
  bucket = "contugas-trusted-data-dev"
  force_destroy = true
}

resource "aws_s3_bucket" "scripts" {
  bucket = "contugas-scripts-dev"
  force_destroy = true
}

resource "aws_s3_bucket" "refined" {
  bucket = "contugas-refined-data-dev"
  force_destroy = true 
}

# Bucket para modelos
resource "aws_s3_bucket" "models" {
  bucket = "contugas-models-dev"
  force_destroy = true
}

# Bucket para resultados do Athena
resource "aws_s3_bucket" "athena_results" {
  bucket = "contugas-athena-results-dev"
  force_destroy = true
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