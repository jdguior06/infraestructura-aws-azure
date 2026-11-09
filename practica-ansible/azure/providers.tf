# Configuración del proveedor de la nube.

# Usa la sesión de "az login"; nunca van credenciales en el código.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
