# Versiones mínimas de Terraform/OpenTofu y de los proveedores.

terraform {
  required_version = ">= 1.10" # use_lockfile en S3 requiere 1.10+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    # Escribe el inventario de Ansible (../ansible/inventarios/aws.ini).
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
