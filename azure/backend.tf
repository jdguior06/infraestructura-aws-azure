# Estado remoto compartido. Pega aquí el bloque que muestra bootstrap.

terraform {
  # Valores que muestra "terraform output -raw bloque_backend"
  # en azure/bootstrap. El bloque backend no acepta variables.
  # Azure bloquea el estado automáticamente durante plan y apply.
  backend "azurerm" {
    subscription_id      = "71b37f71-39b3-4923-a424-c5bffee73955"
    resource_group_name  = "rg-tfstate-asistencia"
    storage_account_name = "sttfstate8f5a458c32"
    container_name       = "tfstate"
    key                  = "azure/terraform.tfstate"
  }
}
