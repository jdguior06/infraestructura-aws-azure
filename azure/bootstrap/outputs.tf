# Salidas: el bloque backend listo para pegar en backend.tf.

output "nombre_cuenta" {
  value = azurerm_storage_account.estado.name
}

output "bloque_backend" {
  description = "Copia este bloque dentro de terraform { } en azure/main.tf"
  value       = <<-EOT
    backend "azurerm" {
      subscription_id      = "${var.subscription_id}"
      resource_group_name  = "${azurerm_resource_group.estado.name}"
      storage_account_name = "${azurerm_storage_account.estado.name}"
      container_name       = "${azurerm_storage_container.estado.name}"
      key                  = "azure/terraform.tfstate"
    }
  EOT
}
