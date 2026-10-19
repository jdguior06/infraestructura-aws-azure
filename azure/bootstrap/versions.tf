# Versiones y proveedor. El estado de esta carpeta queda LOCAL en la PC del dueño de la cuenta.

# BOOTSTRAP AZURE · Storage Account para el estado compartido del grupo
# Lo ejecuta UNA sola vez el dueño de la suscripción. Su propio estado
# queda local (en esta carpeta), porque la cuenta aún no existe al crearla.
terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.9"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
