# Versiones mínimas de Terraform/OpenTofu y del proveedor.

terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    # Genera las contraseñas de la base de datos, JWT y administrador.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
