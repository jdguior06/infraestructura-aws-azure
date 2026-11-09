# Versiones mínimas de Terraform/OpenTofu y de los proveedores.

terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    # Escribe el inventario de Ansible (../ansible/inventarios/azure.ini).
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
