# Versiones mínimas de Terraform/OpenTofu y del proveedor.

terraform {
  required_version = ">= 1.10" # use_lockfile en S3 requiere 1.10+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    # Genera las contraseñas de la base de datos, JWT y administrador.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
