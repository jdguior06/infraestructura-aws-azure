# Recursos que guardan el estado compartido del grupo (con versionado y protección).

locals {
  # Nombre único en todo Azure: 3-24 caracteres, solo minúsculas y números.
  nombre_cuenta = "sttfstate${substr(md5(var.subscription_id), 0, 10)}"

  etiquetas = {
    Proyecto   = "asistencia-grupo"
    Gestionado = "terraform"
    Uso        = "estado-terraform"
  }
}

resource "azurerm_resource_group" "estado" {
  name     = "rg-tfstate-asistencia"
  location = var.region
  tags     = local.etiquetas

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_account" "estado" {
  name                            = local.nombre_cuenta
  resource_group_name             = azurerm_resource_group.estado.name
  location                        = azurerm_resource_group.estado.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.etiquetas

  blob_properties {
    # Versionado: cada apply guarda una versión nueva del estado.
    versioning_enabled = true

    # Papelera: un blob o contenedor borrado se puede recuperar durante 7 días.
    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  # Protege el estado del grupo contra un "destroy" accidental.
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "estado" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.estado.id
  container_access_type = "private"
}
