## Bucket S3 donde se va a guardar el tfstate remoto del orquestador.
## prevent_destroy: este bucket nunca debe poder borrarse desde un "terraform destroy" del stack
## principal (ni de este mismo). Es la unica fuente de verdad de que existe en AWS.
resource "aws_s3_bucket" "tfstate" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

## Versionado: permite recuperar una version anterior del state si un apply lo deja en mal estado.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

## Cifrado en reposo: el tfstate guarda en texto plano valores sensibles (ej. db_password).
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

## Bloqueo total de acceso publico: el tfstate nunca debe ser accesible desde Internet.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

## Tabla DynamoDB usada por el backend "s3" de Terraform para el lock del state.
## LockID (string) es el nombre y tipo de clave que Terraform espera de forma fija.
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}
