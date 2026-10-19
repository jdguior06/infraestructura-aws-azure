# Salidas: el bloque backend listo para pegar en backend.tf.

output "nombre_bucket" {
  value = aws_s3_bucket.estado.bucket
}

output "bloque_backend" {
  description = "Copia este bloque dentro de terraform { } en aws/main.tf"
  value       = <<-EOT
    backend "s3" {
      bucket       = "${aws_s3_bucket.estado.bucket}"
      key          = "aws/terraform.tfstate"
      region       = "${var.region}"
      use_lockfile = true
      encrypt      = true
    }
  EOT
}
