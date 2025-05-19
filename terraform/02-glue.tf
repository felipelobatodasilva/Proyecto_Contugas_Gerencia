# IAM Role para o Glue
resource "aws_iam_role" "glue_role" {
  name = "contugas_glue_role"
  depends_on = [
    aws_s3_bucket.raw,
    aws_s3_bucket.trusted,
    aws_s3_bucket.scripts,
    aws_s3_bucket.refined
  ]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# Políticas necessárias para o Glue
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "s3_policy" {
  name = "contugas_s3_policy"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*",
          aws_s3_bucket.trusted.arn,
          "${aws_s3_bucket.trusted.arn}/*",
          aws_s3_bucket.scripts.arn,
          "${aws_s3_bucket.scripts.arn}/*",
          aws_s3_bucket.refined.arn,
          "${aws_s3_bucket.refined.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:*"
        ]
        Resource = [
          "*"
        ]
      }
    ]
  })
}

# Job do Glue
resource "aws_glue_job" "raw_to_trusted" {
  name     = "contugas_raw_to_trusted"
  role_arn = aws_iam_role.glue_role.arn
  depends_on = [
    aws_s3_object.raw_to_trusted_script,
    aws_s3_object.excel_data
  ]

  command {
    script_location = "s3://${aws_s3_bucket.scripts.id}/glue/raw_to_trusted_01.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--job-language"                     = "python"
    "--TempDir"                          = "s3://${aws_s3_bucket.scripts.id}/temporary/"
    "--additional-python-modules"        = "pandas==1.5.3,openpyxl==3.1.2,psutil==5.9.5,holidays==0.25"
    "--conf spark.jars.packages"         = "com.crealytics:spark-excel_2.12:0.18.7"
  }

  max_capacity = 2
  max_retries  = 0
  timeout      = 60

  execution_property {
    max_concurrent_runs = 1
  }

  glue_version      = "4.0"
}

# Job do Glue para Trusted to Refined
resource "aws_glue_job" "trusted_to_refined" {
  name     = "contugas_trusted_to_refined"
  role_arn = aws_iam_role.glue_role.arn
  depends_on = [
    aws_s3_object.trusted_to_refined_script,
    aws_glue_job.raw_to_trusted
  ]

  command {
    script_location = "s3://${aws_s3_bucket.scripts.id}/glue/trusted_to_refined_02.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--job-language"                     = "python"
    "--TempDir"                          = "s3://${aws_s3_bucket.scripts.id}/temporary/"
    "--additional-python-modules"        = "scikit-learn==1.0.2"
  }

  max_capacity = 2
  max_retries  = 0
  timeout      = 60

  execution_property {
    max_concurrent_runs = 1
  }

  glue_version      = "4.0"
} 