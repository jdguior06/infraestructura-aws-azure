# Recursos que guardan el estado compartido del grupo (con versionado y protección).

# El ID de la cuenta hace que el nombre del bucket sea único en todo AWS.
data "aws_caller_identity" "actual" {}

locals {
  nombre_bucket = "tfstate-asistencia-${data.aws_caller_identity.actual.account_id}"
}

resource "aws_s3_bucket" "estado" {
  bucket = local.nombre_bucket

  # Protege el estado del grupo contra un "destroy" accidental.
  lifecycle {
    prevent_destroy = true
  }
}

# Versionado: cada apply guarda una versión nueva del estado.
resource "aws_s3_bucket_versioning" "estado" {
  bucket = aws_s3_bucket.estado.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado en reposo.
resource "aws_s3_bucket_server_side_encryption_configuration" "estado" {
  bucket = aws_s3_bucket.estado.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# El estado nunca debe ser público.
resource "aws_s3_bucket_public_access_block" "estado" {
  bucket                  = aws_s3_bucket.estado.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
