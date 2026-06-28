## Variable del nombre del bucket S3 donde se va a guardar el tfstate remoto. Debe ser globalmente unico.
variable "bucket_name" {
  description = "Nombre del bucket S3 para el tfstate remoto. Debe ser globalmente unico en AWS."
  type        = string
}

## Variable del nombre de la tabla DynamoDB usada para el lock del state.
variable "lock_table_name" {
  description = "Nombre de la tabla DynamoDB usada para el lock del tfstate."
  type        = string
  default     = "terraform-state-lock"
}
