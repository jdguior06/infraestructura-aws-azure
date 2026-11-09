# Estado remoto compartido: el mismo bucket del grupo, con otra clave.

terraform {
  backend "s3" {
    bucket       = "tfstate-asistencia-859142233691"
    key          = "practica-ansible/aws/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true # bloqueo: un solo apply a la vez
    encrypt      = true
  }
}
