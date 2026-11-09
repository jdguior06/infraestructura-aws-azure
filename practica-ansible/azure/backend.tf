# Estado remoto compartido: el mismo Storage Account del grupo, con otra clave.
# Azure bloquea el estado automáticamente durante plan y apply.

terraform {
  backend "azurerm" {
    subscription_id      = "71b37f71-39b3-4923-a424-c5bffee73955"
    resource_group_name  = "rg-tfstate-asistencia"
    storage_account_name = "sttfstate8f5a458c32"
    container_name       = "tfstate"
    key                  = "practica-ansible/azure/terraform.tfstate"
  }
}
