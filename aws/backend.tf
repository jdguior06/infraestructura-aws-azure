# Estado remoto compartido. Pega aquí el bloque que muestra bootstrap.

terraform {
  # Valores que muestra "terraform output -raw bloque_backend"
  # en aws/bootstrap. El bloque backend no acepta variables.
  backend "s3" {
    bucket       = "tfstate-asistencia-859142233691"
    key          = "aws/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true # bloqueo: un solo apply a la vez
    encrypt      = true
  }
}
