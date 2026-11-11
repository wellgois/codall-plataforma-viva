output "bucket" { value = aws_s3_bucket.lake.bucket }
output "workgroup_athena" { value = try(aws_athena_workgroup.bi[0].name, null) }
output "banco_glue" { value = aws_glue_catalog_database.gold.name }
output "usuario_publicador" { value = aws_iam_user.publicador.name }
