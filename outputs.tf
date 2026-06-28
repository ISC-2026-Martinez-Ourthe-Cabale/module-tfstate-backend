## Output con el nombre del bucket S3 del tfstate remoto.
output "bucket_name" {
  description = "Nombre del bucket S3 a usar en el bloque backend \"s3\" del orquestador."
  value       = aws_s3_bucket.tfstate.id
}

## Output con el nombre de la tabla DynamoDB de lock.
output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB a usar en el bloque backend \"s3\" del orquestador."
  value       = aws_dynamodb_table.tfstate_lock.name
}
