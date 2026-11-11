data "aws_caller_identity" "atual" {}

locals {
  bucket = "${var.prefixo}-lake-${data.aws_caller_identity.atual.account_id}"
}

# ---------- Armazenamento (unico recurso com custo proporcional ao uso) ----------
resource "aws_s3_bucket" "lake" {
  bucket        = local.bucket
  force_destroy = true # permite destruir e recriar a vitrine sem sobras
}

resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    id     = "resultados-athena-7-dias"
    status = "Enabled"
    filter { prefix = "athena-results/" }
    expiration { days = 7 }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
  rule {
    id     = "limpeza-multipart"
    status = "Enabled"
    filter { prefix = "" }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}

# ---------- Catalogo e consulta (Athena cobra so por dado lido; catalogo Glue e gratis nesta escala) ----------
resource "aws_glue_catalog_database" "gold" {
  name = "plataforma_viva"
}

resource "aws_glue_catalog_table" "radar_demanda" {
  name          = "gold_radar_demanda"
  database_name = aws_glue_catalog_database.gold.name
  table_type    = "EXTERNAL_TABLE"
  parameters    = { "classification" = "parquet" }
  storage_descriptor {
    location      = "s3://${aws_s3_bucket.lake.bucket}/gold/gold_radar_demanda/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }
    columns {
      name = "dt"
      type = "date"
    }
    columns {
      name = "tecnologia"
      type = "string"
    }
    columns {
      name = "vagas"
      type = "bigint"
    }
    columns {
      name = "vagas_com_tec"
      type = "bigint"
    }
    columns {
      name = "pct_vagas"
      type = "double"
    }
    columns {
      name = "pct_media_7d"
      type = "double"
    }
  }
}

resource "aws_glue_catalog_table" "operacao_diaria" {
  name          = "gold_operacao_diaria"
  database_name = aws_glue_catalog_database.gold.name
  table_type    = "EXTERNAL_TABLE"
  parameters    = { "classification" = "parquet" }
  storage_descriptor {
    location      = "s3://${aws_s3_bucket.lake.bucket}/gold/gold_operacao_diaria/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }
    columns {
      name = "dt"
      type = "date"
    }
    columns {
      name = "projeto"
      type = "string"
    }
    columns {
      name = "origem"
      type = "string"
    }
    columns {
      name = "eventos"
      type = "bigint"
    }
  }
}

resource "aws_athena_workgroup" "bi" {
  count         = var.habilitar_athena ? 1 : 0
  name          = "${var.prefixo}-bi"
  force_destroy = true
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false
    bytes_scanned_cutoff_per_query     = var.limite_athena_bytes
    result_configuration {
      output_location = "s3://${aws_s3_bucket.lake.bucket}/athena-results/"
    }
  }
}

# ---------- Acesso minimo: quem publica o gold so escreve em gold/ ----------
resource "aws_iam_user" "publicador" {
  name = "${var.prefixo}-publicador"
}

data "aws_iam_policy_document" "publicador" {
  statement {
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.lake.arn}/gold/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.lake.arn]
  }
}

resource "aws_iam_user_policy" "publicador" {
  name   = "somente-gold"
  user   = aws_iam_user.publicador.name
  policy = data.aws_iam_policy_document.publicador.json
}

# ---------- Teto de gasto ----------
resource "aws_budgets_budget" "mensal" {
  count        = var.habilitar_orcamento ? 1 : 0
  name         = "${var.prefixo}-teto-mensal"
  budget_type  = "COST"
  limit_amount = tostring(var.teto_mensal_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.email_alerta]
    }
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.email_alerta]
  }
}
