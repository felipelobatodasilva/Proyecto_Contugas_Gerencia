# Database no Glue Catalog
resource "aws_glue_catalog_database" "trusted" {
  name        = "contugas_trusted"
  description = "Database para dados processados da Contugas na camada trusted"
}

resource "aws_glue_catalog_database" "refined" {
  name        = "contugas_refined"
  description = "Database para dados refinados da Contugas"
}

# Tabela para os dados processados
resource "aws_glue_catalog_table" "dados_processados" {
  name          = "dados_processados"
  database_name = aws_glue_catalog_database.trusted.name
  description   = "Dados processados da Contugas"
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification"  = "parquet"
    "typeOfData"     = "file"
    EXTERNAL         = "TRUE"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.trusted.id}/dato_procesado"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    compressed    = false

    ser_de_info {
      name                  = "ParquetHiveSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    # Definir as colunas conforme o schema dos dados
    columns {
      name = "cliente"
      type = "string"
    }
    columns {
      name = "fecha"
      type = "timestamp"
    }
    columns {
      name = "presion"
      type = "double"
    }
    columns {
      name = "temperatura"
      type = "double"
    }
    columns {
      name = "volumen"
      type = "double"
    }
    columns {
      name = "mes"
      type = "string"
    }
    columns {
      name = "año"
      type = "string"
    }
    columns {
      name = "es_feriado"
      type = "boolean"
    }
    columns {
      name = "anomalia"
      type = "string"
    }
    columns {
      name = "anomalia_bin"
      type = "int"
    }
  }

  # Particionamento por data de processamento
  partition_keys {
    name = "fecha_procesamiento"
    type = "string"
  }
}

# Crawler para detectar partições
resource "aws_glue_crawler" "trusted_crawler" {
  database_name = aws_glue_catalog_database.trusted.name
  name          = "contugas_trusted_crawler"
  role          = aws_iam_role.glue_role.arn
  s3_target {
    path = "s3://${aws_s3_bucket.trusted.id}/dato_procesado"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })
}

# Crawler para os dados refinados
resource "aws_glue_crawler" "refined_crawler" {
  database_name = aws_glue_catalog_database.refined.name
  name          = "contugas_refined_crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.refined.id}/dato_refinado/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })
}
